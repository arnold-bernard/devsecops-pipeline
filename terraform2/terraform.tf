# ----------------------------------------------------------------------
# Terraform configuration for 3 t2.medium instances:
#   Jenkins, SonarQube (Docker), and a generic third server
# ----------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# ----------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  default     = "my-keypair"   # change to your key
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhLVYWp61sn22sWle6aSy9j3bYWZI4kwsohEL2LVGYp arnold@DESKTOP-T7RVSCP"
}

variable "instance_type" {
  description = "Instance type for all servers"
  default     = "t2.medium"
}

# ----------------------------------------------------------------------
# Data sources
# ----------------------------------------------------------------------
# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ----------------------------------------------------------------------
# Networking – VPC, Subnet, Internet Gateway, Route Table
# ----------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "jenkins-sonarqube-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "jenkins-sonarqube-public-subnet"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "jenkins-sonarqube-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "jenkins-sonarqube-public-route"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ----------------------------------------------------------------------
# Security Group
# ----------------------------------------------------------------------
resource "aws_security_group" "common" {
  name        = "jenkins-sonarqube-sg"
  description = "Security group for Jenkins, SonarQube and third server"
  vpc_id      = aws_vpc.main.id

  # SSH from anywhere (change to your IP for better security)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Jenkins web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube web UI
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic between instances in the same security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

    ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sonarqube-common-sg"
  }
}

# ----------------------------------------------------------------------
# EC2 Instances
# ----------------------------------------------------------------------

# 1. Jenkins Server
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.common.id]
  key_name               = var.key_name
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "jenkins-root-volume"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name        = "Jenkins-Server"
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}

# 2. SonarQube Server (using Docker)
resource "aws_instance" "sonarqube" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.common.id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              # Update system
              yum update -y

              # Install Docker
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user

              # Run SonarQube container (LTS version) on port 9000
              docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "SonarQube-Server"
  }
}

# 3. Third Server (generic web server – Nginx)
resource "aws_instance" "third" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.common.id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -e
              exec > >(tee -a /var/log/user-data.log) 2>&1
              echo "Starting user-data script..."

              yum update -y
              curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
              yum install -y nodejs git

              cd /home/ec2-user
              git clone https://github.com/arnold-bernard/devsecops-pipeline.git

              APP_DIR="/home/ec2-user/devsecops-pipeline/app/juice-shop"
              if [ ! -d "$APP_DIR" ]; then
                  FOUND_DIR=$(find /home/ec2-user/devsecops-pipeline -name "package.json" -not -path "*/node_modules/*" -exec dirname {} \; | head -1)
                  if [ -n "$FOUND_DIR" ]; then
                      APP_DIR="$FOUND_DIR"
                  else
                      echo "Could not find package.json" && exit 1
                  fi
              fi
              cd "$APP_DIR"
              npm install
              nohup npm start > /home/ec2-user/app.log 2>&1 &
              echo "Done."
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "Third-Server"
  }
}

# ----------------------------------------------------------------------
# Outputs
# ----------------------------------------------------------------------
output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
  description = "Public IP of the Jenkins server"
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
  description = "Jenkins web interface URL"
}

output "sonarqube_public_ip" {
  value = aws_instance.sonarqube.public_ip
  description = "Public IP of the SonarQube server"
}

output "sonarqube_url" {
  value = "http://${aws_instance.sonarqube.public_ip}:9000"
  description = "SonarQube web interface URL"
}

output "third_server_public_ip" {
  value = aws_instance.third.public_ip
  description = "Public IP of the third server (Nginx)"
}

output "third_server_url" {
  value = "http://${aws_instance.third.public_ip}"
  description = "Third server web interface (Nginx)"
}
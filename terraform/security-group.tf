resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_eip" "demo" {
  domain = "vpc"
}

resource "aws_subnet" "demo_public_subnet1" {
  vpc_id     = aws_vpc.demo.id
  cidr_block = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "demo_private_subnet1" {
  vpc_id     = aws_vpc.demo.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.demo.id
  subnet_id     = aws_subnet.demo_public_subnet1.id
  depends_on = [
    aws_internet_gateway.demo
  ]

}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.demo_public_subnet1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.demo_private_subnet1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "web" {
  name = "web-sg"
  description = "Allow SSH access from specific IP"
  vpc_id = aws_vpc.demo.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = ["192.168.0.0/32"]
    description = "Allow SSH from specific IP"
  }

  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}
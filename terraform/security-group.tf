resource "aws_security_group" "web" {
  name = "web-sg"
  description = "Allow SSH access from specific IP"
  vpc_id = aws_vpc.demo.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = ["192.168.1.254/32"]
    description = "Allow SSH from specific IP"
  }
}
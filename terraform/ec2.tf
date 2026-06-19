resource "aws_instance" "demo" {
  subnet_id = aws_subnet.demo_public_subnet1.id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.web.id]
  ami           =  var.ami
  instance_type = "t2.medium"
  monitoring     = true
  tags = {
    Name = "DemoInstance"
  }

  metadata_options {
  http_endpoint = "enabled"
  http_tokens   = "required"
}

  root_block_device {
  encrypted = true
}
}
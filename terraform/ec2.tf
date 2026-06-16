resource "aws_instance" "demo" {
  security_groups = [aws_security_group.web.name]
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
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
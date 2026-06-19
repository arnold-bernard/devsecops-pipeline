resource "aws_s3_bucket" "demo" {
  bucket = "demo-bucket-terraform-1a2b3c4d5e6f7g8h9i0j"

  tags = {
    Name        = "Demo Bucket"
    Environment = "DevSecOps"
  }
}

resource "aws_s3_bucket_versioning" "demo" {
  bucket = aws_s3_bucket.demo.id

  versioning_configuration {
    status = "Enabled"
  }
}
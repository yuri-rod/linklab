variable "bucket_name" {}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  force_destroy = true
}

output "bucket" { value = aws_s3_bucket.this.bucket }

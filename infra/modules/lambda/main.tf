variable "function_name" {}
variable "role_arn" {}
variable "s3_bucket" {}
variable "s3_key" {}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = var.role_arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key
}

output "arn" { value = aws_lambda_function.this.arn }

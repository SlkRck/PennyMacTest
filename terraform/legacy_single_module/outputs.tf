output "lambda_function_name" {
  value       = aws_lambda_function.snapshot_cleaner.function_name
  description = "Deployed Lambda function name."
}

output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID."
}

output "private_subnet_id" {
  value       = aws_subnet.private_a.id
  description = "Private subnet ID used by the Lambda."
}

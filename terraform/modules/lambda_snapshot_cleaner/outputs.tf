output "lambda_name" {
  value = aws_lambda_function.this.function_name
}

output "lambda_arn" {
  value = aws_lambda_function.this.arn
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}

output "kms_key_arn" {
  value = aws_kms_key.lambda.arn
}

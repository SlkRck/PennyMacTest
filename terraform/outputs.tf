output "lambda_function_name" {
  value       = module.snapshot_cleaner.lambda_name
  description = "Deployed Lambda function name."
}

output "lambda_function_arn" {
  value       = module.snapshot_cleaner.lambda_arn
  description = "Deployed Lambda function ARN."
}

output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC ID."
}

output "private_subnet_ids" {
  value       = module.network.private_subnet_ids
  description = "Private subnet IDs used by the Lambda."
}

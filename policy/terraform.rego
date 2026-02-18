package terraform.guardrails

# Conftest parses Terraform HCL into JSON. We keep rules simple and static for an interview exercise.

denies[msg] {
  some r
  input.resource[r].type == "aws_lambda_function"
  not input.resource[r].config.vpc_config
  msg := "aws_lambda_function must include vpc_config (Lambda should run in private subnets)"
}

denies[msg] {
  some r
  input.resource[r].type == "aws_cloudwatch_log_group"
  not input.resource[r].config.retention_in_days
  msg := "aws_cloudwatch_log_group must set retention_in_days"
}

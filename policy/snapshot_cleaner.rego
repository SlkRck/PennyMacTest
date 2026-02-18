package snapshot_cleaner

# These policies are intentionally simple and demonstrative.
# In production you'd typically evaluate a Terraform plan JSON (tfplan.json).

deny[msg] {
  input.resource_changes[_].type == "aws_cloudwatch_log_group"
  after := input.resource_changes[_].change.after
  not after.kms_key_id
  msg := "CloudWatch log groups must be encrypted with kms_key_id"
}

deny[msg] {
  input.resource_changes[_].type == "aws_cloudwatch_log_group"
  after := input.resource_changes[_].change.after
  not after.retention_in_days
  msg := "CloudWatch log groups must set retention_in_days"
}

deny[msg] {
  input.resource_changes[_].type == "aws_lambda_function"
  after := input.resource_changes[_].change.after
  not after.kms_key_arn
  msg := "Lambda environment variables must be encrypted with kms_key_arn"
}

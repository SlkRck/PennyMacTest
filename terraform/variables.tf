variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}

# -----------------------------
# Networking
# -----------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "availability_zones" {
  description = "List of AZs to use (same length as private_subnet_cidrs)."
  type        = list(string)
}

variable "enable_vpc_endpoints" {
  description = "Create VPC interface endpoints so the Lambda can call AWS APIs from private subnets without a NAT gateway."
  type        = bool
}

# -----------------------------
# Lambda behavior
# -----------------------------
variable "retention_days" {
  description = "Snapshots older than this many days are eligible for deletion."
  type        = number
}

variable "dry_run" {
  description = "When true, the Lambda logs eligible snapshots but does not delete them."
  type        = bool
}

variable "delete_only_tagged" {
  description = "When true, Lambda will only delete snapshots that have the configured tag key/value, and IAM will also enforce this constraint."
  type        = bool
}

variable "delete_tag_key" {
  description = "Tag key required on snapshots to be eligible for deletion (used only when delete_only_tagged=true)."
  type        = string
}

variable "delete_tag_value" {
  description = "Tag value required on snapshots to be eligible for deletion (used only when delete_only_tagged=true)."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention (days)."
  type        = number
}

# -----------------------------
# Scheduling (Bonus)
# -----------------------------
variable "enable_schedule" {
  description = "When true, create an EventBridge schedule trigger for the Lambda."
  type        = bool
}

variable "schedule_expression" {
  description = "EventBridge schedule expression, e.g. rate(1 day) or cron(...)."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
  default     = "pennymac-snap-cleaner"
}

variable "retention_days" {
  description = "Snapshots older than this many days are eligible for deletion."
  type        = number
  default     = 365
}

variable "schedule_expression" {
  description = "EventBridge schedule expression."
  type        = string
  default     = "rate(1 day)"
}

variable "dry_run" {
  description = "When true, the Lambda logs eligible snapshots but does not delete them."
  type        = bool
  default     = false
}

variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
variable "aws_region" { type = string }

variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "retention_days" { type = number }
variable "dry_run" { type = bool }

variable "delete_only_tagged" { type = bool }
variable "delete_tag_key" { type = string }
variable "delete_tag_value" { type = string }

variable "log_retention_days" { type = number }

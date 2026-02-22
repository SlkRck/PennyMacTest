locals {
  common_tags = merge(var.tags, { Project = var.name_prefix })
}

module "network" {
  source = "./modules/network"

  name_prefix          = var.name_prefix
  tags                 = local.common_tags
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  enable_vpc_endpoints = var.enable_vpc_endpoints
}

module "snapshot_cleaner" {
  source = "./modules/lambda_snapshot_cleaner"

  name_prefix = var.name_prefix
  tags        = local.common_tags
  aws_region  = var.aws_region

  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  retention_days = var.retention_days
  dry_run        = var.dry_run

  delete_only_tagged = var.delete_only_tagged
  delete_tag_key     = var.delete_tag_key
  delete_tag_value   = var.delete_tag_value

  log_retention_days = var.log_retention_days
}

module "schedule" {
  source = "./modules/schedule"
  count  = var.enable_schedule ? 1 : 0

  name_prefix = var.name_prefix
  tags        = local.common_tags

  schedule_expression = var.schedule_expression
  lambda_arn          = module.snapshot_cleaner.lambda_arn
  lambda_name         = module.snapshot_cleaner.lambda_name
}

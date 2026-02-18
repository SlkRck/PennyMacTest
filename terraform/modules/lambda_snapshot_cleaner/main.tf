locals {
  lambda_name = "${var.name_prefix}-snapshot-cleaner"
}

# -----------------------------
# KMS key for Lambda environment variables and CloudWatch Logs encryption
# -----------------------------
data "aws_iam_policy_document" "kms" {
  statement {
    sid     = "EnableAccountAdmin"
    effect  = "Allow"
    actions = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    resources = ["*"]
  }
}

resource "aws_kms_key" "lambda" {
  description             = "KMS key for ${local.lambda_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-kms" })
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/${var.name_prefix}-lambda"
  target_key_id = aws_kms_key.lambda.key_id
}

# -----------------------------
# IAM: role + least-privilege policy
# -----------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

# CloudWatch logging permissions
data "aws_iam_policy_document" "logs" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

# EC2 snapshot permissions
data "aws_iam_policy_document" "ec2" {
  statement {
    sid     = "DescribeSnapshots"
    effect  = "Allow"
    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "DeleteSnapshots"
    effect  = "Allow"
    actions = ["ec2:DeleteSnapshot"]
    resources = ["*"]

    dynamic "condition" {
      for_each = var.delete_only_tagged ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${var.delete_tag_key}"
        values   = [var.delete_tag_value]
      }
    }
  }
}

# KMS decrypt/encrypt for env var encryption + Logs encryption
data "aws_iam_policy_document" "kms_use" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.lambda.arn]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name = "${var.name_prefix}-lambda-inline"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      jsondecode(data.aws_iam_policy_document.logs.json).Statement,
      jsondecode(data.aws_iam_policy_document.ec2.json).Statement,
      jsondecode(data.aws_iam_policy_document.kms_use.json).Statement
    )
  })
}

# -----------------------------
# Security Group: no ingress, HTTPS egress
# -----------------------------
resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for ${local.lambda_name}"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS egress (to VPC endpoints / AWS APIs)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-lambda-sg" })
}

# -----------------------------
# CloudWatch Logs (explicit so we can set retention + KMS)
# -----------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.lambda.arn

  tags = var.tags
}

# -----------------------------
# Package + Deploy Lambda
# -----------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda"
  output_path = "${path.module}/build/${local.lambda_name}.zip"
}

resource "aws_lambda_function" "this" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  kms_key_arn = aws_kms_key.lambda.arn

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      RETENTION_DAYS      = tostring(var.retention_days)
      DRY_RUN             = tostring(var.dry_run)
      DELETE_ONLY_TAGGED  = tostring(var.delete_only_tagged)
      DELETE_TAG_KEY      = var.delete_tag_key
      DELETE_TAG_VALUE    = var.delete_tag_value
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda
  ]

  tags = var.tags
}

data "aws_caller_identity" "current" {}

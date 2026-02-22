locals {
  tags = {
    Project = var.name_prefix
  }
}

# -----------------------------
# Networking: VPC + Private Subnet
# -----------------------------
resource "aws_vpc" "this" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.42.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = merge(local.tags, { Name = "${var.name_prefix}-private-a" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.name_prefix}-rt-private" })
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------
# Security Group for Lambda
# -----------------------------
resource "aws_security_group" "lambda" {
  name        = "${var.name_prefix}-lambda-sg"
  description = "Security group for snapshot cleanup Lambda"
  vpc_id      = aws_vpc.this.id

  # Allow all egress. With VPC endpoints, traffic stays private.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.name_prefix}-lambda-sg" })
}

# -----------------------------
# VPC Endpoints (avoid NAT Gateway)
# - Interface endpoints for EC2 + CloudWatch Logs
# -----------------------------
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id]
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true

  tags = merge(local.tags, { Name = "${var.name_prefix}-vpce-ec2" })
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id]
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true

  tags = merge(local.tags, { Name = "${var.name_prefix}-vpce-logs" })
}

# STS is optional but helpful depending on runtime/auth patterns.
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id]
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true

  tags = merge(local.tags, { Name = "${var.name_prefix}-vpce-sts" })
}

# -----------------------------
# IAM Role + Policy for Lambda
# -----------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = local.tags
}

# Least privilege for snapshot listing/deletion + logs.
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DeleteSnapshot"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.name_prefix}-lambda-inline"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# -----------------------------
# Lambda packaging (zip)
# -----------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/.terraform/lambda_snapshot_cleaner.zip"
}

# -----------------------------
# Lambda Function
# -----------------------------
resource "aws_lambda_function" "snapshot_cleaner" {
  function_name = var.name_prefix
  role          = aws_iam_role.lambda.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 60
  memory_size = 256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      RETENTION_DAYS = tostring(var.retention_days)
      SNAPSHOT_OWNER = "self"
      DRY_RUN        = tostring(var.dry_run)
    }
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy.lambda_inline]
}

# -----------------------------
# EventBridge Rule (schedule) + permission
# -----------------------------
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name_prefix}-daily"
  schedule_expression = var.schedule_expression

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "SnapshotCleaner"
  arn       = aws_lambda_function.snapshot_cleaner.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

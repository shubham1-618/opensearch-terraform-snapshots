terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "opensearch-vpc" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "opensearch-subnet-a" }
}
resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "opensearch-subnet-b" }
}
resource "aws_subnet" "c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}c"
  tags = { Name = "opensearch-subnet-c" }
}

resource "aws_security_group" "opensearch" {
  name        = "opensearch-sg"
  description = "Allow HTTPS"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "snapshots" {
  bucket = var.snapshot_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "snapshots" {
  bucket = aws_s3_bucket.snapshots.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "opensearch_snapshot" {
  name = "opensearch-snapshot-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "es.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "opensearch_snapshot" {
  name = "opensearch-snapshot-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        Resource = [aws_s3_bucket.snapshots.arn]
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        Resource = ["${aws_s3_bucket.snapshots.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "opensearch_snapshot" {
  role       = aws_iam_role.opensearch_snapshot.name
  policy_arn = aws_iam_policy.opensearch_snapshot.arn
}

resource "aws_iam_role" "lambda_snapshot" {
  name = "lambda-snapshot-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_snapshot" {
  name = "lambda-snapshot-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["es:ESHttpPut", "es:ESHttpPost", "es:ESHttpGet"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
        Resource = [aws_s3_bucket.snapshots.arn, "${aws_s3_bucket.snapshots.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_snapshot" {
  role       = aws_iam_role.lambda_snapshot.name
  policy_arn = aws_iam_policy.lambda_snapshot.arn
}

resource "aws_opensearch_domain" "main" {
  domain_name    = var.opensearch_domain_name
  engine_version = "OpenSearch_2.5"
  cluster_config {
    instance_type = "t3.small.search"
    instance_count = 3
    zone_awareness_enabled = true
    zone_awareness_config { availability_zone_count = 3 }
  }
  vpc_options {
    subnet_ids = [aws_subnet.a.id, aws_subnet.b.id, aws_subnet.c.id]
    security_group_ids = [aws_security_group.opensearch.id]
  }
  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp2"
  }
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
    }
  }
  encrypt_at_rest { enabled = true }
  node_to_node_encryption { enabled = true }
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }
  access_policies = <<POLICIES
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "*" },
      "Action": "es:*",
      "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*",
      "Condition": { "IpAddress": { "aws:SourceIp": "${var.allowed_cidr}" } }
    }
  ]
}
POLICIES
  depends_on = [aws_iam_role.opensearch_snapshot]
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "snapshot" {
  function_name = "opensearch-snapshot"
  role          = aws_iam_role.lambda_snapshot.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "lambda_function.zip"
  timeout       = 900
  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.main.endpoint
      OPENSEARCH_USER     = var.master_user_name
      OPENSEARCH_PASS     = var.master_user_password
      S3_BUCKET           = aws_s3_bucket.snapshots.bucket
      REGION              = var.aws_region
      SNAPSHOT_ROLE_ARN   = aws_iam_role.opensearch_snapshot.arn
    }
  }
  depends_on = [aws_iam_role_policy_attachment.lambda_snapshot]
}

resource "aws_cloudwatch_event_rule" "every_hour" {
  name                = "every-hour-snapshot"
  schedule_expression = "cron(0 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.every_hour.name
  target_id = "lambda-snapshot"
  arn       = aws_lambda_function.snapshot.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_hour.arn
}

resource "null_resource" "invoke_snapshot_lambda" {
  count = var.create_snapshot_now ? 1 : 0
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.snapshot.function_name} --payload '{}' response.json"
  }
  depends_on = [aws_lambda_function.snapshot]
}

resource "aws_lambda_function" "restore" {
  function_name = "opensearch-restore"
  role          = aws_iam_role.lambda_snapshot.arn
  handler       = "restore_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "restore_function.zip"
  timeout       = 900
  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.main.endpoint
      OPENSEARCH_USER     = var.master_user_name
      OPENSEARCH_PASS     = var.master_user_password
      S3_BUCKET           = aws_s3_bucket.snapshots.bucket
      REGION              = var.aws_region
      SNAPSHOT_ROLE_ARN   = aws_iam_role.opensearch_snapshot.arn
    }
  }
  depends_on = [aws_iam_role_policy_attachment.lambda_snapshot]
}

resource "null_resource" "invoke_restore_lambda" {
  count = length(var.restore_snapshot_name) > 0 && length(var.restore_index_name) > 0 ? 1 : 0
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.restore.function_name} --payload '{\"snapshot_name\":\"${var.restore_snapshot_name}\",\"index_name\":\"${var.restore_index_name}\"}' restore_response.json"
  }
  depends_on = [aws_lambda_function.restore]
}

output "opensearch_endpoint" {
  value = aws_opensearch_domain.main.endpoint
}
output "snapshot_bucket_name" {
  value = aws_s3_bucket.snapshots.bucket
}
output "lambda_function_name" {
  value = aws_lambda_function.snapshot.function_name
}
output "snapshot_role_arn" {
  value = aws_iam_role.opensearch_snapshot.arn
} 
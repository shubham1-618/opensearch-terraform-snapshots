provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "opensearch_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "opensearch-vpc"
  }
}

resource "aws_subnet" "opensearch_subnet_1" {
  vpc_id            = aws_vpc.opensearch_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  
  tags = {
    Name = "opensearch-subnet-1"
  }
}

resource "aws_subnet" "opensearch_subnet_2" {
  vpc_id            = aws_vpc.opensearch_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  
  tags = {
    Name = "opensearch-subnet-2"
  }
}

resource "aws_subnet" "opensearch_subnet_3" {
  vpc_id            = aws_vpc.opensearch_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}c"
  
  tags = {
    Name = "opensearch-subnet-3"
  }
}

resource "aws_security_group" "opensearch_sg" {
  name        = "opensearch-sg"
  description = "Security group for OpenSearch domain"
  vpc_id      = aws_vpc.opensearch_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "opensearch_snapshot_role" {
  name = "opensearch-snapshot-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "opensearch_snapshot_policy" {
  name        = "opensearch-snapshot-policy"
  description = "Policy for OpenSearch to manage snapshots in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.snapshot_bucket.arn]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.snapshot_bucket.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "snapshot_policy_attachment" {
  role       = aws_iam_role.opensearch_snapshot_role.name
  policy_arn = aws_iam_policy.opensearch_snapshot_policy.arn
}

resource "aws_s3_bucket" "snapshot_bucket" {
  bucket = var.snapshot_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "snapshot_bucket_block" {
  bucket = aws_s3_bucket.snapshot_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_opensearch_domain" "main" {
  domain_name           = var.opensearch_domain_name
  engine_version        = "OpenSearch_2.5"

  cluster_config {
    instance_type = "t3.small.search"
    instance_count = 3
    
    zone_awareness_enabled = true
    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  vpc_options {
    subnet_ids = [
      aws_subnet.opensearch_subnet_1.id,
      aws_subnet.opensearch_subnet_2.id,
      aws_subnet.opensearch_subnet_3.id
    ]
    security_group_ids = [aws_security_group.opensearch_sg.id]
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

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  access_policies = <<POLICIES
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.opensearch_domain_name}/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": "${var.allowed_cidr}"
        }
      }
    }
  ]
}
POLICIES

  depends_on = [aws_iam_role.opensearch_snapshot_role]
}

data "aws_caller_identity" "current" {}

resource "null_resource" "register_snapshot_repository" {
  count = var.create_snapshot ? 1 : 0
  
  provisioner "local-exec" {
    command = "python snapshot_repository.py ${aws_opensearch_domain.main.endpoint} ${aws_s3_bucket.snapshot_bucket.bucket} ${aws_iam_role.opensearch_snapshot_role.arn} ${var.aws_region} ${var.master_user_name} ${var.master_user_password}"
  }

  depends_on = [aws_opensearch_domain.main]
}

resource "null_resource" "create_snapshot_management_policy" {
  count = var.create_snapshot_policy ? 1 : 0
  
  provisioner "local-exec" {
    command = "python snapshot_policy.py ${aws_opensearch_domain.main.endpoint} ${var.aws_region} ${var.master_user_name} ${var.master_user_password}"
  }

  depends_on = [null_resource.register_snapshot_repository]
}

resource "aws_iam_user" "opensearch_user" {
  name = "opensearch-user"
  force_destroy = true
}

resource "aws_iam_user_login_profile" "opensearch_user" {
  user    = aws_iam_user.opensearch_user.name
  pgp_key = "keybase:username" // Replace with your PGP key or remove if not needed
  password_reset_required = false
  // If you want to set a specific password, use 'password = "YourPassword123!"'
}

resource "aws_iam_access_key" "opensearch_user" {
  user = aws_iam_user.opensearch_user.name
}

resource "null_resource" "map_iam_user_to_role" {
  provisioner "local-exec" {
    command = "python map_iam_user.py ${aws_opensearch_domain.main.endpoint} ${var.master_user_name} ${var.master_user_password} ${aws_iam_user.opensearch_user.arn} all_access"
  }
  depends_on = [aws_iam_user.opensearch_user, aws_opensearch_domain.main]
} 
variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "opensearch_domain_name" {
  description = "Name of the OpenSearch domain."
  type        = string
  default     = "example-domain"
}

variable "snapshot_bucket_name" {
  description = "Name of the S3 bucket for OpenSearch snapshots."
  type        = string
  default     = "example-opensearch-snapshots"
}

variable "master_user_name" {
  description = "Username for the OpenSearch master user."
  type        = string
  default     = "admin"
}

variable "master_user_password" {
  description = "Password for the OpenSearch master user."
  type        = string
  sensitive   = true
}

variable "allowed_cidr" {
  description = "CIDR block allowed to access the OpenSearch domain."
  type        = string
  default     = "0.0.0.0/0"
}

variable "create_snapshot_now" {
  description = "Whether to trigger a one-time snapshot via Lambda."
  type        = bool
  default     = false
}

variable "restore_snapshot_name" {
  description = "Name of the snapshot to restore (leave empty to skip restore)."
  type        = string
  default     = ""
}

variable "restore_index_name" {
  description = "Name of the index to restore (leave empty to skip restore)."
  type        = string
  default     = ""
} 
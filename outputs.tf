output "opensearch_endpoint" {
  value = aws_opensearch_domain.main.endpoint
}

output "snapshot_bucket_name" {
  value = aws_s3_bucket.snapshot_bucket.bucket
}

output "snapshot_role_arn" {
  value = aws_iam_role.opensearch_snapshot_role.arn
}

output "opensearch_iam_user_arn" {
  value = aws_iam_user.opensearch_user.arn
}

output "opensearch_iam_user_access_key_id" {
  value = aws_iam_access_key.opensearch_user.id
  sensitive = true
}

output "opensearch_iam_user_secret_access_key" {
  value = aws_iam_access_key.opensearch_user.secret
  sensitive = true
} 
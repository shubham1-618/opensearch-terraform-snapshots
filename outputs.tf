output "opensearch_endpoint" {
  value = aws_opensearch_domain.main.endpoint
}

output "snapshot_bucket_name" {
  value = aws_s3_bucket.snapshot_bucket.bucket
}

output "snapshot_role_arn" {
  value = aws_iam_role.opensearch_snapshot_role.arn
} 
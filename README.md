# OpenSearch Snapshot & Restore with Terraform

This project implements automated snapshot and restore capabilities for Amazon OpenSearch using Terraform and the native OpenSearch Snapshot Management feature.

## Features

- Provisions an OpenSearch domain with 3 data nodes
- Sets up fine-grained access control for security
- Configures a VPC with security groups for HTTPS access
- Creates an S3 bucket for snapshot storage with appropriate IAM roles
- Implements OpenSearch's Snapshot Management for automated hourly snapshots
- Configures Index State Management (ISM) policies for hot-to-warm index transitions
- Provides scripts for manual snapshot operations and restoration

## File Structure

- `main.tf` - Terraform configuration for OpenSearch domain, VPC, S3 bucket, and IAM roles
- `variables.tf` - Terraform variables definitions
- `outputs.tf` - Terraform output definitions
- `snapshot_repository.py` - Python script to register a snapshot repository
- `snapshot_policy.py` - Python script to create index templates, ISM policies, and snapshot management policies
- `list_snapshots.py` - Python script to list available snapshots
- `restore.py` - Python script to restore indices from snapshots
- `requirements.txt` - Python dependencies

## Prerequisites

- Terraform
- AWS CLI configured
- Python 3
- Python packages: Install with `pip install -r requirements.txt`

## Variables

Create a `terraform.tfvars` file with the following variables:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region to deploy resources | us-east-1 | No |
| `opensearch_domain_name` | Name of the OpenSearch domain | example-domain | Yes |
| `snapshot_bucket_name` | Name of the S3 bucket for snapshots | example-opensearch-snapshots | Yes |
| `create_snapshot` | Whether to register a snapshot repository | false | No |
| `create_snapshot_policy` | Whether to create a snapshot management policy | false | No |
| `master_user_name` | Username for OpenSearch master user | admin | Yes |
| `master_user_password` | Password for OpenSearch master user | | Yes |
| `allowed_cidr` | CIDR block allowed to access OpenSearch | 0.0.0.0/0 | No |

Example `terraform.tfvars`:
```
aws_region = "us-east-1"
opensearch_domain_name = "my-domain"
snapshot_bucket_name = "my-opensearch-snapshots-123"  # Must be globally unique
master_user_name = "admin"
master_user_password = "YourStrongPassword123!"
allowed_cidr = "10.0.0.0/16"  # Your allowed CIDR block
create_snapshot = true
create_snapshot_policy = true
```

## Step-by-Step Setup

### 1. Prepare Your Environment

```sh
# Clone the repository (if applicable)
git clone <repository-url>
cd <repository-directory>

# Install Python dependencies
pip install -r requirements.txt
```

### 2. Configure Terraform Variables

Create your `terraform.tfvars` file as described above.

### 3. Initialize and Apply Terraform

```sh
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply -auto-approve
```

This will create:
- OpenSearch domain with 3 data nodes
- VPC with subnets and security groups
- S3 bucket for snapshots
- IAM roles for OpenSearch to access S3

### 4. Register Snapshot Repository

**Option 1:** Using Terraform variable
```sh
terraform apply -var="create_snapshot=true"
```

**Option 2:** Manually run the script
```sh
python snapshot_repository.py <opensearch-endpoint> <s3-bucket> <role-arn> <region> <username> <password>
```

Example:
```sh
python snapshot_repository.py search-my-domain-xxxxxx.us-east-1.es.amazonaws.com my-opensearch-snapshots-123 arn:aws:iam::123456789012:role/opensearch-snapshot-role us-east-1 admin YourPassword123!
```

### 5. Create Snapshot Management Policy

**Option 1:** Using Terraform variable
```sh
terraform apply -var="create_snapshot_policy=true"
```

**Option 2:** Manually run the script
```sh
python snapshot_policy.py <opensearch-endpoint> <region> <username> <password>
```

Example:
```sh
python snapshot_policy.py search-my-domain-xxxxxx.us-east-1.es.amazonaws.com us-east-1 admin YourPassword123!
```

## Snapshot Management

The solution implements the Snapshot Management feature as described in the [AWS Blog](https://aws.amazon.com/blogs/big-data/unleash-the-power-of-snapshot-management-to-take-automated-snapshots-using-amazon-opensearch-service/).

### Key Components:

1. **Index Templates**
   - Automatically assigns the `hot` alias to new indices matching the pattern `log*`

2. **Index State Management (ISM) Policy**
   - Moves indices from hot to warm storage after 30 days
   - Updates index aliases during migration

3. **Snapshot Management Policy**
   - Takes hourly snapshots of all "hot" indices
   - Retains up to 48 snapshots (2 days worth)
   - Cleans up old snapshots automatically

## Manual Operations

### List Available Snapshots
```sh
python list_snapshots.py <opensearch-endpoint> <repo-name> <username> <password>
```

Example:
```sh
python list_snapshots.py search-my-domain-xxxxxx.us-east-1.es.amazonaws.com s3-repo admin YourPassword123!
```

### Restore an Index from a Snapshot
```sh
python restore.py <opensearch-endpoint> <repo-name> <snapshot-name> <index-name> <username> <password>
```

Example:
```sh
python restore.py search-my-domain-xxxxxx.us-east-1.es.amazonaws.com s3-repo snapshot-20240607120000 logs-2024-06-07 admin YourPassword123!
```

## Troubleshooting

### Common Issues

1. **Repository Registration Fails**
   - Verify IAM role permissions
   - Check that S3 bucket exists and is accessible
   - Confirm the OpenSearch domain has permissions to assume the IAM role

2. **Snapshot Creation Fails**
   - Check if the repository is correctly registered
   - Verify that the OpenSearch domain has proper VPC connectivity to AWS services

3. **Restore Operation Fails**
   - Verify that the snapshot exists (use `list_snapshots.py`)
   - Check that the index name is correct
   - Ensure sufficient storage space in the OpenSearch domain

### Verifying Snapshot Status

You can verify snapshot status in the OpenSearch Dashboards:
1. Access OpenSearch Dashboards at `https://<opensearch-endpoint>/_dashboards/`
2. Navigate to **Snapshots Management**
3. Check repository and snapshot status

## Notes

- The snapshot repository is named `s3-repo` by default
- Snapshots of indices are taken every hour using the OpenSearch Snapshot Management feature
- The restored index will be named `restored_<original-index-name>` to avoid conflicts
- For production use, consider strengthening the IAM policies and security settings
- Applying `terraform destroy` will remove all resources, including the S3 bucket with snapshots



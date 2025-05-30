# OpenSearch Snapshot Automation with Lambda & Terraform

This solution provisions an Amazon OpenSearch cluster with 3 t3.small nodes, a VPC, security groups, S3 snapshot storage, and automates hourly snapshots using AWS Lambda and EventBridge. IAM roles are created for OpenSearch and Lambda, and you will map the snapshot role in OpenSearch Dashboards for repository access.

## Features
- 3 OpenSearch data nodes (t3.small)
- VPC, subnets, security group (HTTPS open)
- S3 bucket for snapshots
- IAM roles for OpenSearch and Lambda
- Lambda function to trigger snapshots every hour
- **On-demand snapshot creation via Terraform variable**
- **On-demand index restore from snapshot via Terraform variable**
- EventBridge rule for scheduling
- Fine-grained access control (master user)

## File Structure
- `main.tf` - Terraform for all AWS resources
- `variables.tf` - Terraform variables
- `lambda_function.py` - Python Lambda function for snapshot automation
- `restore_function.py` - Python Lambda function for restoring an index from a snapshot
- `requirements.txt` - Python dependencies for Lambda

## Prerequisites
- Terraform
- AWS CLI configured
- Python 3
- Docker (for packaging Lambda with dependencies)

## Variables

Add these to your `terraform.tfvars`:

| Variable                | Description                                                      | Default                  |
|-------------------------|------------------------------------------------------------------|--------------------------|
| aws_region              | AWS region to deploy resources                                   | us-east-1                |
| opensearch_domain_name  | Name of the OpenSearch domain                                    | example-domain           |
| snapshot_bucket_name    | Name of the S3 bucket for OpenSearch snapshots                   | example-opensearch-snapshots |
| master_user_name        | Username for the OpenSearch master user                          | admin                    |
| master_user_password    | Password for the OpenSearch master user                          | (required)               |
| allowed_cidr            | CIDR block allowed to access the OpenSearch domain               | 0.0.0.0/0                |
| create_snapshot_now     | **Set to true to trigger a one-time snapshot via Lambda**         | false                    |
| restore_snapshot_name   | **Name of the snapshot to restore (leave empty to skip restore)**| ""                       |
| restore_index_name      | **Name of the index to restore (leave empty to skip restore)**   | ""                       |

### Example `terraform.tfvars`
```hcl
aws_region = "us-east-1"
opensearch_domain_name = "my-domain"
snapshot_bucket_name = "my-opensearch-snapshots-123"  # Must be globally unique
master_user_name = "admin"
master_user_password = "YourStrongPassword123!"
allowed_cidr = "0.0.0.0/0"  # Or restrict as needed
create_snapshot_now = true  # Set to true to trigger a snapshot once
restore_snapshot_name = "snapshot-20240610120000"  # Set to restore a snapshot
restore_index_name = "my-index"  # Set to restore this index from the snapshot
```

## Setup Steps

### 1. Configure Variables
Edit or create `terraform.tfvars` as above.

### 2. Build Lambda Deployment Packages
**For snapshot Lambda:**
```sh
pip install -r requirements.txt -t python/
cp lambda_function.py python/
cd python
zip -r ../lambda_function.zip .
cd ..
```
**For restore Lambda:**
```sh
pip install -r requirements.txt -t python/
cp restore_function.py python/
cd python
zip -r ../restore_function.zip .
cd ..
```
Or use Docker for a clean build:
```sh
docker run --rm -v "$PWD":/var/task lambci/lambda:build-python3.9 pip install -r requirements.txt -t python/
cp lambda_function.py python/
cd python
zip -r ../lambda_function.zip .
cd ..
# For restore Lambda
cp restore_function.py python/
cd python
zip -r ../restore_function.zip .
cd ..
```

### 3. Deploy Infrastructure
```sh
terraform init
terraform apply -auto-approve
```
- **Hourly snapshots** will be triggered by the Lambda function via EventBridge.
- **On-demand snapshot** will be triggered if `create_snapshot_now = true`.
- **On-demand restore** will be triggered if both `restore_snapshot_name` and `restore_index_name` are set.

### 4. Map IAM Role in OpenSearch Dashboards
1. Log in to OpenSearch Dashboards as the master user.
2. Go to **Security > Roles**.
3. Find or create a role for snapshot management (e.g., `snapshot_manager`).
4. In **Mapped users** or **Backend roles**, add the ARN of the snapshot IAM role (output as `snapshot_role_arn`).
5. Save the mapping.

### 5. Verify Snapshots and Restores
- Snapshots will be visible in the S3 bucket and OpenSearch Dashboards > Snapshots.
- Restored indices will be named `restored_<index_name>`.

## Notes
- The Lambda function registers the snapshot repository and triggers a snapshot each run.
- The restore Lambda restores the specified index from the specified snapshot.
- You can adjust the EventBridge schedule in `main.tf` as needed.
- For production, restrict security group and IAM permissions as appropriate.

## Cleanup
To remove all resources:
```sh
terraform destroy -auto-approve
``` 
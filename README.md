# OpenSearch Snapshot & Restore with Terraform

This project implements automated snapshot and restore capabilities for Amazon OpenSearch using Terraform and the native OpenSearch Snapshot Management feature. It now also automates IAM user creation and mapping to OpenSearch roles.

## Features

- Provisions an OpenSearch domain with 3 data nodes
- Sets up fine-grained access control for security
- Configures a VPC with security groups for HTTPS access
- Creates an S3 bucket for snapshot storage with appropriate IAM roles
- Implements OpenSearch's Snapshot Management for automated hourly snapshots
- Configures Index State Management (ISM) policies for hot-to-warm index transitions
- Provides scripts for manual snapshot operations and restoration
- **Automatically creates an IAM user and maps it to an OpenSearch role using the Security API**

## File Structure

- `main.tf` - Terraform configuration for OpenSearch domain, VPC, S3 bucket, IAM roles, IAM user, and automation
- `variables.tf` - Terraform variables definitions
- `outputs.tf` - Terraform output definitions
- `snapshot_repository.py` - Python script to register a snapshot repository
- `snapshot_policy.py` - Python script to create index templates, ISM policies, and snapshot management policies
- `list_snapshots.py` - Python script to list available snapshots
- `restore.py` - Python script to restore indices from snapshots
- `map_iam_user.py` - **Python script to map the IAM user to an OpenSearch role automatically**
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
```hcl
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
- **IAM user for OpenSearch access**
- **Automatically map the IAM user to the `all_access` role in OpenSearch using the Security API**

### 4. How the Automation Works

- After Terraform creates the IAM user and OpenSearch domain, it runs `map_iam_user.py` automatically.
- This script uses the OpenSearch Security API to add the IAM user's ARN as a backend role to the `all_access` role.
- No manual mapping in OpenSearch Dashboards is required.

### 5. Outputs

After `terraform apply`, you will see outputs including:
- OpenSearch endpoint
- Snapshot bucket name
- Snapshot role ARN
- **IAM user ARN**
- **IAM user access key and secret** (for programmatic access)

### 6. Accessing OpenSearch

- Use the OpenSearch endpoint output to access OpenSearch Dashboards.
- Log in as the master user (from your variables) for full admin access.
- The IAM user is now mapped to the `all_access` role and can be used for API access or mapped to other roles as needed.

### 7. Manual Operations (Optional)

#### List Available Snapshots
```sh
python list_snapshots.py <opensearch-endpoint> <repo-name> <username> <password>
```

#### Restore an Index from a Snapshot
```sh
python restore.py <opensearch-endpoint> <repo-name> <snapshot-name> <index-name> <username> <password>
```

### 8. Customizing Role Mapping

- By default, the IAM user is mapped to the `all_access` role.
- To map to a different role, change the role name in the `null_resource` in `main.tf` and re-apply.
- You can also use `map_iam_user.py` manually:
  ```sh
  python map_iam_user.py <opensearch-endpoint> <master-username> <master-password> <iam-user-arn> <role-name>
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

4. **IAM User Mapping Fails**
   - Check the output of the `map_iam_user.py` script for errors
   - Ensure the OpenSearch endpoint, master username, and password are correct
   - Make sure the OpenSearch domain is fully available before mapping
   - You can re-run the script manually if needed

### Verifying Snapshot and IAM User Mapping Status

- **Snapshot:**
  1. Access OpenSearch Dashboards at `https://<opensearch-endpoint>/_dashboards/`
  2. Navigate to **Snapshots Management**
  3. Check repository and snapshot status

- **IAM User Mapping:**
  1. Access OpenSearch Dashboards as the master user
  2. Go to **Security → Roles → all_access → Mapped users**
  3. You should see the IAM user's ARN listed

## Notes

- The snapshot repository is named `s3-repo` by default
- Snapshots of indices are taken every hour using the OpenSearch Snapshot Management feature
- The restored index will be named `restored_<original-index-name>` to avoid conflicts
- For production use, consider strengthening the IAM policies and security settings
- Applying `terraform destroy` will remove all resources, including the S3 bucket with snapshots and the IAM user

---

**This setup is now fully automated for OpenSearch, IAM, and snapshot management!**



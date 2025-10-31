# Bolt IT Terraform Infrastructure

This directory contains Terraform configuration for provisioning Bolt IT infrastructure on AWS.

## Prerequisites

1. **Terraform**: Version 1.5.0 or later
   ```bash
   terraform version
   ```

2. **AWS CLI**: Configured with appropriate credentials
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

3. **Required Permissions**: IAM user/role must have permissions to create:
   - S3 buckets
   - KMS keys
   - ECR repositories
   - IAM roles and policies
   - EC2 instances and security groups
   - Secrets Manager secrets
   - CloudWatch log groups
   - SNS topics

## Initial Setup

### 1. Create Terraform State Backend

Before running Terraform, create the S3 bucket and DynamoDB table for remote state:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://boltit-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket boltit-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name boltit-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

### 2. Configure Variables

Edit `pilot.tfvars` with your actual values:
- VPC ID and subnet ID
- EC2 key pair name (create one if needed)
- Admin CIDR blocks for SSH access
- Alarm email address

```bash
cp pilot.tfvars pilot.tfvars.local
vim pilot.tfvars.local
```

### 3. Initialize Terraform

```bash
terraform init
```

## Deployment

### Pilot Environment

```bash
# Review the plan
terraform plan -var-file=pilot.tfvars

# Apply the configuration
terraform apply -var-file=pilot.tfvars

# Save outputs to ENV file
terraform output -json > outputs.json
```

### After Deployment

1. **Update ENV file**:
   ```bash
   # Extract outputs and update infra/ENV.pilot
   terraform output kms_key_arn
   terraform output s3_artifacts_bucket
   # ... copy all outputs to infra/ENV.pilot
   ```

2. **Configure ECR authentication**:
   ```bash
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin \
     $(terraform output -raw ecr_repository_api_url | cut -d'/' -f1)
   ```

3. **SSH to EC2 instance**:
   ```bash
   ssh -i ~/.ssh/boltit-pilot-key.pem ubuntu@$(terraform output -raw ec2_public_ip)
   ```

4. **Verify cloud-init completed**:
   ```bash
   ssh ubuntu@<ec2-ip>
   sudo tail -f /var/log/cloud-init-output.log
   docker --version
   docker compose version
   ```

## Resource Overview

### Created Resources

- **KMS Key**: Encryption key for S3 and Secrets Manager
- **S3 Buckets**:
  - `boltit-artifacts-<env>`: Model artifacts and retrain outputs
  - `boltit-backups-<env>`: Database backups (with lifecycle to Glacier)
- **ECR Repositories**: `boltit-api`, `boltit-model`, `boltit-worker`
- **IAM Role**: EC2 instance role with least-privilege permissions
- **Security Group**: Configured for HTTP/HTTPS/SSH/API access
- **EC2 Instance**: Ubuntu 22.04 with cloud-init bootstrap
- **Secrets Manager**: Database credentials and API master key
- **CloudWatch Log Groups**: For API, model, and worker logs
- **SNS Topic**: For CloudWatch alarms

### Cost Estimate (Pilot)

- EC2 m6i.large: ~$70/month (on-demand)
- S3 storage: ~$5/month (100 GB)
- ECR storage: ~$3/month (30 GB)
- Secrets Manager: ~$2/month (2 secrets)
- KMS: ~$1/month
- Data transfer: Variable
- **Total**: ~$80-100/month

## Terraform Commands

### Standard Operations

```bash
# Initialize (after changes to backend or providers)
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan changes
terraform plan -var-file=pilot.tfvars

# Apply changes
terraform apply -var-file=pilot.tfvars

# Show current state
terraform show

# List resources
terraform state list

# Output specific value
terraform output ecr_repository_api_url
```

### Destruction

**WARNING**: This will destroy all infrastructure!

```bash
# Plan destruction
terraform plan -destroy -var-file=pilot.tfvars

# Destroy resources
terraform destroy -var-file=pilot.tfvars
```

Before destroying:
1. Backup all data from S3 buckets
2. Export database if needed
3. Save any important logs
4. Remove any manually created resources

## Troubleshooting

### State Lock Issues

If Terraform is interrupted, the state may be locked:

```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### Permission Errors

Verify IAM permissions:

```bash
aws iam get-user
aws sts get-caller-identity
```

### EC2 Instance Not Starting

Check cloud-init logs:

```bash
ssh ubuntu@<ec2-ip>
sudo cat /var/log/cloud-init-output.log
sudo systemctl status docker
```

### KMS Key Policy Issues

If services can't decrypt data:

1. Verify KMS key policy in `../kms_policy.json`
2. Check IAM role has KMS permissions
3. Verify service principal is allowed

## Security Considerations

1. **State File**: Contains sensitive data - never commit to version control
2. **Variables**: Use `pilot.tfvars.local` (gitignored) for sensitive values
3. **Backend**: S3 bucket should have encryption and versioning
4. **KMS Keys**: Rotate quarterly, enable automatic rotation
5. **IAM Roles**: Follow least-privilege principle
6. **Security Groups**: Restrict admin access to known IPs only

## Maintenance

### Updating Resources

To update infrastructure:

1. Modify Terraform files
2. Run `terraform plan -var-file=pilot.tfvars`
3. Review changes carefully
4. Run `terraform apply -var-file=pilot.tfvars`

### Key Rotation

KMS keys are configured for automatic rotation. To manually rotate:

```bash
aws kms enable-key-rotation --key-id <key-id>
```

### Upgrading Providers

Update provider versions in `main.tf`:

```bash
terraform init -upgrade
```

## Integration with CI/CD

For automated deployments, use a service account with limited permissions:

```bash
# GitHub Actions example
export AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }}
export AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}
terraform apply -var-file=pilot.tfvars -auto-approve
```

## Support

For issues:
- Check AWS CloudTrail for API errors
- Review Terraform logs: `TF_LOG=DEBUG terraform apply`
- Contact: devops@cursor.example.com

## References

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)

---

Last Updated: 2025-10-31

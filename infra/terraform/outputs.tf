output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.boltit.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.boltit.arn
}

output "kms_key_alias" {
  description = "KMS key alias"
  value       = aws_kms_alias.boltit.name
}

output "s3_artifacts_bucket" {
  description = "S3 artifacts bucket name"
  value       = aws_s3_bucket.artifacts.id
}

output "s3_artifacts_bucket_arn" {
  description = "S3 artifacts bucket ARN"
  value       = aws_s3_bucket.artifacts.arn
}

output "s3_backups_bucket" {
  description = "S3 backups bucket name"
  value       = aws_s3_bucket.backups.id
}

output "s3_backups_bucket_arn" {
  description = "S3 backups bucket ARN"
  value       = aws_s3_bucket.backups.arn
}

output "ecr_repository_api_url" {
  description = "ECR repository URL for API image"
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_model_url" {
  description = "ECR repository URL for model image"
  value       = aws_ecr_repository.model.repository_url
}

output "ecr_repository_worker_url" {
  description = "ECR repository URL for worker image"
  value       = aws_ecr_repository.worker.repository_url
}

output "ec2_instance_role_arn" {
  description = "EC2 instance IAM role ARN"
  value       = aws_iam_role.ec2_instance.arn
}

output "ec2_instance_role_name" {
  description = "EC2 instance IAM role name"
  value       = aws_iam_role.ec2_instance.name
}

output "ec2_instance_profile_arn" {
  description = "EC2 instance profile ARN"
  value       = aws_iam_instance_profile.ec2_instance.arn
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name"
  value       = aws_iam_instance_profile.ec2_instance.name
}

output "security_group_id" {
  description = "Security group ID for EC2 instance"
  value       = aws_security_group.ec2_instance.id
}

output "ec2_instance_id" {
  description = "EC2 instance ID (if created)"
  value       = var.create_ec2_instance ? aws_instance.boltit[0].id : null
}

output "ec2_public_ip" {
  description = "EC2 instance public IP (if created)"
  value       = var.create_ec2_instance ? aws_instance.boltit[0].public_ip : null
}

output "ec2_private_ip" {
  description = "EC2 instance private IP (if created)"
  value       = var.create_ec2_instance ? aws_instance.boltit[0].private_ip : null
}

output "secret_db_credentials_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_db_credentials_name" {
  description = "Secrets Manager name for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "secret_api_master_key_arn" {
  description = "Secrets Manager ARN for API master key"
  value       = aws_secretsmanager_secret.api_master_key.arn
}

output "secret_api_master_key_name" {
  description = "Secrets Manager name for API master key"
  value       = aws_secretsmanager_secret.api_master_key.name
}

output "cloudwatch_log_group_api" {
  description = "CloudWatch Log Group for API"
  value       = aws_cloudwatch_log_group.api.name
}

output "cloudwatch_log_group_model" {
  description = "CloudWatch Log Group for model service"
  value       = aws_cloudwatch_log_group.model.name
}

output "cloudwatch_log_group_worker" {
  description = "CloudWatch Log Group for worker"
  value       = aws_cloudwatch_log_group.worker.name
}

output "sns_alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = aws_sns_topic.alarms.arn
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = <<-EOT
    BoltIT ${var.environment} Infrastructure Deployed Successfully!
    
    KMS Key: ${aws_kms_key.boltit.arn}
    S3 Artifacts: ${aws_s3_bucket.artifacts.id}
    S3 Backups: ${aws_s3_bucket.backups.id}
    ECR API: ${aws_ecr_repository.api.repository_url}
    ECR Model: ${aws_ecr_repository.model.repository_url}
    ECR Worker: ${aws_ecr_repository.worker.repository_url}
    ${var.create_ec2_instance ? "EC2 Instance: ${aws_instance.boltit[0].id} (${aws_instance.boltit[0].public_ip})" : ""}
    
    Next Steps:
    1. Update infra/ENV.${var.environment} with these values
    2. Build and push Docker images to ECR
    3. SSH to EC2 instance and run deployment
    4. Configure CloudWatch alarms
    5. Set up monitoring dashboards
  EOT
}

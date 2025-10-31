terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "boltit-terraform-state"
    key            = "pilot/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "boltit-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "BoltIT"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "cursor-devops"
      CostCenter  = "engineering"
    }
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# KMS KEY
# =============================================================================

resource "aws_kms_key" "boltit" {
  description             = "BoltIT ${var.environment} encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "boltit-${var.environment}-key"
  }
}

resource "aws_kms_alias" "boltit" {
  name          = "alias/boltit-${var.environment}"
  target_key_id = aws_kms_key.boltit.key_id
}

# =============================================================================
# S3 BUCKETS
# =============================================================================

resource "aws_s3_bucket" "artifacts" {
  bucket = "boltit-artifacts-${var.environment}"

  tags = {
    Name        = "boltit-artifacts-${var.environment}"
    Description = "Model artifacts and retrain outputs"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.boltit.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "backups" {
  bucket = "boltit-backups-${var.environment}"

  tags = {
    Name        = "boltit-backups-${var.environment}"
    Description = "Database backups and disaster recovery"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.boltit.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "archive-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# =============================================================================
# ECR REPOSITORIES
# =============================================================================

resource "aws_ecr_repository" "api" {
  name                 = "boltit-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.boltit.arn
  }

  tags = {
    Name = "boltit-api"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_repository" "model" {
  name                 = "boltit-model"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.boltit.arn
  }

  tags = {
    Name = "boltit-model"
  }
}

resource "aws_ecr_lifecycle_policy" "model" {
  repository = aws_ecr_repository.model.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_repository" "worker" {
  name                 = "boltit-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.boltit.arn
  }

  tags = {
    Name = "boltit-worker"
  }
}

resource "aws_ecr_lifecycle_policy" "worker" {
  repository = aws_ecr_repository.worker.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# =============================================================================
# IAM ROLES AND POLICIES
# =============================================================================

# EC2 Instance Role
resource "aws_iam_role" "ec2_instance" {
  name = "ec2-boltit-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ec2-boltit-${var.environment}-role"
  }
}

resource "aws_iam_role_policy" "ec2_instance" {
  name = "ec2-boltit-${var.environment}-policy"
  role = aws_iam_role.ec2_instance.id

  policy = templatefile("${path.module}/../iam_policy.json", {
    artifacts_bucket_arn = aws_s3_bucket.artifacts.arn
    backups_bucket_arn   = aws_s3_bucket.backups.arn
    kms_key_arn          = aws_kms_key.boltit.arn
    aws_account_id       = data.aws_caller_identity.current.account_id
    aws_region           = var.aws_region
    environment          = var.environment
  })
}

resource "aws_iam_instance_profile" "ec2_instance" {
  name = "ec2-boltit-${var.environment}-profile"
  role = aws_iam_role.ec2_instance.name
}

# Attach AWS managed policy for SSM Session Manager
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# =============================================================================
# SECRETS MANAGER
# =============================================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "boltit/${var.environment}/db-credentials"
  description = "PostgreSQL database credentials"
  kms_key_id  = aws_kms_key.boltit.id

  tags = {
    Name = "boltit-${var.environment}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "boltit_admin"
    password = random_password.db_password.result
    host     = "localhost"  # Update if using RDS
    port     = 5432
    database = "boltit"
  })
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "api_master_key" {
  name        = "boltit/${var.environment}/api-master-key"
  description = "Master key for API key generation"
  kms_key_id  = aws_kms_key.boltit.id

  tags = {
    Name = "boltit-${var.environment}-api-master-key"
  }
}

resource "aws_secretsmanager_secret_version" "api_master_key" {
  secret_id = aws_secretsmanager_secret.api_master_key.id
  secret_string = jsonencode({
    master_key = random_password.api_master_key.result
  })
}

resource "random_password" "api_master_key" {
  length  = 64
  special = true
}

# =============================================================================
# SECURITY GROUP
# =============================================================================

resource "aws_security_group" "ec2_instance" {
  name        = "boltit-${var.environment}-sg"
  description = "Security group for BoltIT EC2 instance"
  vpc_id      = var.vpc_id

  # SSH access (restricted to admin IPs)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "SSH access from admin IPs"
  }

  # HTTP/HTTPS from anywhere (or ALB security group in production)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allow_http_from
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allow_https_from
    description = "HTTPS access"
  }

  # API port
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.allow_api_from
    description = "API access"
  }

  # Prometheus metrics (restricted)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "Prometheus metrics"
  }

  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "boltit-${var.environment}-sg"
  }
}

# =============================================================================
# EC2 INSTANCE (optional - can be provisioned separately)
# =============================================================================

resource "aws_instance" "boltit" {
  count = var.create_ec2_instance ? 1 : 0

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ec2_instance.id]
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance.name

  user_data = templatefile("${path.module}/../../deploy/cloud-init.yml", {
    environment          = var.environment
    ecr_api_uri          = aws_ecr_repository.api.repository_url
    ecr_model_uri        = aws_ecr_repository.model.repository_url
    ecr_worker_uri       = aws_ecr_repository.worker.repository_url
    s3_artifacts_bucket  = aws_s3_bucket.artifacts.id
    secret_db_name       = aws_secretsmanager_secret.db_credentials.name
    secret_api_key_name  = aws_secretsmanager_secret.api_master_key.name
    aws_region           = var.aws_region
  })

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = aws_kms_key.boltit.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "boltit-${var.environment}-instance"
  }
}

# =============================================================================
# CLOUDWATCH LOG GROUPS
# =============================================================================

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/boltit/${var.environment}/api"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.boltit.arn

  tags = {
    Name = "boltit-${var.environment}-api-logs"
  }
}

resource "aws_cloudwatch_log_group" "model" {
  name              = "/aws/boltit/${var.environment}/model"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.boltit.arn

  tags = {
    Name = "boltit-${var.environment}-model-logs"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/boltit/${var.environment}/worker"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.boltit.arn

  tags = {
    Name = "boltit-${var.environment}-worker-logs"
  }
}

# =============================================================================
# SNS TOPIC FOR ALARMS
# =============================================================================

resource "aws_sns_topic" "alarms" {
  name              = "boltit-${var.environment}-alarms"
  kms_master_key_id = aws_kms_key.boltit.id

  tags = {
    Name = "boltit-${var.environment}-alarms"
  }
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

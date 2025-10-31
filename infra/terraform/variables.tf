variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (pilot, dev, staging, prod)"
  type        = string
  default     = "pilot"
}

variable "vpc_id" {
  description = "VPC ID for EC2 instance and security groups"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.large"
}

variable "key_pair_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed for admin access (SSH, metrics)"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "allow_http_from" {
  description = "CIDR blocks allowed for HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_https_from" {
  description = "CIDR blocks allowed for HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allow_api_from" {
  description = "CIDR blocks allowed for API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarms (optional)"
  type        = string
  default     = ""
}

variable "create_ec2_instance" {
  description = "Whether to create EC2 instance (set false if provisioning separately)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

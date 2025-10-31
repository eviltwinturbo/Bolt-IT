# Bolt IT Pilot Environment Configuration

environment = "pilot"
aws_region  = "us-east-1"

# Network Configuration
# Replace with your actual VPC and subnet IDs
vpc_id    = "vpc-0123456789abcdef0"
subnet_id = "subnet-0123456789abcdef0"

# EC2 Configuration
instance_type      = "m6i.large"
key_pair_name      = "boltit-pilot-key"
create_ec2_instance = true

# Access Control
admin_cidr_blocks = [
  "10.0.0.0/8",          # Internal network
  "203.0.113.0/24",      # Office IP range (example)
]

allow_http_from = ["0.0.0.0/0"]
allow_https_from = ["0.0.0.0/0"]
allow_api_from = ["0.0.0.0/0"]

# Monitoring
log_retention_days = 30
alarm_email        = "devops@cursor.example.com"

# Additional Tags
tags = {
  Pilot      = "true"
  Compliance = "none"
  Backup     = "daily"
}

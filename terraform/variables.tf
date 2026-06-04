variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  description = "CIDR block for production VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for production subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_secondary" {
  description = "CIDR block for secondary production subnet (required for ALB HA)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_private_cidr" {
  description = "CIDR block for primary private subnet (ECS tasks/data plane)"
  type        = string
  default     = "10.0.11.0/24"
}

variable "subnet_private_cidr_secondary" {
  description = "CIDR block for secondary private subnet (ECS tasks/data plane)"
  type        = string
  default     = "10.0.12.0/24"
}

variable "aws_availability_zone" {
  description = "aws availability zone"
  type        = string
}

variable "aws_availability_zone_secondary" {
  description = "Secondary AWS availability zone"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access. Leave empty to disable SSH ingress."
  type        = list(string)
  default     = []
}

variable "site_prefix" {
  description = "Prefix for naming of resources"
  default     = "scholarspace"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ACM certificate ARN used for ALB HTTPS listener. Leave empty to run HTTP only."
  type        = string
  default     = ""
}

# ── EC2 ──────────────────────────────────────────────────────────────────────

variable "instance_ami" {
  default  = null
  type     = string
  nullable = true
}

variable "instance_type" {
  description = "EC2 instance type used for each environment"
  default     = "c7i.xlarge"
  type        = string
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size for the EC2 instance in GiB"
  default     = 80
  type        = number
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  default     = "gp3"
  type        = string
}

variable "key_name" {
  description = "Name for Terraform-managed EC2 key pair"
  default     = "scholarspace-prod-key"
  type        = string
}

variable "public_key_path" {
  description = "Absolute path to the SSH public key (.pub) used for EC2 access"
  default     = "~/.ssh/id_rsa.pub"
  type        = string
}

variable "repo_clone_url" {
  description = "Repository URL cloned on instance boot"
  default     = "https://github.com/gwu-libraries/scholarspace-5-test.git"
  type        = string
}

variable "deploy_git_ref" {
  description = "Git ref (branch/tag/sha) deployed on instance boot"
  default     = "react-av-viewers"
  type        = string
}

# ── SSM / S3 ─────────────────────────────────────────────────────────────────

variable "ssm_env_parameter_name" {
  description = "SSM Parameter Store name containing full .env content as SecureString"
  type        = string
}

variable "ssm_env_file_path" {
  description = "Path to the production env file whose contents are written to SSM SecureString"
  type        = string
  default     = "../.env"
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_prefix" {
  type    = string
  default = ""
}

# ── ECS Sidekiq ──────────────────────────────────────────────────────────────

variable "sidekiq_image" {
  description = "Full image URI used by ECS Sidekiq tasks. Defaults to the Terraform-managed ECR repository with :latest tag."
  type        = string
  default     = ""
}

variable "sidekiq_task_cpu" {
  description = "CPU units for standard Sidekiq ECS tasks"
  type        = number
  default     = 1024
}

variable "sidekiq_task_memory" {
  description = "Memory (MiB) for standard Sidekiq ECS tasks"
  type        = number
  default     = 2048
}

variable "sidekiq_whisper_task_cpu" {
  description = "CPU units for whisper Sidekiq ECS tasks"
  type        = number
  default     = 2048
}

variable "sidekiq_whisper_task_memory" {
  description = "Memory (MiB) for whisper Sidekiq ECS tasks"
  type        = number
  default     = 4096
}

variable "sidekiq_pdf_text_task_cpu" {
  description = "CPU units for PDF text extraction Sidekiq ECS tasks"
  type        = number
  default     = 1024
}

variable "sidekiq_pdf_text_task_memory" {
  description = "Memory (MiB) for PDF text extraction Sidekiq ECS tasks"
  type        = number
  default     = 2048
}

variable "sidekiq_default_desired_count" {
  description = "Desired task count for default Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_default_min_capacity" {
  description = "Minimum autoscaling capacity for default Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_default_max_capacity" {
  description = "Maximum autoscaling capacity for default Sidekiq service"
  type        = number
  default     = 6
}

variable "sidekiq_whisper_desired_count" {
  description = "Desired task count for whisper Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_whisper_min_capacity" {
  description = "Minimum autoscaling capacity for whisper Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_whisper_max_capacity" {
  description = "Maximum autoscaling capacity for whisper Sidekiq service"
  type        = number
  default     = 4
}

variable "sidekiq_pdf_text_desired_count" {
  description = "Desired task count for PDF text extraction Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_pdf_text_min_capacity" {
  description = "Minimum autoscaling capacity for PDF text extraction Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_pdf_text_max_capacity" {
  description = "Maximum autoscaling capacity for PDF text extraction Sidekiq service"
  type        = number
  default     = 4
}

variable "sidekiq_target_cpu_utilization" {
  description = "Target average CPU utilization percent for Sidekiq autoscaling"
  type        = number
  default     = 70
}

variable "sidekiq_target_memory_utilization" {
  description = "Target average memory utilization percent for Sidekiq autoscaling"
  type        = number
  default     = 80
}

variable "sidekiq_assign_public_ip" {
  description = "Assign public IPs to Sidekiq tasks. Keep false when using private subnets with NAT."
  type        = bool
  default     = false
}

variable "sidekiq_log_retention_days" {
  description = "CloudWatch log retention in days for Sidekiq ECS services"
  type        = number
  default     = 30
}

variable "sidekiq_enable_log_based_autoscaling" {
  description = "Enable log-pattern based scale-out policies for Sidekiq ECS services"
  type        = bool
  default     = false
}

variable "sidekiq_log_autoscaling_pattern" {
  description = "CloudWatch log filter pattern that indicates Sidekiq queue pressure and should trigger scale-out"
  type        = string
  default     = "\"queue_latency_high\""
}

variable "sidekiq_log_autoscaling_period_seconds" {
  description = "CloudWatch alarm period for Sidekiq log-pattern scale-out metric"
  type        = number
  default     = 60
}

variable "sidekiq_log_autoscaling_evaluation_periods" {
  description = "Number of periods evaluated before triggering Sidekiq log-pattern scale-out alarm"
  type        = number
  default     = 2
}

variable "sidekiq_log_autoscaling_threshold" {
  description = "Minimum number of matching log events per period that triggers Sidekiq scale-out"
  type        = number
  default     = 5
}

variable "sidekiq_log_scale_out_adjustment" {
  description = "How many tasks to add when the Sidekiq log-pattern scale-out alarm fires"
  type        = number
  default     = 1
}

variable "sidekiq_log_scale_out_cooldown_seconds" {
  description = "Cooldown in seconds after a Sidekiq log-pattern scale-out action"
  type        = number
  default     = 120
}

variable "web_image" {
  description = "Full image URI used by ECS web tasks. Defaults to the Terraform-managed ECR repository with :latest tag."
  type        = string
  default     = ""
}

variable "web_task_cpu" {
  description = "CPU units for Rails web ECS tasks"
  type        = number
  default     = 2048
}

variable "web_task_memory" {
  description = "Memory (MiB) for Rails web ECS tasks"
  type        = number
  default     = 4096
}

variable "web_desired_count" {
  description = "Desired task count for Rails web ECS service"
  type        = number
  default     = 2
}

variable "web_min_capacity" {
  description = "Minimum autoscaling capacity for Rails web ECS service"
  type        = number
  default     = 2
}

variable "web_max_capacity" {
  description = "Maximum autoscaling capacity for Rails web ECS service"
  type        = number
  default     = 6
}

variable "web_target_cpu_utilization" {
  description = "Target average CPU utilization percent for Rails web autoscaling"
  type        = number
  default     = 60
}

variable "web_target_memory_utilization" {
  description = "Target average memory utilization percent for Rails web autoscaling"
  type        = number
  default     = 75
}

variable "web_assign_public_ip" {
  description = "Assign public IPs to Rails web tasks. Keep false when using private subnets with NAT."
  type        = bool
  default     = false
}

variable "web_log_retention_days" {
  description = "CloudWatch log retention in days for Rails web ECS service"
  type        = number
  default     = 30
}

variable "fits_image" {
  description = "Full image URI used by ECS FITS tasks. Defaults to the Terraform-managed ECR repository with :latest tag."
  type        = string
  default     = ""
}

variable "fits_task_cpu" {
  description = "CPU units for FITS ECS tasks"
  type        = number
  default     = 1024
}

variable "fits_task_memory" {
  description = "Memory (MiB) for FITS ECS tasks"
  type        = number
  default     = 2048
}

variable "fits_desired_count" {
  description = "Desired task count for FITS ECS service"
  type        = number
  default     = 2
}

variable "fits_min_capacity" {
  description = "Minimum autoscaling capacity for FITS ECS service"
  type        = number
  default     = 2
}

variable "fits_max_capacity" {
  description = "Maximum autoscaling capacity for FITS ECS service"
  type        = number
  default     = 8
}

variable "fits_target_cpu_utilization" {
  description = "Target average CPU utilization percent for FITS autoscaling"
  type        = number
  default     = 70
}

variable "fits_target_memory_utilization" {
  description = "Target average memory utilization percent for FITS autoscaling"
  type        = number
  default     = 80
}

variable "fits_assign_public_ip" {
  description = "Assign public IPs to FITS tasks. Keep false when using private subnets with NAT."
  type        = bool
  default     = false
}

variable "fits_log_retention_days" {
  description = "CloudWatch log retention in days for FITS ECS service"
  type        = number
  default     = 30
}

variable "fits_service_discovery_namespace" {
  description = "Suffix for private DNS namespace used by ECS service discovery for internal services"
  type        = string
  default     = "internal"
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "aurora_database_name" {
  description = "Name of the initial database created in Aurora"
  type        = string
  default     = "scholarspace_production"
}

variable "aurora_master_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "scholarspace"
}

variable "aurora_master_password" {
  description = "Master password for the Aurora cluster. Must match DB_PASSWORD in your SSM env blob."
  type        = string
  sensitive   = true
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora cluster members"
  type        = string
  default     = "db.t4g.medium"
}

variable "aurora_instance_count" {
  description = "Number of Aurora cluster instances (1 = writer only; 2+ adds readers)"
  type        = number
  default     = 1
}

variable "aurora_backup_retention_days" {
  description = "Number of days to retain automated Aurora backups"
  type        = number
  default     = 7
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot on cluster deletion. Set false in production."
  type        = bool
  default     = false
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection on the Aurora cluster."
  type        = bool
  default     = true
}

# ── ElastiCache ──────────────────────────────────────────────────────────────

variable "elasticache_node_type" {
  description = "ElastiCache node type for the managed Redis cluster"
  type        = string
  default     = "cache.t4g.micro"
}

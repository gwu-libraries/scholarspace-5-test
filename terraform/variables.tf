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

variable "site_prefix" {
  description = "Prefix for naming of resources"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ACM certificate ARN used for ALB HTTPS listener. Leave empty to run HTTP only."
  type        = string
  default     = ""
}

# ── SSM / S3 ─────────────────────────────────────────────────────────────────

variable "ssm_env_parameter_name" {
  description = "SSM Parameter Store name containing full env file content as SecureString"
  type        = string
}

variable "ssm_env_file_path" {
  description = "Path to the production env file whose contents are written to SSM SecureString"
  type        = string
  default     = "../prod.env"
}

variable "s3_bucket_name" {
  type = string
}

variable "s3_prefix" {
  type    = string
  default = ""
}

variable "sidekiq_default_image" {
  description = "Full image URI for the default Sidekiq ECS service. Must be explicitly set."
  type        = string
  default     = ""

  validation {
    condition     = length(trimspace(var.sidekiq_default_image)) > 0
    error_message = "sidekiq_default_image must be set to a non-empty image URI."
  }
}

variable "sidekiq_whisper_image" {
  description = "Full image URI for the whisper Sidekiq ECS service. Must be explicitly set."
  type        = string
  default     = ""

  validation {
    condition     = length(trimspace(var.sidekiq_whisper_image)) > 0
    error_message = "sidekiq_whisper_image must be set to a non-empty image URI."
  }
}

variable "sidekiq_ocr_text_image" {
  description = "Full image URI for the OCR text extraction Sidekiq ECS service. Must be explicitly set."
  type        = string
  default     = ""

  validation {
    condition     = length(trimspace(var.sidekiq_ocr_text_image)) > 0
    error_message = "sidekiq_ocr_text_image must be set to a non-empty image URI."
  }
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

variable "sidekiq_container_stop_timeout_seconds" {
  description = "ECS container stop timeout in seconds for Sidekiq tasks (Fargate max is 120)"
  type        = number
  default     = 120
}

variable "sidekiq_shutdown_timeout_seconds" {
  description = "Sidekiq shutdown timeout in seconds passed via -t"
  type        = number
  default     = 90
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

variable "sidekiq_ocr_text_task_cpu" {
  description = "CPU units for OCR text extraction Sidekiq ECS tasks"
  type        = number
  default     = 1024
}

variable "sidekiq_ocr_text_task_memory" {
  description = "Memory (MiB) for OCR text extraction Sidekiq ECS tasks"
  type        = number
  default     = 2048
}

variable "sidekiq_derivatives_task_cpu" {
  description = "CPU units for derivatives-only Sidekiq ECS tasks"
  type        = number
  default     = 2048
}

variable "sidekiq_derivatives_task_memory" {
  description = "Memory (MiB) for derivatives-only Sidekiq ECS tasks"
  type        = number
  default     = 4096
}

variable "sidekiq_thumbnail_task_cpu" {
  description = "CPU units for thumbnail-only Sidekiq ECS tasks"
  type        = number
  default     = 1024
}

variable "sidekiq_thumbnail_task_memory" {
  description = "Memory (MiB) for thumbnail-only Sidekiq ECS tasks"
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

variable "sidekiq_ocr_text_desired_count" {
  description = "Desired task count for OCR text extraction Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_ocr_text_min_capacity" {
  description = "Minimum autoscaling capacity for OCR text extraction Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_ocr_text_max_capacity" {
  description = "Maximum autoscaling capacity for OCR text extraction Sidekiq service"
  type        = number
  default     = 4
}

variable "sidekiq_derivatives_desired_count" {
  description = "Desired task count for derivatives Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_derivatives_min_capacity" {
  description = "Minimum autoscaling capacity for derivatives Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_derivatives_max_capacity" {
  description = "Maximum autoscaling capacity for derivatives Sidekiq service"
  type        = number
  default     = 4
}

variable "sidekiq_thumbnail_desired_count" {
  description = "Desired task count for thumbnail Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_thumbnail_min_capacity" {
  description = "Minimum autoscaling capacity for thumbnail Sidekiq service"
  type        = number
  default     = 0
}

variable "sidekiq_thumbnail_max_capacity" {
  description = "Maximum autoscaling capacity for thumbnail Sidekiq service"
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
  description = "CloudWatch log filter pattern that indicates Sidekiq queue latency pressure and should trigger scale-out"
  type        = string
  default     = "\"queue_latency_high\""
}

variable "sidekiq_log_autoscaling_depth_pattern" {
  description = "CloudWatch log filter pattern that indicates Sidekiq queue depth pressure and should trigger scale-out"
  type        = string
  default     = "\"queue_depth_high\""
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

variable "sidekiq_log_autoscaling_depth_threshold" {
  description = "Minimum number of queue-depth pressure log events per period that triggers Sidekiq scale-out"
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

variable "memcached_image" {
  description = "Container image URI used by ECS Memcached tasks"
  type        = string
  default     = "bitnami/memcached"
}

variable "memcached_task_cpu" {
  description = "CPU units for Memcached ECS tasks"
  type        = number
  default     = 256
}

variable "memcached_task_memory" {
  description = "Memory (MiB) for Memcached ECS tasks"
  type        = number
  default     = 512
}

variable "memcached_desired_count" {
  description = "Desired task count for Memcached ECS service"
  type        = number
  default     = 1
}

variable "memcached_min_capacity" {
  description = "Minimum autoscaling capacity for Memcached ECS service"
  type        = number
  default     = 1
}

variable "memcached_max_capacity" {
  description = "Maximum autoscaling capacity for Memcached ECS service"
  type        = number
  default     = 2
}

variable "memcached_target_cpu_utilization" {
  description = "Target average CPU utilization percent for Memcached autoscaling"
  type        = number
  default     = 70
}

variable "memcached_target_memory_utilization" {
  description = "Target average memory utilization percent for Memcached autoscaling"
  type        = number
  default     = 80
}

variable "memcached_assign_public_ip" {
  description = "Assign public IPs to Memcached tasks. Keep false when using private subnets with NAT."
  type        = bool
  default     = false
}

variable "memcached_log_retention_days" {
  description = "CloudWatch log retention in days for Memcached ECS service"
  type        = number
  default     = 30
}

variable "fedora_image" {
  description = "Container image URI used by ECS Fedora tasks"
  type        = string
  default     = "fcrepo/fcrepo:6.5.1-tomcat9"
}

variable "fedora_task_cpu" {
  description = "CPU units for Fedora ECS tasks"
  type        = number
  default     = 1024
}

variable "fedora_task_memory" {
  description = "Memory (MiB) for Fedora ECS tasks"
  type        = number
  default     = 8192
}

variable "fedora_ephemeral_storage_gib" {
  description = "Ephemeral storage (GiB) for Fedora ECS Fargate tasks"
  type        = number
  default     = 100
}

variable "fedora_jvm_xms_mb" {
  description = "Initial JVM heap size in MiB for Fedora"
  type        = number
  default     = 1024
}

variable "fedora_jvm_xmx_mb" {
  description = "Maximum JVM heap size in MiB for Fedora"
  type        = number
  default     = 6144

  validation {
    condition     = var.fedora_jvm_xmx_mb <= var.fedora_task_memory - 1536
    error_message = "fedora_jvm_xmx_mb must leave at least 1536MiB of non-heap memory inside the Fedora task."
  }
}

variable "fedora_db_connection_checkout_timeout_ms" {
  description = "Fedora database connection checkout timeout in milliseconds"
  type        = number
  default     = 120000
}

variable "fedora_session_timeout_ms" {
  description = "Fedora session timeout in milliseconds"
  type        = number
  default     = 1800000
}

variable "fedora_ocfl_s3_connection_timeout_seconds" {
  description = "Fedora OCFL S3 connection timeout in seconds"
  type        = number
  default     = 300
}

variable "fedora_ocfl_s3_read_timeout_seconds" {
  description = "Fedora OCFL S3 read timeout in seconds"
  type        = number
  default     = 300
}

variable "fedora_ocfl_s3_write_timeout_seconds" {
  description = "Fedora OCFL S3 write timeout in seconds"
  type        = number
  default     = 900
}

variable "fedora_desired_count" {
  description = "Desired task count for Fedora ECS service"
  type        = number
  default     = 1

  validation {
    condition     = var.fedora_desired_count <= 1
    error_message = "fedora_desired_count must be <= 1 (Fedora is pinned to a single instance)."
  }
}

variable "fedora_min_capacity" {
  description = "Minimum autoscaling capacity for Fedora ECS service"
  type        = number
  default     = 1

  validation {
    condition     = var.fedora_min_capacity <= 1
    error_message = "fedora_min_capacity must be <= 1 (Fedora is pinned to a single instance)."
  }
}

variable "fedora_max_capacity" {
  description = "Maximum autoscaling capacity for Fedora ECS service"
  type        = number
  default     = 1

  validation {
    condition     = var.fedora_max_capacity <= 1
    error_message = "fedora_max_capacity must be <= 1 (Fedora is pinned to a single instance)."
  }
}

variable "fedora_target_cpu_utilization" {
  description = "Target average CPU utilization percent for Fedora autoscaling"
  type        = number
  default     = 70
}

variable "fedora_target_memory_utilization" {
  description = "Target average memory utilization percent for Fedora autoscaling"
  type        = number
  default     = 80
}

variable "fedora_assign_public_ip" {
  description = "Assign public IPs to Fedora tasks. Keep false when using private subnets with NAT."
  type        = bool
  default     = false
}

variable "fedora_log_retention_days" {
  description = "CloudWatch log retention in days for Fedora ECS service"
  type        = number
  default     = 30
}

variable "solr_image" {
  description = "Container image URI used by ECS Solr tasks. Should be built from Dockerfile-solr so /opt/solr/server/configsets/hyraxconf exists."
  type        = string
  default     = "solr:8.11"
}

variable "solr_heap" {
  description = "Heap value passed to SOLR_HEAP for Solr JVM"
  type        = string
  default     = "1g"
}

variable "solr_task_cpu" {
  description = "CPU units for Solr ECS tasks"
  type        = number
  default     = 1024
}

variable "solr_task_memory" {
  description = "Memory (MiB) for Solr ECS tasks"
  type        = number
  default     = 2048
}

variable "solr_desired_count" {
  description = "Desired task count for Solr ECS service"
  type        = number
  default     = 1
}

variable "solr_min_capacity" {
  description = "Minimum autoscaling capacity for Solr ECS service"
  type        = number
  default     = 1
}

variable "solr_max_capacity" {
  description = "Maximum autoscaling capacity for Solr ECS service"
  type        = number
  default     = 1
}

variable "solr_target_cpu_utilization" {
  description = "Target average CPU utilization percent for Solr autoscaling"
  type        = number
  default     = 70
}

variable "solr_target_memory_utilization" {
  description = "Target average memory utilization percent for Solr autoscaling"
  type        = number
  default     = 80
}

variable "solr_assign_public_ip" {
  description = "Assign public IPs to Solr tasks. Keep false when using private subnets with NAT."
  type        = bool
  default     = false
}

variable "solr_log_retention_days" {
  description = "CloudWatch log retention in days for Solr ECS service"
  type        = number
  default     = 30
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.9"
}

variable "aurora_database_name" {
  description = "Name of the initial database created in Aurora"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]*$", var.aurora_database_name))
    error_message = "aurora_database_name must begin with a letter and contain only alphanumeric characters."
  }
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

variable "elasticache_node_type" {
  description = "ElastiCache node type for the managed Redis cluster"
  type        = string
  default     = "cache.t4g.micro"
}

variable "elasticache_num_cache_clusters" {
  description = "Number of cache nodes in the Redis replication group (set >1 for failover/read replica)"
  type        = number
  default     = 1
}

variable "elasticache_parameter_group_family" {
  description = "ElastiCache Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "elasticache_maxmemory_policy" {
  description = "Redis maxmemory-policy for Sidekiq safety; noeviction prevents silent queue data loss"
  type        = string
  default     = "noeviction"
}

variable "elasticache_alarm_period_seconds" {
  description = "CloudWatch period for ElastiCache alarms"
  type        = number
  default     = 60
}

variable "elasticache_alarm_evaluation_periods" {
  description = "CloudWatch evaluation periods for ElastiCache alarms"
  type        = number
  default     = 5
}

variable "elasticache_evictions_alarm_threshold" {
  description = "Alarm when Redis evictions over the period are >= this value"
  type        = number
  default     = 1
}

variable "elasticache_memory_usage_alarm_threshold" {
  description = "Alarm when Redis memory usage percentage exceeds this threshold"
  type        = number
  default     = 80
}

variable "elasticache_alarm_actions" {
  description = "SNS topic ARNs or other alarm actions for ElastiCache alarms"
  type        = list(string)
  default     = []
}

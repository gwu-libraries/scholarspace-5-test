terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  # terraform init -migrate-state -backend-config=backend.hcl
  # backend "s3" {}

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app" {
  name                 = var.site_prefix
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.site_prefix
  }
}

locals {
  ssm_env_content       = trimspace(file(var.ssm_env_file_path))
  ssm_env_parameter_arn = aws_ssm_parameter.app_env.arn
  ssm_env_lines = [
    for line in split("\n", replace(local.ssm_env_content, "\r", "")) :
    trimspace(line)
  ]
  ssm_env_assignments = [
    for line in local.ssm_env_lines : {
      key       = trimspace(split("=", line)[0])
      raw_value = join("=", slice(split("=", line), 1, length(split("=", line))))
    }
    if length(line) > 0 && !startswith(line, "#") && length(split("=", line)) > 1
  ]
  ssm_env_values = {
    for entry in local.ssm_env_assignments :
    entry.key => (
      startswith(entry.raw_value, "\"") && endswith(entry.raw_value, "\"")
      ? substr(entry.raw_value, 1, length(entry.raw_value) - 2)
      : entry.raw_value
    )
  }
  ssm_env_values_nonempty = {
    for key, value in local.ssm_env_values :
    key => value
    if length(trimspace(value)) > 0
  }

  ecs_managed_env = {
    RAILS_ENV        = "production"
    PUMA_ENV         = "production"
    DB_HOST          = aws_rds_cluster.aurora.endpoint
    DB_NAME          = var.aurora_database_name
    DB_PORT          = "5432"
    DB_USERNAME      = var.aurora_master_username
    REDIS_HOST       = aws_elasticache_replication_group.redis.primary_endpoint_address
    REDIS_PORT       = "6379"
    REDIS_PASSWORD   = ""
    REDIS_URL        = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0"
    MEMCACHED_HOST   = "${aws_service_discovery_service.memcached.name}.${aws_service_discovery_private_dns_namespace.internal.name}:11211"
    SOLR_PROD_URL    = "http://${aws_service_discovery_service.solr.name}.${aws_service_discovery_private_dns_namespace.internal.name}:8983/solr/scholarspace_prod"
    FEDORA_URL       = "http://${lookup(local.ssm_env_values, "FEDORA_USER", "fedoraAdmin")}:${lookup(local.ssm_env_values, "FEDORA_PASSWORD", "fedoraAdmin")}@${aws_service_discovery_service.fedora.name}.${aws_service_discovery_private_dns_namespace.internal.name}:8080/fcrepo/rest"
    FITS_SERVLET_URL = "http://${aws_service_discovery_service.fits.name}.${aws_service_discovery_private_dns_namespace.internal.name}:8080/fits"
  }

  ecs_common_container_environment = [
    for key, value in local.ecs_managed_env :
    { name = key, value = value }
  ]

  ecs_common_container_secrets = [
    for key, parameter in aws_ssm_parameter.app_env_var :
    { name = key, valueFrom = parameter.arn }
    if !contains(keys(local.ecs_managed_env), key)
  ]

  ecs_uploads_mount_point = {
    sourceVolume  = "uploads"
    containerPath = "/app/scholarspace/uploads"
    readOnly      = false
  }

  # ECS service log group configurations for consolidated CloudWatch setup
  ecs_log_groups = {
    web = {
      name              = "/ecs/${var.site_prefix}/web"
      retention_in_days = var.web_log_retention_days
    }
    fits = {
      name              = "/ecs/${var.site_prefix}/fits"
      retention_in_days = var.fits_log_retention_days
    }
  }
}

resource "aws_ssm_parameter" "app_env" {
  name      = var.ssm_env_parameter_name
  type      = "SecureString"
  tier      = "Advanced"
  value     = local.ssm_env_content
  overwrite = true

  lifecycle {
    precondition {
      condition     = length(local.ssm_env_content) > 0
      error_message = "ssm_env_file_path must point to a non-empty env file."
    }
  }
}

resource "aws_ssm_parameter" "app_env_var" {
  for_each = local.ssm_env_values_nonempty

  name      = "${trimsuffix(var.ssm_env_parameter_name, "/")}/${each.key}"
  type      = "SecureString"
  value     = each.key == "DB_PASSWORD" ? var.aurora_master_password : each.value
  overwrite = true
}

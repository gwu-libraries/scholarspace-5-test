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

locals {
  ssm_env_content       = trimspace(file(var.ssm_env_file_path))
  ssm_env_parameter_arn = aws_ssm_parameter.app_env.arn

  ecs_common_container_environment = [
    { name = "RAILS_ENV", value = "production" },
    { name = "PUMA_ENV", value = "production" },
    { name = "APP_HOST_PRIVATE_IP", value = aws_instance.web_server.private_ip },
    { name = "AURORA_ENDPOINT", value = aws_rds_cluster.aurora.endpoint },
    { name = "FITS_INTERNAL_HOST", value = "${aws_service_discovery_service.fits.name}.${aws_service_discovery_private_dns_namespace.internal.name}" }
  ]

  ecs_common_container_secrets = [
    { name = "APP_ENV_CONTENT", valueFrom = local.ssm_env_parameter_arn }
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
  value     = local.ssm_env_content
  overwrite = true

  lifecycle {
    precondition {
      condition     = length(local.ssm_env_content) > 0
      error_message = "ssm_env_file_path must point to a non-empty env file."
    }
  }
}

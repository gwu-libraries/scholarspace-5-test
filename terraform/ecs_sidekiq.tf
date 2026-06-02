locals {
  sidekiq_image_uri = length(trimspace(var.sidekiq_image)) > 0 ? var.sidekiq_image : "${aws_ecr_repository.sidekiq.repository_url}:latest"

  sidekiq_service_configs = {
    default = {
      sidekiq_only_audio_transcript    = "false"
      sidekiq_only_pdf_text_extraction = "false"
      sidekiq_workers                  = "4"
      desired_count                    = var.sidekiq_default_desired_count
      min_capacity                     = var.sidekiq_default_min_capacity
      max_capacity                     = var.sidekiq_default_max_capacity
      cpu                              = var.sidekiq_task_cpu
      memory                           = var.sidekiq_task_memory
    }
    whisper = {
      sidekiq_only_audio_transcript    = "true"
      sidekiq_only_pdf_text_extraction = "false"
      sidekiq_workers                  = "1"
      desired_count                    = var.sidekiq_whisper_desired_count
      min_capacity                     = var.sidekiq_whisper_min_capacity
      max_capacity                     = var.sidekiq_whisper_max_capacity
      cpu                              = var.sidekiq_whisper_task_cpu
      memory                           = var.sidekiq_whisper_task_memory
    }
    pdf_text = {
      sidekiq_only_audio_transcript    = "false"
      sidekiq_only_pdf_text_extraction = "true"
      sidekiq_workers                  = "1"
      desired_count                    = var.sidekiq_pdf_text_desired_count
      min_capacity                     = var.sidekiq_pdf_text_min_capacity
      max_capacity                     = var.sidekiq_pdf_text_max_capacity
      cpu                              = var.sidekiq_pdf_text_task_cpu
      memory                           = var.sidekiq_pdf_text_task_memory
    }
  }

  sidekiq_log_autoscaling_configs = var.sidekiq_enable_log_based_autoscaling ? local.sidekiq_service_configs : {}
}

resource "aws_ecr_repository" "sidekiq" {
  name                 = "${var.site_prefix}-sidekiq"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.site_prefix}-sidekiq"
  }
}

resource "aws_cloudwatch_log_group" "sidekiq" {
  for_each = local.sidekiq_service_configs

  name              = "/ecs/${var.site_prefix}/sidekiq/${each.key}"
  retention_in_days = var.sidekiq_log_retention_days

  tags = {
    Name = "${var.site_prefix}-sidekiq-${each.key}"
  }
}

resource "aws_ecs_cluster" "sidekiq" {
  name = "${var.site_prefix}-sidekiq"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.site_prefix}-sidekiq"
  }
}

resource "aws_ecs_task_definition" "sidekiq" {
  for_each = local.sidekiq_service_configs

  family                   = "${var.site_prefix}-sidekiq-${each.key}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.sidekiq_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "sidekiq-${each.key}"
      image     = local.sidekiq_image_uri
      essential = true
      command = [
        "/app/scholarspace/bin/ecs-env",
        "sh",
        "-lc",
        "export SIDEKIQ_ONLY_AUDIO_TRANSCRIPT=\"${each.value.sidekiq_only_audio_transcript}\" SIDEKIQ_ONLY_PDF_TEXT_EXTRACTION=\"${each.value.sidekiq_only_pdf_text_extraction}\" SIDEKIQ_WORKERS=\"${each.value.sidekiq_workers}\" && exec bundle exec sidekiq"
      ]
      environment = local.ecs_common_container_environment
      secrets     = local.ecs_common_container_secrets
      mountPoints = [
        local.ecs_uploads_mount_point,
        {
          sourceVolume  = "ocr-cache"
          containerPath = "/app/scholarspace/tmp/cache/solr-ocr-index-cache"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.sidekiq[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.key
        }
      }
    }
  ])

  volume {
    name = "uploads"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.uploads.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.uploads.id
        iam             = "DISABLED"
      }
    }
  }

  volume {
    name = "ocr-cache"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.uploads.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.ocr_cache.id
        iam             = "DISABLED"
      }
    }
  }
}

resource "aws_ecs_service" "sidekiq" {
  for_each = local.sidekiq_service_configs

  name                   = "${var.site_prefix}-sidekiq-${each.key}"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.sidekiq[each.key].arn
  desired_count          = each.value.desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.app_private_subnet.id, aws_subnet.app_private_subnet_secondary.id]
    security_groups  = [aws_security_group.sidekiq_tasks.id]
    assign_public_ip = var.sidekiq_assign_public_ip
  }

  depends_on = [
    aws_security_group_rule.aurora_from_sidekiq_tasks,
    aws_rds_cluster_instance.aurora,
    aws_ecs_service.fits,
  ]
}

resource "aws_appautoscaling_target" "sidekiq" {
  for_each = local.sidekiq_service_configs

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${aws_ecs_cluster.sidekiq.name}/${aws_ecs_service.sidekiq[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "sidekiq_cpu" {
  for_each = local.sidekiq_service_configs

  name               = "${var.site_prefix}-sidekiq-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sidekiq[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.sidekiq[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.sidekiq[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.sidekiq_target_cpu_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_appautoscaling_policy" "sidekiq_memory" {
  for_each = local.sidekiq_service_configs

  name               = "${var.site_prefix}-sidekiq-${each.key}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sidekiq[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.sidekiq[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.sidekiq[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.sidekiq_target_memory_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_cloudwatch_log_metric_filter" "sidekiq_queue_pressure" {
  for_each = local.sidekiq_log_autoscaling_configs

  name           = "${var.site_prefix}-sidekiq-${each.key}-queue-pressure"
  log_group_name = aws_cloudwatch_log_group.sidekiq[each.key].name
  pattern        = var.sidekiq_log_autoscaling_pattern

  metric_transformation {
    name          = "${var.site_prefix}-sidekiq-${each.key}-queue-pressure"
    namespace     = "${var.site_prefix}/Sidekiq"
    value         = "1"
    default_value = 0
  }
}

resource "aws_appautoscaling_policy" "sidekiq_log_scale_out" {
  for_each = local.sidekiq_log_autoscaling_configs

  name               = "${var.site_prefix}-sidekiq-${each.key}-log-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.sidekiq[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.sidekiq[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.sidekiq[each.key].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = var.sidekiq_log_scale_out_cooldown_seconds
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = var.sidekiq_log_scale_out_adjustment
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "sidekiq_log_scale_out" {
  for_each = local.sidekiq_log_autoscaling_configs

  alarm_name          = "${var.site_prefix}-sidekiq-${each.key}-log-scale-out"
  alarm_description   = "Scale out Sidekiq ${each.key} service when log queue pressure events increase"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.sidekiq_log_autoscaling_evaluation_periods
  threshold           = var.sidekiq_log_autoscaling_threshold
  metric_name         = aws_cloudwatch_log_metric_filter.sidekiq_queue_pressure[each.key].metric_transformation[0].name
  namespace           = "${var.site_prefix}/Sidekiq"
  period              = var.sidekiq_log_autoscaling_period_seconds
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_appautoscaling_policy.sidekiq_log_scale_out[each.key].arn]
  ok_actions          = []
}

locals {
  sidekiq_service_configs = {
    ingest = {
      desired_count         = var.sidekiq_ingest_desired_count
      min_capacity          = var.sidekiq_ingest_min_capacity
      max_capacity          = var.sidekiq_ingest_max_capacity
      cpu                   = var.sidekiq_ingest_task_cpu
      memory                = var.sidekiq_ingest_task_memory
      ephemeral_storage_gib = var.sidekiq_ingest_ephemeral_storage_gib
    }
    default = {
      desired_count         = var.sidekiq_default_desired_count
      min_capacity          = var.sidekiq_default_min_capacity
      max_capacity          = var.sidekiq_default_max_capacity
      cpu                   = var.sidekiq_task_cpu
      memory                = var.sidekiq_task_memory
      ephemeral_storage_gib = var.sidekiq_ephemeral_storage_gib
    }
    whisper = {
      desired_count         = var.sidekiq_whisper_desired_count
      min_capacity          = var.sidekiq_whisper_min_capacity
      max_capacity          = var.sidekiq_whisper_max_capacity
      cpu                   = var.sidekiq_whisper_task_cpu
      memory                = var.sidekiq_whisper_task_memory
      ephemeral_storage_gib = var.sidekiq_whisper_ephemeral_storage_gib
    }
    ocr_text = {
      desired_count         = var.sidekiq_ocr_text_desired_count
      min_capacity          = var.sidekiq_ocr_text_min_capacity
      max_capacity          = var.sidekiq_ocr_text_max_capacity
      cpu                   = var.sidekiq_ocr_text_task_cpu
      memory                = var.sidekiq_ocr_text_task_memory
      ephemeral_storage_gib = var.sidekiq_ocr_text_ephemeral_storage_gib
    }
    images = {
      desired_count         = var.sidekiq_images_desired_count
      min_capacity          = var.sidekiq_images_min_capacity
      max_capacity          = var.sidekiq_images_max_capacity
      cpu                   = var.sidekiq_images_task_cpu
      memory                = var.sidekiq_images_task_memory
      ephemeral_storage_gib = var.sidekiq_images_ephemeral_storage_gib
    }
    thumbnail = {
      desired_count         = var.sidekiq_thumbnail_desired_count
      min_capacity          = var.sidekiq_thumbnail_min_capacity
      max_capacity          = var.sidekiq_thumbnail_max_capacity
      cpu                   = var.sidekiq_thumbnail_task_cpu
      memory                = var.sidekiq_thumbnail_task_memory
      ephemeral_storage_gib = var.sidekiq_thumbnail_ephemeral_storage_gib
    }
    persist = {
      desired_count         = var.sidekiq_persist_desired_count
      min_capacity          = var.sidekiq_persist_min_capacity
      max_capacity          = var.sidekiq_persist_max_capacity
      cpu                   = var.sidekiq_persist_task_cpu
      memory                = var.sidekiq_persist_task_memory
      ephemeral_storage_gib = var.sidekiq_persist_ephemeral_storage_gib
    }
  }

  sidekiq_log_autoscaling_configs = var.sidekiq_enable_log_based_autoscaling ? local.sidekiq_service_configs : {}
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
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  dynamic "ephemeral_storage" {
    for_each = each.value.ephemeral_storage_gib == null ? [] : [each.value.ephemeral_storage_gib]

    content {
      size_in_gib = ephemeral_storage.value
    }
  }

  container_definitions = jsonencode([
    {
      name        = "sidekiq-${each.key}"
      image       = trimspace(var.sidekiq_image)
      essential   = true
      stopTimeout = var.sidekiq_container_stop_timeout_seconds
      command = [
        "bundle", "exec", "sidekiq",
        "-C", each.key == "default" ? "config/sidekiq.yml" : "config/sidekiq/${each.key}.yml",
        "-t", tostring(var.sidekiq_shutdown_timeout_seconds)
      ]
      environment = concat(local.ecs_common_container_environment, [
        { name = "SIDEKIQ_WORKER_POOL", value = each.key }
      ])
      secrets = local.ecs_common_container_secrets
      mountPoints = [
        local.ecs_uploads_mount_point
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
    aws_ecs_service.memcached,
    aws_ecs_service.fits,
    aws_ecs_service.fedora,
    aws_ecs_service.solr,
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
    scale_in_cooldown  = var.sidekiq_scale_in_cooldown_seconds
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
    scale_in_cooldown  = var.sidekiq_scale_in_cooldown_seconds
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

resource "aws_cloudwatch_log_metric_filter" "sidekiq_queue_depth_pressure" {
  for_each = local.sidekiq_log_autoscaling_configs

  name           = "${var.site_prefix}-sidekiq-${each.key}-queue-depth-pressure"
  log_group_name = aws_cloudwatch_log_group.sidekiq[each.key].name
  pattern        = var.sidekiq_log_autoscaling_depth_pattern

  metric_transformation {
    name          = "${var.site_prefix}-sidekiq-${each.key}-queue-depth-pressure"
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

resource "aws_cloudwatch_metric_alarm" "sidekiq_log_depth_scale_out" {
  for_each = local.sidekiq_log_autoscaling_configs

  alarm_name          = "${var.site_prefix}-sidekiq-${each.key}-log-depth-scale-out"
  alarm_description   = "Scale out Sidekiq ${each.key} service when log queue depth pressure events increase"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.sidekiq_log_autoscaling_evaluation_periods
  threshold           = var.sidekiq_log_autoscaling_depth_threshold
  metric_name         = aws_cloudwatch_log_metric_filter.sidekiq_queue_depth_pressure[each.key].metric_transformation[0].name
  namespace           = "${var.site_prefix}/Sidekiq"
  period              = var.sidekiq_log_autoscaling_period_seconds
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_appautoscaling_policy.sidekiq_log_scale_out[each.key].arn]
  ok_actions          = []
}

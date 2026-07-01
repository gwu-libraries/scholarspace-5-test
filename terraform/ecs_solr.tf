locals {
  solr_image_uri = length(trimspace(var.solr_image)) > 0 ? var.solr_image : "solr:9.6"
}

resource "aws_cloudwatch_log_group" "solr" {
  name              = "/ecs/${var.site_prefix}/solr"
  retention_in_days = var.solr_log_retention_days

  tags = {
    Name = "${var.site_prefix}-solr"
  }
}

resource "aws_service_discovery_service" "solr" {
  name = "solr"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_security_group" "solr_tasks" {
  name        = "${var.site_prefix}-solr-tasks"
  description = "Ingress from web/sidekiq ECS tasks to Solr"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "Allow Rails web ECS tasks to reach Solr"
    from_port       = 8983
    to_port         = 8983
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tasks.id]
  }

  ingress {
    description     = "Allow Sidekiq ECS tasks to reach Solr"
    from_port       = 8983
    to_port         = 8983
    protocol        = "tcp"
    security_groups = [aws_security_group.sidekiq_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-solr-tasks"
  }
}

resource "aws_ecs_task_definition" "solr" {
  family                   = "${var.site_prefix}-solr"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.solr_task_cpu)
  memory                   = tostring(var.solr_task_memory)
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.sidekiq_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "solr"
      image     = local.solr_image_uri
      essential = true
      command = [
        "sh",
        "-lc",
        "test -d /opt/solr/server/configsets/hyraxconf || { echo 'Missing hyraxconf configset. Build and set solr_image from Dockerfile-solr.'; exit 1; } && mkdir -p /var/solr/data && precreate-core scholarspace_test /opt/solr/server/configsets/hyraxconf && exec solr-precreate scholarspace_prod /opt/solr/server/configsets/hyraxconf"
      ]
      environment = [
        { name = "SOLR_HEAP", value = var.solr_heap }
      ]
      portMappings = [
        {
          containerPort = 8983
          hostPort      = 8983
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "solr-data"
          containerPath = "/var/solr"
          readOnly      = false
        },
        {
          sourceVolume  = "ocr-cache"
          containerPath = "/app/scholarspace/tmp/cache/solr-ocr-index-cache"
          readOnly      = true
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://localhost:8983/solr/admin/info/system || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 90
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.solr.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "solr"
        }
      }
    }
  ])

  volume {
    name = "solr-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.uploads.id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = aws_efs_access_point.solr_data.id
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

resource "aws_ecs_service" "solr" {
  name                   = "${var.site_prefix}-solr"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.solr.arn
  desired_count          = var.solr_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  # Solr is configured as a single-node core on shared storage. Avoid overlapping
  # old/new tasks during deployments to prevent concurrent writers.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.app_private_subnet.id, aws_subnet.app_private_subnet_secondary.id]
    security_groups  = [aws_security_group.solr_tasks.id]
    assign_public_ip = var.solr_assign_public_ip
  }

  service_registries {
    registry_arn = aws_service_discovery_service.solr.arn
  }

  lifecycle {
    precondition {
      condition = (
        var.solr_desired_count <= 1 &&
        var.solr_min_capacity <= 1 &&
        var.solr_max_capacity <= 1
      )
      error_message = "Standalone Solr on shared EFS must run as a single instance."
    }
  }
}

resource "aws_appautoscaling_target" "solr" {
  max_capacity       = var.solr_max_capacity
  min_capacity       = var.solr_min_capacity
  resource_id        = "service/${aws_ecs_cluster.sidekiq.name}/${aws_ecs_service.solr.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "solr_cpu" {
  name               = "${var.site_prefix}-solr-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.solr.resource_id
  scalable_dimension = aws_appautoscaling_target.solr.scalable_dimension
  service_namespace  = aws_appautoscaling_target.solr.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.solr_target_cpu_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_appautoscaling_policy" "solr_memory" {
  name               = "${var.site_prefix}-solr-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.solr.resource_id
  scalable_dimension = aws_appautoscaling_target.solr.scalable_dimension
  service_namespace  = aws_appautoscaling_target.solr.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.solr_target_memory_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

locals {
  fits_image_uri = length(trimspace(var.fits_image)) > 0 ? var.fits_image : "${aws_ecr_repository.app.repository_url}:latest-fits"
}

resource "aws_cloudwatch_log_group" "fits" {
  name              = local.ecs_log_groups.fits.name
  retention_in_days = local.ecs_log_groups.fits.retention_in_days

  tags = {
    Name = "${var.site_prefix}-fits"
  }
}

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "${var.site_prefix}.${var.fits_service_discovery_namespace}"
  vpc  = aws_vpc.app_vpc.id

  tags = {
    Name = "${var.site_prefix}-internal"
  }
}

resource "aws_service_discovery_service" "fits" {
  name = "fits"

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

resource "aws_security_group" "fits_tasks" {
  name        = "${var.site_prefix}-fits-tasks"
  description = "Ingress from web/sidekiq ECS tasks to FITS"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "Allow Rails web ECS tasks to reach FITS"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tasks.id]
  }

  ingress {
    description     = "Allow Sidekiq ECS tasks to reach FITS"
    from_port       = 8080
    to_port         = 8080
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
    Name = "${var.site_prefix}-fits-tasks"
  }
}

resource "aws_ecs_task_definition" "fits" {
  family                   = "${var.site_prefix}-fits"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.fits_task_cpu)
  memory                   = tostring(var.fits_task_memory)
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "fits"
      image     = local.fits_image_uri
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.fits.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "fits"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "fits" {
  name                   = "${var.site_prefix}-fits"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.fits.arn
  desired_count          = var.fits_desired_count
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
    security_groups  = [aws_security_group.fits_tasks.id]
    assign_public_ip = var.fits_assign_public_ip
  }

  service_registries {
    registry_arn = aws_service_discovery_service.fits.arn
  }
}

resource "aws_appautoscaling_target" "fits" {
  max_capacity       = var.fits_max_capacity
  min_capacity       = var.fits_min_capacity
  resource_id        = "service/${aws_ecs_cluster.sidekiq.name}/${aws_ecs_service.fits.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "fits_cpu" {
  name               = "${var.site_prefix}-fits-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.fits.resource_id
  scalable_dimension = aws_appautoscaling_target.fits.scalable_dimension
  service_namespace  = aws_appautoscaling_target.fits.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.fits_target_cpu_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_appautoscaling_policy" "fits_memory" {
  name               = "${var.site_prefix}-fits-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.fits.resource_id
  scalable_dimension = aws_appautoscaling_target.fits.scalable_dimension
  service_namespace  = aws_appautoscaling_target.fits.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.fits_target_memory_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

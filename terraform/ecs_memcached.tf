locals {
  memcached_image_uri = length(trimspace(var.memcached_image)) > 0 ? var.memcached_image : "bitnami/memcached"
}

resource "aws_cloudwatch_log_group" "memcached" {
  name              = "/ecs/${var.site_prefix}/memcached"
  retention_in_days = var.memcached_log_retention_days

  tags = {
    Name = "${var.site_prefix}-memcached"
  }
}

resource "aws_service_discovery_service" "memcached" {
  name = "memcached"

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

resource "aws_security_group" "memcached_tasks" {
  name        = "${var.site_prefix}-memcached-tasks"
  description = "Ingress from web/sidekiq ECS tasks to Memcached"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "Allow Rails web ECS tasks to reach Memcached"
    from_port       = 11211
    to_port         = 11211
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tasks.id]
  }

  ingress {
    description     = "Allow Sidekiq ECS tasks to reach Memcached"
    from_port       = 11211
    to_port         = 11211
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
    Name = "${var.site_prefix}-memcached-tasks"
  }
}

resource "aws_ecs_task_definition" "memcached" {
  family                   = "${var.site_prefix}-memcached"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.memcached_task_cpu)
  memory                   = tostring(var.memcached_task_memory)
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.sidekiq_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "memcached"
      image     = local.memcached_image_uri
      essential = true
      portMappings = [
        {
          containerPort = 11211
          hostPort      = 11211
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.memcached.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "memcached"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "memcached" {
  name                   = "${var.site_prefix}-memcached"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.memcached.arn
  desired_count          = var.memcached_desired_count
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
    security_groups  = [aws_security_group.memcached_tasks.id]
    assign_public_ip = var.memcached_assign_public_ip
  }

  service_registries {
    registry_arn = aws_service_discovery_service.memcached.arn
  }
}

resource "aws_appautoscaling_target" "memcached" {
  max_capacity       = var.memcached_max_capacity
  min_capacity       = var.memcached_min_capacity
  resource_id        = "service/${aws_ecs_cluster.sidekiq.name}/${aws_ecs_service.memcached.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "memcached_cpu" {
  name               = "${var.site_prefix}-memcached-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.memcached.resource_id
  scalable_dimension = aws_appautoscaling_target.memcached.scalable_dimension
  service_namespace  = aws_appautoscaling_target.memcached.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.memcached_target_cpu_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_appautoscaling_policy" "memcached_memory" {
  name               = "${var.site_prefix}-memcached-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.memcached.resource_id
  scalable_dimension = aws_appautoscaling_target.memcached.scalable_dimension
  service_namespace  = aws_appautoscaling_target.memcached.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memcached_target_memory_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

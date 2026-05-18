locals {
  web_image_uri = length(trimspace(var.web_image)) > 0 ? var.web_image : "${aws_ecr_repository.web.repository_url}:latest"
}

resource "aws_ecr_repository" "web" {
  name                 = "${var.site_prefix}-web"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.site_prefix}-web"
  }
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${var.site_prefix}/web"
  retention_in_days = var.web_log_retention_days

  tags = {
    Name = "${var.site_prefix}-web"
  }
}

resource "aws_security_group" "web_tasks" {
  name        = "${var.site_prefix}-web-tasks"
  description = "Ingress from ALB and egress for Rails web ECS tasks"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "Allow ALB to reach Rails web tasks"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-web-tasks"
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "${var.site_prefix}-web"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.web_task_cpu)
  memory                   = tostring(var.web_task_memory)
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.sidekiq_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "web"
      image     = local.web_image_uri
      essential = true
      command = [
        "sh",
        "-lc",
        "${local.ecs_env_bootstrap_command} && ${local.ecs_common_runtime_exports} && bundle exec rails db:prepare && exec ./bin/rails server -p 3000 -b 0.0.0.0"
      ]
      environment = local.ecs_common_container_environment
      secrets     = local.ecs_common_container_secrets
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      mountPoints = [local.ecs_uploads_mount_point]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.web.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "web"
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

resource "aws_ecs_service" "web" {
  name                   = "${var.site_prefix}-web"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.web.arn
  desired_count          = var.web_desired_count
  launch_type            = "FARGATE"
  enable_execute_command = true

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 120

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.app_private_subnet.id, aws_subnet.app_private_subnet_secondary.id]
    security_groups  = [aws_security_group.web_tasks.id]
    assign_public_ip = var.web_assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.scholarspace.arn
    container_name   = "web"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.scholarspace_http,
    aws_security_group_rule.web_server_redis_from_web,
    aws_security_group_rule.web_server_fedora_from_web,
    aws_security_group_rule.web_server_solr_from_web,
    aws_security_group_rule.web_server_memcached_from_web,
    aws_security_group_rule.aurora_from_web_tasks,
    aws_rds_cluster_instance.aurora,
    aws_ecs_service.fits,
  ]
}

resource "aws_appautoscaling_target" "web" {
  max_capacity       = var.web_max_capacity
  min_capacity       = var.web_min_capacity
  resource_id        = "service/${aws_ecs_cluster.sidekiq.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "web_cpu" {
  name               = "${var.site_prefix}-web-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.web_target_cpu_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_appautoscaling_policy" "web_memory" {
  name               = "${var.site_prefix}-web-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.web_target_memory_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

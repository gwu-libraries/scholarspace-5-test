locals {
  fedora_image_uri = length(trimspace(var.fedora_image)) > 0 ? var.fedora_image : "fcrepo/fcrepo:6.5.1-tomcat9"
}

resource "aws_cloudwatch_log_group" "fedora" {
  name              = "/ecs/${var.site_prefix}/fedora"
  retention_in_days = var.fedora_log_retention_days

  tags = {
    Name = "${var.site_prefix}-fedora"
  }
}

resource "aws_service_discovery_service" "fedora" {
  name = "fedora"

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

resource "aws_security_group" "fedora_tasks" {
  name        = "${var.site_prefix}-fedora-tasks"
  description = "Ingress from web/sidekiq ECS tasks to Fedora"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description     = "Allow Rails web ECS tasks to reach Fedora"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tasks.id]
  }

  ingress {
    description     = "Allow Sidekiq ECS tasks to reach Fedora"
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
    Name = "${var.site_prefix}-fedora-tasks"
  }
}

resource "aws_ecs_task_definition" "fedora" {
  family                   = "${var.site_prefix}-fedora"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.fedora_task_cpu)
  memory                   = tostring(var.fedora_task_memory)
  ephemeral_storage {
    size_in_gib = var.fedora_ephemeral_storage_gib
  }
  network_mode       = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "fedora"
      image     = local.fedora_image_uri
      essential = true
      environment = [
        {
          name  = "CATALINA_OPTS"
          value = "-Dfcrepo.home=/fcrepo-home -Djava.awt.headless=true -Dfile.encoding=UTF-8 -server -Xms${var.fedora_jvm_xms_mb}m -Xmx${var.fedora_jvm_xmx_mb}m -XX:NewSize=256m -XX:MaxNewSize=1G -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/data/mem -Dorg.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH=true -Dfcrepo.pid.minter.length=2 -Dfcrepo.pid.minter.count=4 -Dfcrepo.jms.enabled=false -Dfcrepo.metrics.enable=true -Dfcrepo.storage=ocfl-s3 -Dfcrepo.aws.region=${var.aws_region} -Dfcrepo.ocfl.s3.bucket=${aws_s3_bucket.app_bucket.bucket} -Dfcrepo.ocfl.s3.prefix=${var.s3_prefix} -Dfcrepo.db.connection.checkout.timeout=${var.fedora_db_connection_checkout_timeout_ms} -Dfcrepo.session.timeout=${var.fedora_session_timeout_ms} -Dfcrepo.ocfl.s3.connection.timeout=${var.fedora_ocfl_s3_connection_timeout_seconds} -Dfcrepo.ocfl.s3.read.timeout=${var.fedora_ocfl_s3_read_timeout_seconds} -Dfcrepo.ocfl.s3.write.timeout=${var.fedora_ocfl_s3_write_timeout_seconds}"
        },
        {
          name  = "JAVA_OPTS"
          value = "-Dorg.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH=true -Dfcrepo.pid.minter.length=2 -Dfcrepo.pid.minter.count=4"
        },
        {
          name  = "FEDORA_USER"
          value = lookup(local.ssm_env_values, "FEDORA_USER", "fedoraAdmin")
        },
        {
          name  = "FEDORA_PASSWORD"
          value = lookup(local.ssm_env_values, "FEDORA_PASSWORD", "fedoraAdmin")
        }
      ]
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget --spider --quiet --http-user=$FEDORA_USER --http-password=$FEDORA_PASSWORD http://localhost:8080/fcrepo/ || exit 1"]
        interval    = 60
        timeout     = 10
        retries     = 10
        startPeriod = 300
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.fedora.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "fedora"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "fedora" {
  name                   = "${var.site_prefix}-fedora"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.fedora.arn
  desired_count          = var.fedora_desired_count
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
    security_groups  = [aws_security_group.fedora_tasks.id]
    assign_public_ip = var.fedora_assign_public_ip
  }

  service_registries {
    registry_arn = aws_service_discovery_service.fedora.arn
  }
}

resource "aws_appautoscaling_target" "fedora" {
  max_capacity       = var.fedora_max_capacity
  min_capacity       = var.fedora_min_capacity
  resource_id        = "service/${aws_ecs_cluster.sidekiq.name}/${aws_ecs_service.fedora.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "fedora_cpu" {
  name               = "${var.site_prefix}-fedora-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.fedora.resource_id
  scalable_dimension = aws_appautoscaling_target.fedora.scalable_dimension
  service_namespace  = aws_appautoscaling_target.fedora.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.fedora_target_cpu_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

resource "aws_appautoscaling_policy" "fedora_memory" {
  name               = "${var.site_prefix}-fedora-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.fedora.resource_id
  scalable_dimension = aws_appautoscaling_target.fedora.scalable_dimension
  service_namespace  = aws_appautoscaling_target.fedora.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.fedora_target_memory_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 120
  }
}

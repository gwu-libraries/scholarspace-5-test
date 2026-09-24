locals {
  fedora_catalina_opts = join(" ", [
    "-server",
    "-Xms${var.fedora_jvm_xms_mb}m",
    "-Xmx${var.fedora_jvm_xmx_mb}m",
    "-XX:NewSize=256m",
    "-XX:MaxNewSize=1G",
    "-XX:+HeapDumpOnOutOfMemoryError",
    "-XX:HeapDumpPath=/data/mem",
    "-Djava.awt.headless=true",
    "-Dfile.encoding=UTF-8",
    "-Dorg.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH=true",
    "-Dfcrepo.home=/fcrepo-home",
    "-Dfcrepo.pid.minter.length=2",
    "-Dfcrepo.pid.minter.count=4",
    "-Dfcrepo.jms.enabled=false",
    "-Dfcrepo.metrics.enable=true",
    "-Dfcrepo.session.timeout=${var.fedora_session_timeout_ms}",
    "-Dfcrepo.storage=ocfl-s3",
    "-Dfcrepo.aws.region=${var.aws_region}",
    "-Dfcrepo.ocfl.s3.bucket=${aws_s3_bucket.app_bucket.bucket}",
    "-Dfcrepo.ocfl.s3.prefix=${var.ocfl_s3_prefix}",
    "-Dfcrepo.ocfl.s3.connection.timeout=${var.fedora_ocfl_s3_connection_timeout_seconds}",
    "-Dfcrepo.ocfl.s3.read.timeout=${var.fedora_ocfl_s3_read_timeout_seconds}",
    "-Dfcrepo.ocfl.s3.write.timeout=${var.fedora_ocfl_s3_write_timeout_seconds}",
    "-Dfcrepo.db.url=jdbc:postgresql://${aws_rds_cluster.aurora.endpoint}:5432/${var.fedora_database_name}",
    "-Dfcrepo.db.user=${var.aurora_master_username}",
    "-Dfcrepo.db.password=${local.ssm_env_values["DB_PASSWORD"]}",
    "-Dfcrepo.db.connection.checkout.timeout=${var.fedora_db_connection_checkout_timeout_ms}",
  ])

  # createdb exits non-zero if the database already exists, which would block the
  # Fedora container, so check first.
  fedora_db_init_command = <<-EOT
    psql -tAc "SELECT 1 FROM pg_database WHERE datname='${var.fedora_database_name}'" | grep -q 1 || createdb ${var.fedora_database_name}
  EOT
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
    # Aurora only creates one database at cluster creation, and that one belongs to
    # Rails. Fedora's is created here so it exists before Fedora opens a connection.
    {
      name      = "fedora-db-init"
      image     = "postgres:16-alpine"
      essential = false
      command = [
        "sh",
        "-c",
        local.fedora_db_init_command
      ]
      environment = [
        { name = "PGHOST", value = aws_rds_cluster.aurora.endpoint },
        { name = "PGPORT", value = "5432" },
        { name = "PGUSER", value = var.aurora_master_username },
        { name = "PGDATABASE", value = var.aurora_database_name }
      ]
      secrets = [
        { name = "PGPASSWORD", valueFrom = aws_ssm_parameter.app_env_var["DB_PASSWORD"].arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.fedora.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "fedora-db-init"
        }
      }
    },
    {
      name      = "fedora"
      image     = var.fedora_image
      essential = true

      dependsOn = [
        {
          containerName = "fedora-db-init"
          condition     = "SUCCESS"
        }
      ]

      environment = [
        {
          name  = "CATALINA_OPTS"
          value = local.fedora_catalina_opts
        },
        {
          name  = "JAVA_OPTS"
          value = "-Dorg.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH=true -Dfcrepo.pid.minter.length=2 -Dfcrepo.pid.minter.count=4"
        },
        {
          name  = "FEDORA_USER"
          value = local.ssm_env_values["FEDORA_USER"]
        },
        {
          name  = "FEDORA_PASSWORD"
          value = local.ssm_env_values["FEDORA_PASSWORD"]
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

  lifecycle {
    precondition {
      condition     = var.fedora_jvm_xmx_mb <= var.fedora_task_memory * 0.75
      error_message = "fedora_jvm_xmx_mb must leave at least 25% of fedora_task_memory for JVM overhead."
    }

    precondition {
      condition     = var.fedora_jvm_xms_mb <= var.fedora_jvm_xmx_mb
      error_message = "fedora_jvm_xms_mb must not exceed fedora_jvm_xmx_mb."
    }
  }
}

resource "aws_ecs_service" "fedora" {
  name                   = "${var.site_prefix}-fedora"
  cluster                = aws_ecs_cluster.sidekiq.id
  task_definition        = aws_ecs_task_definition.fedora.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

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

  depends_on = [
    aws_security_group_rule.aurora_from_fedora_tasks,
    aws_rds_cluster_instance.aurora,
  ]
}

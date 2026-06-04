# ── Aurora PostgreSQL ─────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "aurora" {
  name = "${var.site_prefix}-aurora"
  subnet_ids = [
    aws_subnet.app_subnet.id,
    aws_subnet.app_subnet_secondary.id,
    aws_subnet.app_private_subnet.id,
    aws_subnet.app_private_subnet_secondary.id,
  ]

  tags = {
    Name = "${var.site_prefix}-aurora"
  }
}

resource "aws_security_group" "aurora" {
  name        = "${var.site_prefix}-aurora"
  description = "Allow Postgres access from ECS tasks and EC2 host"
  vpc_id      = aws_vpc.app_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-aurora"
  }
}

resource "aws_security_group_rule" "aurora_from_web_tasks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora.id
  source_security_group_id = aws_security_group.web_tasks.id
  description              = "Allow Rails web ECS tasks to reach Aurora"
}

resource "aws_security_group_rule" "aurora_from_sidekiq_tasks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora.id
  source_security_group_id = aws_security_group.sidekiq_tasks.id
  description              = "Allow Sidekiq ECS tasks to reach Aurora"
}

resource "aws_security_group_rule" "aurora_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.aurora.id
  source_security_group_id = aws_security_group.allow_web_traffic.id
  description              = "Allow EC2 host to reach Aurora (admin, migrations)"
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${var.site_prefix}-aurora-pg16"
  family      = "aurora-postgresql16"
  description = "Aurora PostgreSQL 16 parameter group for ${var.site_prefix}"

  tags = {
    Name = "${var.site_prefix}-aurora-pg16"
  }
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = "${var.site_prefix}-aurora"
  engine                          = "aurora-postgresql"
  engine_version                  = var.aurora_engine_version
  database_name                   = var.aurora_database_name
  master_username                 = var.aurora_master_username
  master_password                 = var.aurora_master_password
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  skip_final_snapshot             = var.aurora_skip_final_snapshot
  final_snapshot_identifier       = var.aurora_skip_final_snapshot ? null : "${var.site_prefix}-aurora-final-snapshot"
  deletion_protection             = var.aurora_deletion_protection
  backup_retention_period         = var.aurora_backup_retention_days
  preferred_backup_window         = "03:00-04:00"
  preferred_maintenance_window    = "sun:04:00-sun:05:00"
  storage_encrypted               = true

  tags = {
    Name = "${var.site_prefix}-aurora"
  }

  lifecycle {
    precondition {
      condition     = length(var.aurora_master_password) > 0
      error_message = "Set aurora_master_password and keep it in sync with DB_PASSWORD in ssm_env_file_path."
    }
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  count = var.aurora_instance_count

  identifier         = "${var.site_prefix}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.aurora_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  tags = {
    Name = "${var.site_prefix}-aurora-${count.index}"
  }
}

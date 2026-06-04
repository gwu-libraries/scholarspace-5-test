resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.site_prefix}-redis"
  subnet_ids = [aws_subnet.app_private_subnet.id, aws_subnet.app_private_subnet_secondary.id]

  tags = {
    Name = "${var.site_prefix}-redis"
  }
}

resource "aws_security_group" "elasticache_redis" {
  name        = "${var.site_prefix}-elasticache-redis"
  description = "Allow Redis access from EC2 and ECS tasks"
  vpc_id      = aws_vpc.app_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-elasticache-redis"
  }
}

resource "aws_security_group_rule" "elasticache_from_ec2" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticache_redis.id
  source_security_group_id = aws_security_group.allow_web_traffic.id
  description              = "Redis from EC2 host"
}

resource "aws_security_group_rule" "elasticache_from_web_tasks" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticache_redis.id
  source_security_group_id = aws_security_group.web_tasks.id
  description              = "Redis from web ECS tasks"
}

resource "aws_security_group_rule" "elasticache_from_sidekiq_tasks" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticache_redis.id
  source_security_group_id = aws_security_group.sidekiq_tasks.id
  description              = "Redis from Sidekiq ECS tasks"
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.site_prefix}-redis"
  description          = "Redis for ${var.site_prefix}"

  node_type               = var.elasticache_node_type
  num_cache_clusters      = 1
  automatic_failover_enabled = false
  multi_az_enabled        = false

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.elasticache_redis.id]

  engine_version             = "7.1"
  parameter_group_name       = "default.redis7"
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  tags = {
    Name = "${var.site_prefix}-redis"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.site_prefix}-redis"
  subnet_ids = [aws_subnet.app_private_subnet.id, aws_subnet.app_private_subnet_secondary.id]

  tags = {
    Name = "${var.site_prefix}-redis"
  }
}

resource "aws_security_group" "elasticache_redis" {
  name        = "${var.site_prefix}-elasticache-redis"
  description = "Allow Redis access from ECS tasks"
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

resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.site_prefix}-redis7"
  family = var.elasticache_parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = var.elasticache_maxmemory_policy
  }

  tags = {
    Name = "${var.site_prefix}-redis-params"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.site_prefix}-redis"
  description          = "Redis for ${var.site_prefix}"

  node_type                  = var.elasticache_node_type
  num_cache_clusters         = var.elasticache_num_cache_clusters
  automatic_failover_enabled = var.elasticache_num_cache_clusters > 1
  multi_az_enabled           = var.elasticache_num_cache_clusters > 1

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.elasticache_redis.id]

  engine_version             = "7.1"
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  tags = {
    Name = "${var.site_prefix}-redis"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.site_prefix}-redis-evictions"
  alarm_description   = "Redis evictions detected for ${var.site_prefix}; Sidekiq reliability is at risk"
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  statistic           = "Sum"
  period              = var.elasticache_alarm_period_seconds
  evaluation_periods  = var.elasticache_alarm_evaluation_periods
  threshold           = var.elasticache_evictions_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = sort(tolist(aws_elasticache_replication_group.redis.member_clusters))[0]
  }

  alarm_actions = var.elasticache_alarm_actions
  ok_actions    = var.elasticache_alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  alarm_name          = "${var.site_prefix}-redis-memory-high"
  alarm_description   = "Redis memory usage is high for ${var.site_prefix}; consider scaling before evictions"
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  period              = var.elasticache_alarm_period_seconds
  evaluation_periods  = var.elasticache_alarm_evaluation_periods
  threshold           = var.elasticache_memory_usage_alarm_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId = sort(tolist(aws_elasticache_replication_group.redis.member_clusters))[0]
  }

  alarm_actions = var.elasticache_alarm_actions
  ok_actions    = var.elasticache_alarm_actions
}

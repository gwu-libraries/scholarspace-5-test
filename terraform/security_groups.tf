# Security group for the EC2 web server
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic_prod"
  description = "Allow web traffic for prod"
  vpc_id      = aws_vpc.app_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_traffic_prod"
  }
}

resource "aws_security_group_rule" "web_server_ssh_from_cidrs" {
  for_each = toset(var.ssh_allowed_cidrs)

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.allow_web_traffic.id
  cidr_blocks       = [each.value]
  description       = "SSH access from allowed CIDRs"
}

# Security group for the ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.site_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-alb-sg"
  }
}

# Security group for Sidekiq ECS tasks (egress only; ingress rules are on the web server SG)
resource "aws_security_group" "sidekiq_tasks" {
  name        = "${var.site_prefix}-sidekiq-tasks"
  description = "Egress for Sidekiq ECS tasks"
  vpc_id      = aws_vpc.app_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.site_prefix}-sidekiq-tasks"
  }
}

# Mapping of backing services accessible from both web and sidekiq ECS tasks
# Redis is excluded here — it is served by ElastiCache, not the EC2 host.
locals {
  ecs_backing_services = {
    fedora    = { port = 8080, description = "Fedora" }
    solr      = { port = 62821, description = "Solr" }
    memcached = { port = 11211, description = "Memcached" }
  }

  # Generate rules for both source task SGs
  ecs_task_sources = {
    web     = aws_security_group.web_tasks.id
    sidekiq = aws_security_group.sidekiq_tasks.id
  }
}

# Allow web and sidekiq ECS tasks to reach backing services running on the EC2 host
resource "aws_security_group_rule" "web_server_service_access" {
  for_each = merge([
    for source_name, source_sg_id in local.ecs_task_sources : {
      for service_name, service_config in local.ecs_backing_services :
      "${source_name}_${service_name}" => {
        source_name  = source_name
        service_name = service_name
        source_sg_id = source_sg_id
        port         = service_config.port
        service_desc = service_config.description
      }
    }
  ]...)

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = each.value.source_sg_id
  description              = "Allow ${each.value.source_name} ECS tasks to access ${each.value.service_desc}"
}

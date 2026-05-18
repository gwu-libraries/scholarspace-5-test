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

# Allow Sidekiq ECS tasks to reach the backing services running on the EC2 host
resource "aws_security_group_rule" "web_server_redis_from_sidekiq" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.sidekiq_tasks.id
  description              = "Allow Sidekiq ECS tasks to access Redis"
}

resource "aws_security_group_rule" "web_server_fedora_from_sidekiq" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.sidekiq_tasks.id
  description              = "Allow Sidekiq ECS tasks to access Fedora"
}

resource "aws_security_group_rule" "web_server_solr_from_sidekiq" {
  type                     = "ingress"
  from_port                = 62821
  to_port                  = 62821
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.sidekiq_tasks.id
  description              = "Allow Sidekiq ECS tasks to access Solr"
}

resource "aws_security_group_rule" "web_server_memcached_from_sidekiq" {
  type                     = "ingress"
  from_port                = 11211
  to_port                  = 11211
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.sidekiq_tasks.id
  description              = "Allow Sidekiq ECS tasks to access Memcached"
}

# Allow Rails web ECS tasks to reach the backing services running on the EC2 host
resource "aws_security_group_rule" "web_server_redis_from_web" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.web_tasks.id
  description              = "Allow Rails web ECS tasks to access Redis"
}

resource "aws_security_group_rule" "web_server_fedora_from_web" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.web_tasks.id
  description              = "Allow Rails web ECS tasks to access Fedora"
}

resource "aws_security_group_rule" "web_server_solr_from_web" {
  type                     = "ingress"
  from_port                = 62821
  to_port                  = 62821
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.web_tasks.id
  description              = "Allow Rails web ECS tasks to access Solr"
}

resource "aws_security_group_rule" "web_server_memcached_from_web" {
  type                     = "ingress"
  from_port                = 11211
  to_port                  = 11211
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_web_traffic.id
  source_security_group_id = aws_security_group.web_tasks.id
  description              = "Allow Rails web ECS tasks to access Memcached"
}

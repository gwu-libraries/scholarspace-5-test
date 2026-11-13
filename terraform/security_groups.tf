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


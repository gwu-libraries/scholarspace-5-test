resource "aws_lb_target_group" "scholarspace" {
  name        = "${var.site_prefix}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.app_vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/up"
    matcher             = "200,404"
  }

  tags = {
    Name = "${var.site_prefix}-target-group"
  }
}

resource "aws_lb" "scholarspace" {
  name               = "${var.site_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.app_subnet.id, aws_subnet.app_subnet_secondary.id]
  idle_timeout       = 900

  enable_deletion_protection = false

  tags = {
    Name = "${var.site_prefix}-alb"
  }
}

resource "aws_lb_listener" "scholarspace_http" {
  count             = length(trimspace(var.ssl_certificate_arn)) == 0 ? 1 : 0
  load_balancer_arn = aws_lb.scholarspace.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.scholarspace.arn
  }
}

resource "aws_lb_listener" "scholarspace_http_redirect" {
  count             = length(trimspace(var.ssl_certificate_arn)) > 0 ? 1 : 0
  load_balancer_arn = aws_lb.scholarspace.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "scholarspace_https" {
  count             = length(trimspace(var.ssl_certificate_arn)) > 0 ? 1 : 0
  load_balancer_arn = aws_lb.scholarspace.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.scholarspace.arn
  }
}

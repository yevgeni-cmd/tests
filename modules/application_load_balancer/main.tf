# modules/application_load_balancer/main.tf - FIXED
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Application Load Balancer
resource "aws_lb" "this" {
  name               = var.alb_name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = var.tags
}

# Target Group for ECS Services
resource "aws_lb_target_group" "ecs" {
  for_each = var.target_groups

  name        = each.value.name
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    matcher             = each.value.health_check.matcher
    port                = "traffic-port"
    protocol            = each.value.health_check.protocol
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  count             = var.enable_http_listener ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
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

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.enable_private_ca ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener" "http_internal" {
  count             = var.internal ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = var.enable_private_ca ? "redirect" : "fixed-response"

    dynamic "redirect" {
      for_each = var.enable_private_ca ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    dynamic "fixed_response" {
      for_each = !var.enable_private_ca ? [1] : []
      content {
        content_type = "text/plain"
        message_body = "Service is available on HTTPS only"
        status_code  = "403"
      }
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "http_external" {
  count             = var.internal ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
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

  tags = var.tags
}

# Listener Rules for Target Groups
resource "aws_lb_listener_rule" "ecs_rules" {
  for_each = var.target_groups

  listener_arn = var.enable_private_ca ? aws_lb_listener.https[0].arn : (var.internal ? aws_lb_listener.http_internal[0].arn : aws_lb_listener.http_external[0].arn)
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }

  dynamic "condition" {
    for_each = each.value.host_headers != null ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }
}
# CloudWatch Log Group for ALB Access Logs
resource "aws_cloudwatch_log_group" "alb_logs" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/alb/${var.alb_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
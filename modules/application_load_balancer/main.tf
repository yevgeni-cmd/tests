# modules/application_load_balancer/main.tf - FINAL FIX (NO COMPUTED VALUES)
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

# Target Groups for ECS Services
resource "aws_lb_target_group" "ecs" {
  for_each = var.target_groups

  name        = each.value.name
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = each.value.health_check.enabled
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

# HTTP Listener - ALWAYS CREATED
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  # Simple default action - will be overridden by rules
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

# HTTPS Listener - ONLY created if HTTPS is enabled (no certificate check)
resource "aws_lb_listener" "https" {
  count             = var.enable_https_listener ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Simple default action - will be overridden by rules
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

# HTTP Listener Rules - ALWAYS created for HTTP listener
resource "aws_lb_listener_rule" "http_rules" {
  for_each = var.target_groups

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority + 1000  # Offset to avoid conflicts with HTTPS rules

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

  tags = merge(var.tags, {
    Name = "${each.key}-http-rule"
  })
}

# HTTPS Listener Rules - Only created if HTTPS is enabled
resource "aws_lb_listener_rule" "https_rules" {
  for_each = var.enable_https_listener ? var.target_groups : {}

  listener_arn = aws_lb_listener.https[0].arn
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

  tags = merge(var.tags, {
    Name = "${each.key}-https-rule"
  })
}

# HTTP to HTTPS Redirect Rule - Only if HTTPS is enabled
resource "aws_lb_listener_rule" "http_redirect" {
  count = var.enable_https_listener ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 1  # Highest priority to catch all traffic

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["*"]  # Catch all paths
    }
  }

  tags = merge(var.tags, {
    Name = "http-to-https-redirect"
  })
}

# CloudWatch Log Group for ALB Access Logs
resource "aws_cloudwatch_log_group" "alb_logs" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/alb/${var.alb_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
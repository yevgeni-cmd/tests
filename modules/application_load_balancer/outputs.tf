output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Map of target group ARNs by name"
  value = {
    for k, v in aws_lb_target_group.ecs : k => v.arn
  }
}

output "target_group_arn_suffixes" {
  description = "Map of target group ARN suffixes by name"
  value = {
    for k, v in aws_lb_target_group.ecs : k => v.arn_suffix
  }
}

output "listener_arns" {
  description = "Map of listener ARNs"
  value = {
    http  = var.enable_http_listener ? aws_lb_listener.http[0].arn : null
    https = var.certificate_arn != null ? aws_lb_listener.https[0].arn : null
    http_internal = var.internal && var.certificate_arn == null ? aws_lb_listener.http_internal[0].arn : null
  }
}
# modules/application_load_balancer/outputs.tf - SIMPLIFIED (NO COMPUTED DEPENDENCIES)
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

output "http_listener_arn" {
  description = "ARN of the HTTP listener (always available)"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (only if HTTPS enabled)"
  value       = var.enable_https_listener ? aws_lb_listener.https[0].arn : null
}

output "listener_arns" {
  description = "Map of listener ARNs"
  value = {
    http  = aws_lb_listener.http.arn
    https = var.enable_https_listener ? aws_lb_listener.https[0].arn : null
  }
}
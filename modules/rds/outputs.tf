
output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_instance_name" {
  description = "RDS instance database name"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "RDS instance master username"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "master_user_secret_arn" {
  description = "ARN of the master user secret (if AWS managed)"
  value       = var.manage_master_user_password ? aws_db_instance.this.master_user_secret[0].secret_arn : (var.manage_master_user_password ? null : aws_secretsmanager_secret.db_password[0].arn)
}

output "db_subnet_group_id" {
  description = "ID of the DB subnet group"
  value       = aws_db_subnet_group.this.id
}

output "db_subnet_group_arn" {
  description = "ARN of the DB subnet group"
  value       = aws_db_subnet_group.this.arn
}

output "enhanced_monitoring_iam_role_arn" {
  description = "ARN of the enhanced monitoring IAM role"
  value       = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
}
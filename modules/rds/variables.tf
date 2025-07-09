# modules/rds/variables.tf
variable "db_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "Engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial storage allocation in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage allocation in GB"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Whether to encrypt storage"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "admin"
}

variable "manage_master_user_password" {
  description = "Whether to manage master password with AWS"
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_id" {
  description = "KMS key for master user secret"
  type        = string
  default     = null
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs"
  type        = list(string)
}

variable "create_parameter_group" {
  description = "Whether to create a custom parameter group"
  type        = bool
  default     = false
}

variable "parameter_group_name" {
  description = "Name of the parameter group"
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "mysql8.0"
}

variable "parameters" {
  description = "List of parameters for the parameter group"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "auto_minor_version_upgrade" {
  description = "Whether to enable auto minor version upgrade"
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Whether to enable Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 0
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = []
}

variable "secret_recovery_window_days" {
  description = "Recovery window for secrets in days"
  type        = number
  default     = 7
}

variable "enable_cloudwatch_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = false
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization threshold for alarms"
  type        = number
  default     = 80
}

variable "connection_count_threshold" {
  description = "Connection count threshold for alarms"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
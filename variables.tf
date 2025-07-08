################################################################################
# Core Configuration Variables
################################################################################

variable "aws_profile" {
  description = "The AWS CLI profile to use for authentication."
  type        = string
}

variable "project_name" {
  description = "A name for the project to prefix resources."
  type        = string
  default     = "final-arch"
}

variable "primary_region" {
  description = "The main AWS region where most resources will be deployed."
  type        = string
  default     = "il-central-1"
}

variable "remote_region" {
  description = "The secondary region for the remote IoT VPC."
  type        = string
  default     = "eu-west-1"
}

################################################################################
# Custom AMI Configuration
################################################################################

variable "custom_standard_ami_id" {
  description = "Custom AMI ID with Docker for standard instances (untrusted hosts, trusted non-GPU hosts)."
  type        = string
  default     = "ami-0ea2fce7f7afb4f4c"
}

variable "custom_gpu_ami_id" {
  description = "Custom AMI ID with Docker and GPU support for GPU instances (trusted streaming host - future use)."
  type        = string
  default     = null # Will be added when GPU AMI is ready
}

variable "use_custom_amis" {
  description = "Whether to use custom AMIs instead of default Ubuntu/Amazon Linux AMIs."
  type        = bool
  default     = true
}

################################################################################
# Transit Gateway Variables
################################################################################

variable "trusted_asn" {
  description = "Private ASN for the trusted Transit Gateway."
  type        = number
  default     = 64512
}

variable "untrusted_asn" {
  description = "Private ASN for the untrusted Transit Gateway."
  type        = number
  default     = 64513
}

variable "remote_asn" {
  description = "Private ASN for the remote IoT Transit Gateway."
  type        = number
  default     = 64514
}

################################################################################
# VPC CIDR Block Variables
################################################################################

variable "untrusted_il_summary_routes" {
  description = "A map of valid summary routes for the untrusted IL environment."
  type        = map(string)
  default = {
    main = "172.19.16.0/20"
  }
}

variable "trusted_vpc_cidrs" {
  description = "A map of CIDR blocks for all VPCs in the trusted environment."
  type        = map(string)
  default = {
    "jacob_api_gw"    = "172.16.10.0/24"
    "iot_management"  = "172.16.11.0/24"
    "streaming"       = "172.16.12.0/24"
    "streaming_scrub" = "172.16.13.0/24"
    "devops"          = "172.16.14.0/24"
  }
}

variable "untrusted_vpc_cidrs" {
  description = "A map of CIDR blocks for all VPCs in the untrusted environment."
  type        = map(string)
  default = {
    "streaming_ingress" = "172.19.21.0/24"
    "streaming_scrub"   = "172.19.22.0/24"
    "iot_management"    = "172.19.23.0/24"
    "devops"            = "172.19.24.0/24"
  }
}

variable "remote_vpc_cidrs" {
  description = "A map of CIDR blocks for VPCs in the remote region."
  type        = map(string)
  default = {
    "iot_core" = "172.18.30.0/24"
  }
}

################################################################################
# Client VPN Variables
################################################################################

variable "vpn_authentication_type" {
  description = "The authentication method for the VPN. Can be 'certificate' or 'saml'."
  type        = string
  default     = "certificate"
  validation {
    condition     = contains(["certificate", "saml"], var.vpn_authentication_type)
    error_message = "Valid values for authentication_type are 'certificate' or 'saml'."
  }
}

variable "trusted_vpn_server_cert_arn" {
  description = "The ARN of an existing ACM certificate for the trusted Client VPN server."
  type        = string
}

variable "untrusted_vpn_server_cert_arn" {
  description = "The ARN of an existing ACM certificate for the untrusted Client VPN server."
  type        = string
}

variable "saml_identity_provider_arn" {
  description = "The ARN of the SAML 2.0 Identity Provider for MFA. Required if authentication_type is 'saml'."
  type        = string
  default     = null
}

variable "trusted_vpn_client_cidr" {
  description = "The CIDR block for clients connecting to the trusted VPN."
  type        = string
  default     = "172.30.20.0/22"
}

variable "untrusted_vpn_client_cidr" {
  description = "The CIDR block for clients connecting to the untrusted VPN."
  type        = string
  default     = "172.31.16.0/22"
}

################################################################################
# EC2 Instance Variables
################################################################################

variable "trusted_ssh_key_name" {
  description = "The name of the EC2 Key Pair for instances in the TRUSTED environment."
  type        = string
}

variable "untrusted_ssh_key_name" {
  description = "The name of the EC2 Key Pair for instances in the UNTRUSTED environment."
  type        = string
}

variable "instance_os" {
  description = "The operating system for the EC2 instances. Valid options: 'amazon', 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "srt_udp_ports" {
  description = "A list of UDP ports to open for SRT ingress."
  type        = list(number)
  default     = [8890]
}

# FIXED: Changed from range to single port for better security
variable "peering_udp_port" {
  description = "Static UDP port for MediaMTX communication between trusted scrub and streaming"
  type        = number
  default     = 50555
}

# Instance type configurations by role
variable "instance_types" {
  description = "Instance types for different server roles"
  type = object({
    # Untrusted environment
    untrusted_ingress    = string  # Needs more CPU/bandwidth for streaming ingress
    untrusted_scrub      = string  # Light forwarding only
    untrusted_devops     = string  # Development/management tasks
    
    # Trusted environment  
    trusted_scrub        = string  # Processing + containers
    trusted_streaming    = string  # Video streaming (GPU optional)
    trusted_devops       = string  # Development/management tasks
  })
  
  default = {
    # Untrusted environment
    untrusted_ingress    = "c5.large"    # 2 vCPU, 4GB RAM - good for network I/O
    untrusted_scrub      = "t3.micro"    # 2 vCPU, 1GB RAM - minimal for forwarding
    untrusted_devops     = "t3.medium"   # 2 vCPU, 4GB RAM - development work
    
    # Trusted environment
    trusted_scrub        = "c5.large"    # 2 vCPU, 4GB RAM - container processing
    trusted_streaming    = "c5.large"    # 2 vCPU, 4GB RAM - default (GPU optional)
    trusted_devops       = "t3.medium"   # 2 vCPU, 4GB RAM - development work
  }
}

# GPU-specific configuration
variable "use_gpu_for_streaming" {
  description = "Whether to use GPU instance for trusted streaming host"
  type        = bool
  default     = false
}

variable "gpu_instance_type" {
  description = "GPU instance type for streaming when use_gpu_for_streaming is true"
  type        = string
  default     = "g5.xlarge"
}

# Keep this for backward compatibility (deprecated)
variable "default_instance_type" {
  description = "Default EC2 instance type (deprecated - use instance_types instead)"
  type        = string
  default     = "t3.small"
}

# Azure DevOps Agent Configuration
variable "enable_ado_agents" {
  description = "Whether to install Azure DevOps agents on DevOps hosts"
  type        = bool
  default     = false
}

variable "ado_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/yourorg)"
  type        = string
  default     = ""
}

variable "ado_agent_pool_name" {
  description = "Azure DevOps agent pool name"
  type        = string
  default     = "Default"
}

variable "ado_pat_secret_name" {
  description = "AWS Secrets Manager secret name containing ADO Personal Access Token"
  type        = string
  default     = ""
}

variable "deployment_ssh_key_secret_name" {
  description = "AWS Secrets Manager secret name containing SSH private key for deployments"
  type        = string
  default     = ""
}

variable "untrusted_cidr_block" {
  description = "The CIDR block for the untrusted"
  type        = string
  default     = "172.19.0.0/16"
}

variable "trusted_cidr_block" {
  description = "The CIDR block for the trusted"
  type        = string
  default     = "172.16.0.0/16"
}

variable "trusted_scrub_ami_id" {
  description = "Custom AMI ID specifically for trusted scrub host. Overrides other AMI settings when specified."
  type        = string
  default     = null
}

variable "trusted_streaming_ami_id" {
  description = "Custom AMI ID specifically for trusted streaming host. Overrides other AMI settings when specified."
  type        = string
  default     = null
}

variable "untrusted_scrub_ami_id" {
  description = "Custom AMI ID specifically for untrusted scrub host. Overrides other AMI settings when specified."
  type        = string
  default     = null
}

variable "untrusted_ingress_ami_id" {
  description = "Custom AMI ID specifically for untrusted ingress host. Overrides other AMI settings when specified."
  type        = string
  default     = null
}

variable "environment_tags" {
  description = "Environment tag values for different environments"
  type = object({
    trusted   = string
    untrusted = string
  })
  default = {
    trusted   = "Trusted"
    untrusted = "Untrusted"
  }
}

################################################################################
# RDS Configuration Variables
################################################################################

variable "rds_instance_class" {
  description = "RDS instance class for IoT database"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Whether to enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Whether to enable deletion protection for RDS"
  type        = bool
  default     = false
}

################################################################################
# ALB Certificate Configuration
################################################################################

variable "alb_certificate_arn" {
  description = "ARN of SSL certificate for Application Load Balancer (optional)"
  type        = string
  default     = null
}

################################################################################
# ECS Configuration Variables
################################################################################

variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Memory (MB) for ECS tasks"
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

################################################################################
# Cross-Region Configuration
################################################################################

variable "enable_cross_region_dns" {
  description = "Whether to enable cross-region DNS resolution"
  type        = bool
  default     = true
}

variable "eu_region" {
  description = "EU region for cross-region connectivity"
  type        = string
  default     = "eu-west-1"
}

################################################################################
# Monitoring and Alerting
################################################################################

variable "enable_enhanced_monitoring" {
  description = "Whether to enable enhanced monitoring for RDS and ECS"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "sns_alarm_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (optional)"
  type        = string
  default     = null
}

################################################################################
# Networking Configuration
################################################################################

variable "enable_vpc_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "VPC Flow Logs retention period in days"
  type        = number
  default     = 14
}


################################################################################
# Streaming RDS Configuration
################################################################################

variable "streaming_rds_instance_class" {
  description = "RDS instance class for streaming analytics database"
  type        = string
  default     = "db.t3.small"  # Slightly larger for analytics
}

variable "streaming_rds_multi_az" {
  description = "Whether to enable Multi-AZ deployment for streaming RDS"
  type        = bool
  default     = false
}

variable "streaming_rds_deletion_protection" {
  description = "Whether to enable deletion protection for streaming RDS"
  type        = bool
  default     = false
}

################################################################################
# Streaming ALB Configuration
################################################################################

variable "streaming_alb_certificate_arn" {
  description = "ARN of SSL certificate for Streaming Application Load Balancer (optional)"
  type        = string
  default     = null
}

################################################################################
# Streaming ECS Configuration
################################################################################

variable "streaming_task_cpu" {
  description = "CPU units for streaming ECS tasks (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024  # Higher for streaming services
}

variable "streaming_task_memory" {
  description = "Memory (MB) for streaming ECS tasks"
  type        = number
  default     = 2048  # Higher for streaming services
}

variable "streaming_player_cpu" {
  description = "CPU units for streaming player tasks (higher for video processing)"
  type        = number
  default     = 2048  # Higher CPU for video processing
}

variable "streaming_player_memory" {
  description = "Memory (MB) for streaming player tasks (higher for video processing)"
  type        = number
  default     = 4096  # Higher memory for video processing
}

variable "streaming_desired_count" {
  description = "Desired number of streaming ECS tasks"
  type        = number
  default     = 2  # Higher for streaming services
}

variable "streaming_player_desired_count" {
  description = "Desired number of streaming player tasks"
  type        = number
  default     = 2  # Always keep at least 2 for HA
}

################################################################################
# Streaming Queue Configuration
################################################################################

variable "streaming_queue_retention_days" {
  description = "Message retention period for streaming queues in days"
  type        = number
  default     = 14
}

variable "streaming_video_visibility_timeout" {
  description = "Visibility timeout for video processing queue in seconds"
  type        = number
  default     = 300  # 5 minutes for video processing
}

################################################################################
# Streaming Performance Configuration
################################################################################

variable "streaming_auto_scaling_target_cpu" {
  description = "Target CPU utilization for streaming services auto scaling"
  type        = number
  default     = 60
}

variable "streaming_auto_scaling_target_memory" {
  description = "Target memory utilization for streaming services auto scaling"
  type        = number
  default     = 70
}

variable "streaming_player_auto_scaling_target_cpu" {
  description = "Target CPU utilization for streaming player auto scaling"
  type        = number
  default     = 50  # Lower for video processing
}

variable "streaming_player_auto_scaling_target_memory" {
  description = "Target memory utilization for streaming player auto scaling"
  type        = number
  default     = 60  # Lower for video processing
}

################################################################################
# Streaming Monitoring Configuration
################################################################################

variable "streaming_video_queue_threshold" {
  description = "Threshold for video processing queue depth alarm"
  type        = number
  default     = 100
}

variable "streaming_cpu_alarm_threshold" {
  description = "CPU utilization threshold for streaming service alarms"
  type        = number
  default     = 80
}

variable "streaming_player_cpu_alarm_threshold" {
  description = "CPU utilization threshold for streaming player alarms"
  type        = number
  default     = 85
}

# IoT RDS Engine Configuration
variable "iot_rds_engine" {
  description = "Database engine for IoT RDS"
  type        = string
  default     = "mysql"
  validation {
    condition = contains([
      "mysql", "postgres", "mariadb", 
      "oracle-ee", "oracle-se2", "oracle-se1", "oracle-se",
      "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"
    ], var.iot_rds_engine)
    error_message = "RDS engine must be a valid AWS RDS engine type."
  }
}

variable "iot_rds_engine_version" {
  description = "Database engine version for IoT RDS"
  type        = string
  default     = "8.0"
}

variable "iot_rds_allocated_storage" {
  description = "Initial allocated storage for IoT RDS (GB)"
  type        = number
  default     = 20
}

variable "iot_rds_max_storage" {
  description = "Maximum allocated storage for IoT RDS (GB)"
  type        = number
  default     = 100
}

# Streaming RDS Engine Configuration
variable "streaming_rds_engine" {
  description = "Database engine for Streaming RDS"
  type        = string
  default     = "postgres"
  validation {
    condition = contains([
      "mysql", "postgres", "mariadb", 
      "oracle-ee", "oracle-se2", "oracle-se1", "oracle-se",
      "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"
    ], var.streaming_rds_engine)
    error_message = "RDS engine must be a valid AWS RDS engine type."
  }
}

variable "streaming_rds_engine_version" {
  description = "Database engine version for Streaming RDS"
  type        = string
  default     = "15.4"
}

variable "streaming_rds_allocated_storage" {
  description = "Initial allocated storage for Streaming RDS (GB)"
  type        = number
  default     = 50
}

variable "streaming_rds_max_storage" {
  description = "Maximum allocated storage for Streaming RDS (GB)"
  type        = number
  default     = 200
}

################################################################################
# ECS Service Configuration Variables - Backend and Frontend Only
################################################################################

variable "streaming_services" {
  description = "Configuration for streaming services - backend and frontend only"
  type = object({
    backend = object({
      image_name       = string
      container_port   = number
      health_check_path = string
      cpu             = number
      memory          = number
      desired_count   = number
      priority        = number
      path_patterns   = list(string)
    })
    frontend = object({
      image_name       = string
      container_port   = number
      health_check_path = string
      cpu             = number
      memory          = number
      desired_count   = number
      priority        = number
      path_patterns   = list(string)
    })
  })
  
  default = {
    backend = {
      image_name       = "streaming-backend"
      container_port   = 8080
      health_check_path = "/api/health"
      cpu             = 1024
      memory          = 2048
      desired_count   = 2
      priority        = 100
      path_patterns   = ["/api/*"]
    }
    frontend = {
      image_name       = "streaming-frontend"
      container_port   = 3000
      health_check_path = "/health"
      cpu             = 512
      memory          = 1024
      desired_count   = 1
      priority        = 200
      path_patterns   = ["/", "/*"]
    }
  }
}

variable "streaming_image_tags" {
  description = "Image tags for streaming services"
  type = object({
    backend  = string
    frontend = string
  })
  
  default = {
    backend  = "latest"
    frontend = "latest"
  }
}

################################################################################
# Auto Scaling Configuration - Backend and Frontend Only
################################################################################

variable "streaming_auto_scaling_config" {
  description = "Auto scaling configuration for streaming services"
  type = object({
    backend = object({
      min_capacity = number
      max_capacity = number
      cpu_target   = number
      memory_target = number
    })
    frontend = object({
      min_capacity = number
      max_capacity = number
      cpu_target   = number
      memory_target = number
    })
  })
  
  default = {
    backend = {
      min_capacity = 1
      max_capacity = 10
      cpu_target   = 70
      memory_target = 80
    }
    frontend = {
      min_capacity = 1
      max_capacity = 5
      cpu_target   = 70
      memory_target = 80
    }
  }
}
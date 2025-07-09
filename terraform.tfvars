# ----------------------------------------------------------------
#                 Updated Terraform Variables Configuration
# ----------------------------------------------------------------

# --- AWS Configuration ---
aws_profile = "728951503198_SystemAdministrator-8H"

# --- Project Configuration ---
project_name = "poc"
instance_os  = "ubuntu"

# --- SSH Key Configuration ---
trusted_ssh_key_name   = "sky-trusted"
untrusted_ssh_key_name = "sky-untrusted"

# --- VPN Configuration ---
trusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/e42ef4ec-db4c-4537-b16e-81d3c2c0b4e2"
untrusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/0c87fe07-ed4d-4810-b069-f6c6fe8c2f92"

# Use custom AMIs for EC2 instances
use_custom_amis = true
custom_standard_ami_id = "ami-0ea2fce7f7afb4f4c"

# Instance type configurations
instance_types = {
  # Untrusted environment
  untrusted_ingress    = "c5.large"   
  untrusted_scrub      = "t3.micro"    
  untrusted_devops     = "t3.medium"   
  
  # Trusted environment
  trusted_scrub        = "c5.large"    
  trusted_streaming    = "c5.large"    
  trusted_devops       = "t3.medium"   
}

# GPU configuration for streaming
use_gpu_for_streaming = true          
gpu_instance_type     = "g5.xlarge"   
custom_gpu_ami_id = "ami-04e22fc5618e54eac"  

# UDP ports for SRT streaming
srt_udp_ports = [8890]

# Azure DevOps Agent Configuration
enable_ado_agents      = true
ado_organization_url   = "https://dev.azure.com/cloudburstnet"
ado_agent_pool_name    = "Self-Hosted-AWS"
ado_pat_secret_name    = "poc-ado-pat"           
     

peering_udp_port = 50555
trusted_asn = 64512
untrusted_asn = 64513

# ----------------------------------------------------------------
# NEW IOT INFRASTRUCTURE CONFIGURATION
# ----------------------------------------------------------------

# --- RDS Configuration ---
rds_instance_class      = "db.t3.micro"      # Start small, can scale up
rds_multi_az           = false               # Set to true for production
rds_deletion_protection = false              # Set to true for production

# --- ALB Configuration ---
# alb_certificate_arn = "arn:aws:acm:il-central-1:123456789012:certificate/your-cert-id"  # Optional SSL cert

# --- ECS Configuration ---
ecs_task_cpu        = 512                    # CPU units (256, 512, 1024, etc.)
ecs_task_memory     = 1024                   # Memory in MB
ecs_desired_count   = 1                      # Number of tasks per service

# --- Cross-Region Configuration ---
enable_cross_region_dns = true
eu_region              = "eu-west-1"

# --- Monitoring Configuration ---
enable_enhanced_monitoring    = true
cloudwatch_log_retention_days = 7
# sns_alarm_topic_arn = "arn:aws:sns:il-central-1:123456789012:alerts"  # Optional

# --- Networking Configuration ---
enable_vpc_flow_logs     = false            # Set to true for enhanced security monitoring
flow_logs_retention_days = 14

# --- IoT RDS Configuration ---
iot_rds_engine = "mysql"          # Options: mysql, postgres, mariadb, oracle-ee
iot_rds_engine_version = "8.0.35"
iot_rds_allocated_storage = 20          # Start small, can scale up
iot_rds_max_storage = 100               # Max storage for IoT data

# ----------------------------------------------------------------
# STREAMING INFRASTRUCTURE CONFIGURATION - FIXED VERSIONS
# ----------------------------------------------------------------

# --- Streaming RDS Configuration ---
streaming_rds_instance_class      = "db.t3.small"     # Slightly larger for analytics
streaming_rds_multi_az           = false              # Set to true for production
streaming_rds_deletion_protection = false             # Set to true for production

# --- Streaming ALB Configuration ---
# streaming_alb_certificate_arn = "arn:aws:acm:il-central-1:123456789012:certificate/your-streaming-cert-id"  # Optional SSL cert

# --- Streaming ECS Configuration ---
streaming_task_cpu        = 1024                      # Higher CPU for streaming services
streaming_task_memory     = 2048                      # Higher memory for streaming services
streaming_player_cpu      = 2048                      # Higher CPU for video processing
streaming_player_memory   = 4096                      # Higher memory for video processing
streaming_desired_count   = 2                         # Higher count for streaming services
streaming_player_desired_count = 2                    # Always keep at least 2 for HA

# --- Streaming Queue Configuration ---
streaming_queue_retention_days     = 14               # 14 days retention for video processing
streaming_video_visibility_timeout = 300              # 5 minutes for video processing

# --- Streaming Performance Configuration ---
streaming_auto_scaling_target_cpu        = 60         # Lower CPU target for streaming
streaming_auto_scaling_target_memory     = 70         # Memory target for streaming
streaming_player_auto_scaling_target_cpu = 50         # Lower CPU target for video processing
streaming_player_auto_scaling_target_memory = 60      # Lower memory target for video processing

# --- Streaming Monitoring Configuration ---
streaming_video_queue_threshold        = 100          # Alert when queue has >100 videos
streaming_cpu_alarm_threshold          = 80           # CPU alarm threshold
streaming_player_cpu_alarm_threshold   = 85           # Higher threshold for video 

# --- Streaming RDS Configuration - FIXED POSTGRESQL VERSION ---
streaming_rds_engine            = "postgres"      # Different engine for streaming
streaming_rds_engine_version    = "17.4"          # FIXED: Valid PostgreSQL version
streaming_rds_allocated_storage = 50              # More storage for streaming data
streaming_rds_max_storage      = 200             # Higher max storage


# ----------------------------------------------------------------
# STREAMING SERVICES CONFIGURATION - Backend and Frontend Only
# ----------------------------------------------------------------

# --- Streaming Services Configuration ---
streaming_services = {
  backend = {
    image_name       = "streaming-backend"      # Maps to trusted-backend-images ECR
    container_port   = 8080
    health_check_path = "/api/health"
    cpu             = 1024
    memory          = 2048
    desired_count   = 2
    priority        = 100
    path_patterns   = ["/api/*"]
  }
  frontend = {
    image_name       = "streaming-frontend"     # Maps to trusted-frontend-images ECR
    container_port   = 8080
    health_check_path = "/"
    cpu             = 512
    memory          = 1024
    desired_count   = 1
    priority        = 200
    path_patterns   = ["/", "/*"]               # Catch-all for frontend
  }
}

# --- Image Tags for Deployment ---
streaming_image_tags = {
  backend  = "streaming-backend-latest"
  frontend = "streaming-frontend-latest"  
}

# --- Auto Scaling Configuration ---
streaming_auto_scaling_config = {
  backend = {
    min_capacity = 1
    max_capacity = 10
    cpu_target   = 70      # Scale when CPU > 70%
    memory_target = 80     # Scale when Memory > 80%
  }
  frontend = {
    min_capacity = 1
    max_capacity = 5
    cpu_target   = 70
    memory_target = 80
  }
}

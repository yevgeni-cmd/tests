# terraform.tfvars - UPDATED WITH PROPER INTERNAL DOMAIN

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

vpn_authentication_type    = "saml"
saml_identity_provider_arn = "arn:aws:iam::728951503198:saml-provider/sky-poc"

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
# IOT INFRASTRUCTURE CONFIGURATION
# ----------------------------------------------------------------

# --- RDS Configuration ---
rds_instance_class      = "db.t3.micro"
rds_multi_az           = false
rds_deletion_protection = false

# --- ECS Configuration ---
ecs_task_cpu        = 512
ecs_task_memory     = 1024
ecs_desired_count   = 1

# --- Cross-Region Configuration ---
enable_cross_region_dns = true
eu_region              = "eu-west-1"

# --- Monitoring Configuration ---
enable_enhanced_monitoring    = true
cloudwatch_log_retention_days = 7

# --- Networking Configuration ---
enable_vpc_flow_logs     = false
flow_logs_retention_days = 14

# --- IoT RDS Configuration ---
iot_rds_engine = "mysql"
iot_rds_engine_version = "8.0.35"
iot_rds_allocated_storage = 20
iot_rds_max_storage = 100

# ----------------------------------------------------------------
# STREAMING INFRASTRUCTURE CONFIGURATION - FIXED VERSIONS
# ----------------------------------------------------------------

# --- Streaming RDS Configuration ---
streaming_rds_instance_class      = "db.t3.small"
streaming_rds_multi_az           = false
streaming_rds_deletion_protection = false

# --- Streaming ECS Configuration ---
streaming_task_cpu        = 1024
streaming_task_memory     = 2048
streaming_player_cpu      = 2048
streaming_player_memory   = 4096
streaming_desired_count   = 2
streaming_player_desired_count = 2

# --- Streaming Queue Configuration ---
streaming_queue_retention_days     = 14
streaming_video_visibility_timeout = 300

# --- Streaming Performance Configuration ---
streaming_auto_scaling_target_cpu        = 60
streaming_auto_scaling_target_memory     = 70
streaming_player_auto_scaling_target_cpu = 50
streaming_player_auto_scaling_target_memory = 60

# --- Streaming Monitoring Configuration ---
streaming_video_queue_threshold        = 100
streaming_cpu_alarm_threshold          = 80
streaming_player_cpu_alarm_threshold   = 85

# --- Streaming RDS Configuration - FIXED POSTGRESQL VERSION ---
streaming_rds_engine            = "postgres"
streaming_rds_engine_version    = "17.4"
streaming_rds_allocated_storage = 50
streaming_rds_max_storage      = 200

# ----------------------------------------------------------------
# STREAMING SERVICES CONFIGURATION - Backend and Frontend Only
# ----------------------------------------------------------------

# --- Streaming Services Configuration ---
streaming_services = {
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
    container_port   = 8080
    health_check_path = "/"
    cpu             = 512
    memory          = 1024
    desired_count   = 1
    priority        = 200
    path_patterns   = ["/", "/*"]
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

# ----------------------------------------------------------------
# FIXED: PROPER INTERNAL DOMAIN CONFIGURATION
# ----------------------------------------------------------------

# FIXED: Use a proper internal domain that's not AWS reserved
internal_domain = "sky.local"  # Changed from "sky.internal" to avoid potential conflicts

# Organization details for certificates
organization_name = "Sky PoC"

# Enable private CA and DNS
enable_private_ca = true
ca_validity_years = 10
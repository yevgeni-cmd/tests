################################################################################
# RDS Database for Streaming Analytics
################################################################################

# Security Group for Streaming RDS - FIXED for VPN access
resource "aws_security_group" "streaming_rds_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-streaming-rds-sg"
  description = "Security group for Streaming RDS database"
  vpc_id      = module.trusted_vpc_streaming.vpc_id

  # Allow inbound from ECS containers
  ingress {
    description = "MySQL/Aurora from ECS containers"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.trusted_vpc_streaming.private_subnets_by_name["ecs-containers"].cidr_block]
  }

  # Allow inbound from ALB subnets
  ingress {
    description = "MySQL/Aurora from ALB subnets"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [
      module.trusted_vpc_streaming.private_subnets_by_name["alb-az-a"].cidr_block,
      module.trusted_vpc_streaming.private_subnets_by_name["alb-az-b"].cidr_block
    ]
  }

  # FIXED: Allow inbound from VPN clients AND DevOps VPC (due to SNAT)
  ingress {
    description = "MySQL/Aurora from VPN clients and DevOps VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  # Allow inbound from streaming-docker subnet
  ingress {
    description = "MySQL/Aurora from streaming hosts"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.trusted_vpc_streaming.private_subnets_by_name["streaming-docker"].cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-streaming-rds-sg"
    Environment = var.environment_tags.trusted
  }
}

module "streaming_rds_database" {
  source = "./modules/rds"
  providers = { aws = aws.primary }

  db_identifier      = "${var.project_name}-streaming-database"
  db_name           = "streaminganalytics"
  engine            = var.streaming_rds_engine         
  engine_version    = var.streaming_rds_engine_version   
  instance_class    = var.streaming_rds_instance_class
  allocated_storage = var.streaming_rds_allocated_storage
  max_allocated_storage = var.streaming_rds_max_storage
  storage_type      = "gp3"
  storage_encrypted = true
  
  # Network Configuration
  db_subnet_group_name = "${var.project_name}-streaming-db-subnet-group"
  subnet_ids = [
    module.trusted_vpc_streaming.private_subnets_by_name["alb-az-a"].id,
    module.trusted_vpc_streaming.private_subnets_by_name["alb-az-b"].id
  ]
  vpc_security_group_ids = [aws_security_group.streaming_rds_sg.id]
  
  # Authentication
  master_username = "streamingadmin"
  manage_master_user_password = true
  
  # Backup and Maintenance
  backup_retention_period = 14  # Longer retention for analytics
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  multi_az              = var.streaming_rds_multi_az
  
  # Monitoring
  performance_insights_enabled = true
  monitoring_interval         = 60
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Alarms
  enable_cloudwatch_alarms    = true
  cpu_utilization_threshold   = 80
  connection_count_threshold  = 80
  
  # Protection
  deletion_protection    = var.streaming_rds_deletion_protection
  skip_final_snapshot   = false
  
  tags = {
    Name        = "${var.project_name}-streaming-database"
    Environment = var.environment_tags.trusted
    Purpose     = "Streaming Analytics Database"
  }
}

################################################################################
# SQS Queues for Streaming Pipeline
################################################################################

# Video Processing Queue
module "streaming_video_queue" {
  source = "./modules/sqs_queue"
  providers = { aws = aws.primary }
  
  queue_name                    = "${var.project_name}-video-processing-queue"
  delay_seconds                = 0
  max_message_size             = 262144
  message_retention_seconds    = 1209600  # 14 days
  visibility_timeout_seconds   = 300      # 5 minutes for video processing
  receive_wait_time_seconds    = 20
  
  # Dead Letter Queue
  enable_dlq                   = true
  max_receive_count           = 3
  dlq_message_retention_seconds = 345600  # 4 days
  
  # Encryption
  kms_master_key_id = "alias/aws/sqs"
  
  # Monitoring
  enable_cloudwatch_alarms     = true
  high_message_count_threshold = 500
  alarm_actions               = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []
  
  tags = {
    Name        = "${var.project_name}-video-processing-queue"
    Environment = var.environment_tags.trusted
    Purpose     = "Video processing pipeline"
  }
}

# Transcoding Results Queue
module "streaming_transcoding_queue" {
  source = "./modules/sqs_queue"
  providers = { aws = aws.primary }
  
  queue_name                   = "${var.project_name}-transcoding-results-queue"
  delay_seconds               = 0
  visibility_timeout_seconds  = 60
  message_retention_seconds   = 604800  # 7 days
  
  enable_dlq                  = true
  max_receive_count          = 3
  
  kms_master_key_id = "alias/aws/sqs"
  
  enable_cloudwatch_alarms     = true
  high_message_count_threshold = 200
  alarm_actions               = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []
  
  tags = {
    Name        = "${var.project_name}-transcoding-results"
    Environment = var.environment_tags.trusted
    Purpose     = "Transcoding results and notifications"
  }
}

# Analytics Events Queue
module "streaming_analytics_queue" {
  source = "./modules/sqs_queue"
  providers = { aws = aws.primary }
  
  queue_name                   = "${var.project_name}-analytics-events-queue"
  delay_seconds               = 0
  visibility_timeout_seconds  = 30
  message_retention_seconds   = 1209600  # 14 days
  
  enable_dlq                  = true
  max_receive_count          = 5
  
  kms_master_key_id = "alias/aws/sqs"
  
  enable_cloudwatch_alarms     = true
  high_message_count_threshold = 1000
  alarm_actions               = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []
  
  tags = {
    Name        = "${var.project_name}-analytics-events"
    Environment = var.environment_tags.trusted
    Purpose     = "Streaming analytics and metrics"
  }
}

################################################################################
# ECS Cluster for Streaming Services
################################################################################

module "streaming_ecs_cluster" {
  source = "./modules/ecs_cluster"
  providers = { aws = aws.primary }
  
  cluster_name             = "${var.project_name}-streaming-cluster"
  enable_container_insights = true
  
  # Capacity providers with SPOT for cost optimization
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = {
    base              = 1
    weight            = 50   # 50% FARGATE, 50% FARGATE_SPOT
    capacity_provider = "FARGATE"
  }
  
  # CloudWatch logs
  log_retention_days = var.cloudwatch_log_retention_days
  
  # IAM permissions for streaming services - FIX: Pass actual secret ARNs
  secrets_arns = [
    module.streaming_rds_database.master_user_secret_arn
  ]
  sqs_queue_arns = [
    module.streaming_video_queue.queue_arn,
    module.streaming_transcoding_queue.queue_arn,
    module.streaming_analytics_queue.queue_arn
  ]
  
  tags = {
    Name        = "${var.project_name}-streaming-ecs-cluster"
    Environment = var.environment_tags.trusted
    Purpose     = "Video Streaming and Processing Services"
  }
}

################################################################################
# Application Load Balancer for Streaming Services
################################################################################

# Security Group for Streaming ALB - FIXED for VPN access
resource "aws_security_group" "streaming_alb_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-streaming-alb-sg"
  description = "Security group for Streaming Application Load Balancer"
  vpc_id      = module.trusted_vpc_streaming.vpc_id

  # FIXED: Allow HTTPS from VPN clients AND DevOps VPC (due to SNAT)
  ingress {
    description = "HTTPS from VPN clients and DevOps VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  # FIXED: Allow HTTP from VPN clients AND DevOps VPC (due to SNAT)
  ingress {
    description = "HTTP from VPN clients and DevOps VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  # FIXED: Allow streaming ports from VPN clients AND DevOps VPC (due to SNAT)
  ingress {
    description = "Streaming ports from VPN clients and DevOps VPC"
    from_port   = 1935  # RTMP
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  # FIXED: Allow HLS/DASH from VPN clients AND DevOps VPC (due to SNAT)
  ingress {
    description = "HLS/DASH from VPN clients and DevOps VPC"
    from_port   = 8080
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  # Allow all outbound
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-streaming-alb-sg"
    Environment = var.environment_tags.trusted
  }
}

# Simplified ALB configuration in stream-vpc-infrastructure.tf

module "streaming_application_load_balancer" {
  source = "./modules/application_load_balancer"
  providers = { aws = aws.primary }
  
  alb_name           = "${var.project_name}-streaming-alb"
  internal           = true
  vpc_id             = module.trusted_vpc_streaming.vpc_id
  security_group_ids = [aws_security_group.streaming_alb_sg.id]
  
  # Multi-AZ subnets
  subnet_ids = [
    module.trusted_vpc_streaming.private_subnets_by_name["alb-az-a"].id,
    module.trusted_vpc_streaming.private_subnets_by_name["alb-az-b"].id
  ]
  
  # SSL Configuration (optional)
  certificate_arn = var.streaming_alb_certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  # Load balancer settings
  enable_deletion_protection        = false
  enable_cross_zone_load_balancing = true
  enable_http_listener             = true
  
  # FIXED: Target group names must match ECS service references
  target_groups = {
    streaming_backend = {  # ✅ Matches ECS service load_balancer reference
      name              = "${var.project_name}-streaming-backend-tg"
      port              = var.streaming_services.backend.container_port
      protocol          = "HTTP"
      priority          = var.streaming_services.backend.priority
      path_patterns     = var.streaming_services.backend.path_patterns
      host_headers      = null
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 10
        interval            = 30
        path               = var.streaming_services.backend.health_check_path
        matcher            = "200"
        protocol           = "HTTP"
      }
    }
    
    streaming_frontend = {  # ✅ Matches ECS service load_balancer reference
      name              = "${var.project_name}-streaming-frontend-tg"
      port              = var.streaming_services.frontend.container_port
      protocol          = "HTTP"
      priority          = var.streaming_services.frontend.priority
      path_patterns     = var.streaming_services.frontend.path_patterns
      host_headers      = null
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 10
        interval            = 30
        path               = var.streaming_services.frontend.health_check_path
        matcher            = "200"
        protocol           = "HTTP"
      }
    }
  }
  
  # Logging
  enable_access_logs  = true
  log_retention_days  = var.cloudwatch_log_retention_days
  
  tags = {
    Name        = "${var.project_name}-streaming-alb"
    Environment = var.environment_tags.trusted
    Purpose     = "Streaming Backend and Frontend Access"
  }
}

################################################################################
# Security Group for Streaming ECS Services - FIXED for VPN access
################################################################################

resource "aws_security_group" "streaming_ecs_services_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-streaming-ecs-services-sg"
  description = "Security group for Streaming ECS services"
  vpc_id      = module.trusted_vpc_streaming.vpc_id

  # Allow inbound from ALB
  ingress {
    description     = "HTTP from Streaming ALB"
    from_port       = 3000
    to_port         = 8090
    protocol        = "tcp"
    security_groups = [aws_security_group.streaming_alb_sg.id]
  }

  # FIXED: Allow inbound from VPN for direct access (both client CIDR and DevOps VPC)
  ingress {
    description = "HTTP from VPN clients and DevOps VPC"
    from_port   = 3000
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  egress {
    description = "HTTPS for ECR, Secrets Manager, and AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ADD THIS RULE - DNS lookups
  egress {
    description = "DNS lookups"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS lookups UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FIXED: Allow UDP for streaming protocols from VPN clients AND DevOps VPC (due to SNAT)
  ingress {
    description = "UDP streaming from VPN clients and DevOps VPC"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [
      var.trusted_vpn_client_cidr,           # Original VPN client CIDR
      var.trusted_vpc_cidrs["devops"]        # DevOps VPC CIDR (SNAT source)
    ]
  }

  # Allow all outbound
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-streaming-ecs-services-sg"
    Environment = var.environment_tags.trusted
  }
}
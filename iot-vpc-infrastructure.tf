################################################################################
# RDS Database for IoT Management
################################################################################

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = module.trusted_vpc_iot.vpc_id

  # Allow inbound from ECS containers
  ingress {
    description = "MySQL/Aurora from ECS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.trusted_vpc_iot.private_subnets_by_name["ecs"].cidr_block]
  }

  # Allow inbound from ALB subnets (for management)
  ingress {
    description = "MySQL/Aurora from ALB subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [
      module.trusted_vpc_iot.private_subnets_by_name["alb-az-a"].cidr_block,
      module.trusted_vpc_iot.private_subnets_by_name["alb-az-b"].cidr_block
    ]
  }

  # Allow inbound from VPN clients
  ingress {
    description = "MySQL/Aurora from VPN clients"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Environment = var.environment_tags.trusted
  }
}

module "iot_rds_database" {
  source = "./modules/rds"
  providers = { aws = aws.primary }
  db_identifier      = "${var.project_name}-iot-database"
  db_name           = "iotmanagement"
  engine            = var.iot_rds_engine              
  engine_version    = var.iot_rds_engine_version      
  instance_class    = var.rds_instance_class
  allocated_storage = var.iot_rds_allocated_storage   
  max_allocated_storage = var.iot_rds_max_storage
  storage_type      = "gp3"
  storage_encrypted = true
  
  # Network Configuration
  db_subnet_group_name = "${var.project_name}-iot-db-subnet-group"
  subnet_ids = [
    module.trusted_vpc_iot.private_subnets_by_name["alb-az-a"].id,
    module.trusted_vpc_iot.private_subnets_by_name["alb-az-b"].id
  ]
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  # Authentication
  master_username = "iotadmin"
  manage_master_user_password = true  # AWS managed password
  
  # Backup and Maintenance
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  multi_az              = var.rds_multi_az
  
  # Monitoring
  performance_insights_enabled = true
  monitoring_interval         = 60
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  # Alarms
  enable_cloudwatch_alarms    = true
  cpu_utilization_threshold   = 80
  connection_count_threshold  = 80
  
  # Protection
  deletion_protection    = var.rds_deletion_protection
  skip_final_snapshot   = false
  
  tags = {
    Name        = "${var.project_name}-iot-database"
    Environment = var.environment_tags.trusted
    Purpose     = "IoT Management Database"
  }
}

################################################################################
# ECS Cluster for IoT Management
################################################################################

module "iot_ecs_cluster" {
  source = "./modules/ecs_cluster"
  providers = { aws = aws.primary }
  
  cluster_name             = "${var.project_name}-iot-cluster"
  enable_container_insights = true
  
  # Capacity providers
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
  
  # CloudWatch logs
  log_retention_days = var.cloudwatch_log_retention_days
  
  # IAM permissions - FIX: Pass actual secret ARNs after RDS is created
  secrets_arns = [
    module.iot_rds_database.master_user_secret_arn
  ]
  sqs_queue_arns = [
    module.jacob_sqs_queues.queue_arn,
    module.jacob_response_sqs_queue.queue_arn
  ]
  
  tags = {
    Name        = "${var.project_name}-iot-ecs-cluster"
    Environment = var.environment_tags.trusted
    Purpose     = "IoT Management Services"
  }
}

################################################################################
# Application Load Balancer for ECS Access
################################################################################

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.trusted_vpc_iot.vpc_id

  # Allow HTTPS from VPN clients
  ingress {
    description = "HTTPS from VPN clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # Allow HTTP from VPN clients (will redirect to HTTPS or serve directly)
  ingress {
    description = "HTTP from VPN clients"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # Allow all outbound (to ECS containers)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment_tags.trusted
  }
}

module "iot_application_load_balancer" {
  source = "./modules/application_load_balancer"
  providers = { aws = aws.primary }
  
  alb_name           = "${var.project_name}-iot-alb"
  internal           = true
  vpc_id             = module.trusted_vpc_iot.vpc_id
  security_group_ids = [aws_security_group.alb_sg.id]
  
  subnet_ids = [
    module.trusted_vpc_iot.private_subnets_by_name["alb-az-a"].id,
    module.trusted_vpc_iot.private_subnets_by_name["alb-az-b"].id
  ]
  
  # FIXED: Use conditional logic for certificate
  certificate_arn = var.enable_private_ca && can(aws_acm_certificate.iot_internal.arn) ? aws_acm_certificate.iot_internal.arn : var.alb_certificate_arn
  enable_https_listener = var.alb_certificate_arn != null || var.enable_private_ca
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  
  enable_deletion_protection        = false
  enable_cross_zone_load_balancing = false
  enable_http_listener             = true

  target_groups = {
    iot_api = {
      name              = "${var.project_name}-iot-api-tg"
      port              = 8080
      protocol          = "HTTP"
      priority          = 100
      path_patterns     = ["/api/*"]
      host_headers      = null
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 30
        path               = "/api/health"
        matcher            = "200"
        protocol           = "HTTP"
      }
    }
    
    iot_dashboard = {
      name              = "${var.project_name}-iot-dashboard-tg"
      port              = 8080
      protocol          = "HTTP"
      priority          = 200
      path_patterns     = ["/*"]
      host_headers      = null
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 30
        path               = "/"
        matcher            = "200"
        protocol           = "HTTP"
      }
    }
  }
  
  # Logging
  enable_access_logs  = false  # Set to true if you want ALB access logs
  log_retention_days  = var.cloudwatch_log_retention_days
  
  tags = {
    Name        = "${var.project_name}-iot-alb"
    Environment = var.environment_tags.trusted
    Purpose     = "IoT Management Application Access"
  }
}

################################################################################
# REMOVED: Route53 Private Hosted Zone (causes AWS reserved domain error)
################################################################################

# REMOVED the Route53 zone creation that was causing the AWS reserved domain error
# Private DNS for VPC endpoints is handled automatically by AWS

################################################################################
# Security Group for ECS Services
################################################################################

resource "aws_security_group" "ecs_services_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-ecs-services-sg"
  description = "Security group for ECS services in IoT VPC"
  vpc_id      = module.trusted_vpc_iot.vpc_id

  # Allow inbound from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow inbound from VPN for direct access
  ingress {
    description = "HTTP from VPN clients"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # Allow all outbound for external API calls, RDS, SQS
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-services-sg"
    Environment = var.environment_tags.trusted
  }
}
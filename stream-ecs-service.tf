################################################################################
# ECS Task Definitions - Backend and Frontend Only - FIXED
################################################################################

# Locals for building dynamic configurations
locals {
  # Build ECR URLs for each service
  streaming_ecr_urls = {
    backend  = "${aws_ecr_repository.trusted_backend.repository_url}:${var.streaming_image_tags.backend}"
    frontend = "${aws_ecr_repository.trusted_frontend.repository_url}:${var.streaming_image_tags.frontend}"
  }
  
  # Environment variables for all services - UPDATED with DB info
  common_environment = [
    {
      name  = "NODE_ENV"
      value = "production"
    },
    {
      name  = "AWS_REGION"
      value = var.primary_region
    },
    {
      name  = "PROJECT_NAME"
      value = var.project_name
    },
    {
      name  = "DB_HOST"
      value = module.streaming_rds_database.db_instance_endpoint
    },
    {
      name  = "DB_NAME"
      value = module.streaming_rds_database.db_instance_name
    }
  ]
  
  # Common secrets for database access - FIXED to only include what exists
  common_secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${module.streaming_rds_database.master_user_secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${module.streaming_rds_database.master_user_secret_arn}:password::"
    }
  ]
}

# Backend API Service Task Definition
resource "aws_ecs_task_definition" "streaming_backend" {
  provider                 = aws.primary
  family                   = "${var.project_name}-streaming-backend"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.streaming_services.backend.cpu
  memory                  = var.streaming_services.backend.memory
  execution_role_arn      = module.streaming_ecs_cluster.execution_role_arn
  task_role_arn          = module.streaming_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "streaming-backend"
      image = local.streaming_ecr_urls.backend
      
      essential = true
      
      portMappings = [
        {
          containerPort = var.streaming_services.backend.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_environment, [
        {
          name  = "PORT"
          value = tostring(var.streaming_services.backend.container_port)
        },
        {
          name  = "SERVICE_TYPE"
          value = "backend-api"
        },
        {
          name  = "VIDEO_QUEUE_URL"
          value = module.streaming_video_queue.queue_url
        },
        {
          name  = "TRANSCODING_QUEUE_URL"
          value = module.streaming_transcoding_queue.queue_url
        },
        {
          name  = "ANALYTICS_QUEUE_URL"
          value = module.streaming_analytics_queue.queue_url
        }
      ])
      
      secrets = local.common_secrets
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.streaming_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "streaming-backend"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.streaming_services.backend.container_port}${var.streaming_services.backend.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-streaming-backend-task"
    Environment = var.environment_tags.trusted
    Service     = "streaming-backend"
  }
}

# Frontend Service Task Definition
resource "aws_ecs_task_definition" "streaming_frontend" {
  provider                 = aws.primary
  family                   = "${var.project_name}-streaming-frontend"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.streaming_services.frontend.cpu
  memory                  = var.streaming_services.frontend.memory
  execution_role_arn      = module.streaming_ecs_cluster.execution_role_arn
  task_role_arn          = module.streaming_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "streaming-frontend"
      image = local.streaming_ecr_urls.frontend
      
      essential = true
      
      portMappings = [
        {
          containerPort = var.streaming_services.frontend.container_port
          protocol      = "tcp"
        }
      ]
      
      environment = concat(local.common_environment, [
        {
          name  = "PORT"
          value = tostring(var.streaming_services.frontend.container_port)
        },
        {
          name  = "SERVICE_TYPE"
          value = "frontend"
        },
        {
          name  = "API_BASE_URL"
          value = "http://localhost:${var.streaming_services.backend.container_port}/api"
        }
      ])
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.streaming_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "streaming-frontend"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:${var.streaming_services.frontend.container_port}${var.streaming_services.frontend.health_check_path} || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-streaming-frontend-task"
    Environment = var.environment_tags.trusted
    Service     = "streaming-frontend"
  }
}

################################################################################
# ECS Services - Backend and Frontend Only
################################################################################

# Backend Service
resource "aws_ecs_service" "streaming_backend" {
  provider        = aws.primary
  name            = "${var.project_name}-streaming-backend-service"
  cluster         = module.streaming_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.streaming_backend.arn
  desired_count   = var.streaming_services.backend.desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_streaming.private_subnets_by_name["ecs-containers"].id]
    security_groups = [aws_security_group.streaming_ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.streaming_application_load_balancer.target_group_arns["streaming_backend"]
    container_name   = "streaming-backend"
    container_port   = var.streaming_services.backend.container_port
  }
  
  deployment_controller {
    type = "ECS"
  }
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  enable_execute_command = true
  
  depends_on = [
    module.streaming_application_load_balancer,
    aws_ecs_task_definition.streaming_backend
  ]

  tags = {
    Name        = "${var.project_name}-streaming-backend-service"
    Environment = var.environment_tags.trusted
    Service     = "streaming-backend"
  }
}

# Frontend Service
resource "aws_ecs_service" "streaming_frontend" {
  provider        = aws.primary
  name            = "${var.project_name}-streaming-frontend-service"
  cluster         = module.streaming_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.streaming_frontend.arn
  desired_count   = var.streaming_services.frontend.desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_streaming.private_subnets_by_name["ecs-containers"].id]
    security_groups = [aws_security_group.streaming_ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.streaming_application_load_balancer.target_group_arns["streaming_frontend"]
    container_name   = "streaming-frontend"
    container_port   = var.streaming_services.frontend.container_port
  }
  
  deployment_controller {
    type = "ECS"
  }
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  enable_execute_command = true
  
  depends_on = [
    module.streaming_application_load_balancer,
    aws_ecs_task_definition.streaming_frontend
  ]

  tags = {
    Name        = "${var.project_name}-streaming-frontend-service"
    Environment = var.environment_tags.trusted
    Service     = "streaming-frontend"
  }
}

################################################################################
# Service Auto Scaling - Backend and Frontend Only
################################################################################

# Auto Scaling Target for Backend
resource "aws_appautoscaling_target" "streaming_backend" {
  max_capacity       = var.streaming_auto_scaling_config.backend.max_capacity
  min_capacity       = var.streaming_auto_scaling_config.backend.min_capacity
  resource_id        = "service/${module.streaming_ecs_cluster.cluster_name}/${aws_ecs_service.streaming_backend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for Backend (CPU-based)
resource "aws_appautoscaling_policy" "streaming_backend_cpu" {
  name               = "${var.project_name}-streaming-backend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_backend.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_backend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_backend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.streaming_auto_scaling_config.backend.cpu_target
  }
}

# Auto Scaling Target for Frontend
resource "aws_appautoscaling_target" "streaming_frontend" {
  max_capacity       = var.streaming_auto_scaling_config.frontend.max_capacity
  min_capacity       = var.streaming_auto_scaling_config.frontend.min_capacity
  resource_id        = "service/${module.streaming_ecs_cluster.cluster_name}/${aws_ecs_service.streaming_frontend.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for Frontend (CPU-based)
resource "aws_appautoscaling_policy" "streaming_frontend_cpu" {
  name               = "${var.project_name}-streaming-frontend-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_frontend.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_frontend.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_frontend.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.streaming_auto_scaling_config.frontend.cpu_target
  }
}
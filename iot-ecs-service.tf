################################################################################
# ECS Task Definitions
################################################################################

# IoT API Service Task Definition
resource "aws_ecs_task_definition" "iot_api" {
  provider                 = aws.primary
  family                   = "${var.project_name}-iot-api"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.ecs_task_cpu
  memory                  = var.ecs_task_memory
  execution_role_arn      = module.iot_ecs_cluster.execution_role_arn
  task_role_arn          = module.iot_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "iot-api"
      image = "${aws_ecr_repository.trusted_devops.repository_url}:iot-api-latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = "8080"
        },
        {
          name  = "SQS_QUEUE_URL"
          value = module.jacob_sqs_queues.queue_url
        },
        {
          name  = "SQS_RESPONSE_QUEUE_URL"
          value = module.jacob_response_sqs_queue.queue_url
        }
      ]
      
      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = "${module.iot_rds_database.master_user_secret_arn}:endpoint::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${module.iot_rds_database.master_user_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${module.iot_rds_database.master_user_secret_arn}:password::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${module.iot_rds_database.master_user_secret_arn}:dbname::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.iot_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "iot-api"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8080/api/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-iot-api-task"
    Environment = var.environment_tags.trusted
    Service     = "iot-api"
  }
}

# IoT Dashboard Task Definition
resource "aws_ecs_task_definition" "iot_dashboard" {
  provider                 = aws.primary
  family                   = "${var.project_name}-iot-dashboard"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.ecs_task_cpu
  memory                  = var.ecs_task_memory
  execution_role_arn      = module.iot_ecs_cluster.execution_role_arn
  task_role_arn          = module.iot_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "iot-dashboard"
      image = "${aws_ecr_repository.trusted_devops.repository_url}:iot-dashboard-latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PORT"
          value = "3000"
        },
        {
          name  = "API_BASE_URL"
          value = "http://localhost:8080/api"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.iot_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "iot-dashboard"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:3000/ || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-iot-dashboard-task"
    Environment = var.environment_tags.trusted
    Service     = "iot-dashboard"
  }
}

################################################################################
# ECS Services - CORRECTED: Proper AWS ECS Service syntax
################################################################################

# IoT API Service
resource "aws_ecs_service" "iot_api" {
  provider        = aws.primary
  name            = "${var.project_name}-iot-api-service"
  cluster         = module.iot_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.iot_api.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_iot.private_subnets_by_name["ecs"].id]
    security_groups = [aws_security_group.ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.iot_application_load_balancer.target_group_arns["iot_api"]
    container_name   = "iot-api"
    container_port   = 8080
  }
  
  # CORRECT: deployment_controller block (not deployment_configuration)
  deployment_controller {
    type = "ECS"
  }
  
  # CORRECT: deployment_circuit_breaker is a separate top-level block
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  # Optional: Service Connect (remove if not needed)
  enable_execute_command = true
  
  depends_on = [
    module.iot_application_load_balancer,
    aws_ecs_task_definition.iot_api
  ]

  tags = {
    Name        = "${var.project_name}-iot-api-service"
    Environment = var.environment_tags.trusted
    Service     = "iot-api"
  }
}

# IoT Dashboard Service
resource "aws_ecs_service" "iot_dashboard" {
  provider        = aws.primary
  name            = "${var.project_name}-iot-dashboard-service"
  cluster         = module.iot_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.iot_dashboard.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_iot.private_subnets_by_name["ecs"].id]
    security_groups = [aws_security_group.ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.iot_application_load_balancer.target_group_arns["iot_dashboard"]
    container_name   = "iot-dashboard"
    container_port   = 3000
  }
  
  # CORRECT: deployment_controller block (not deployment_configuration)
  deployment_controller {
    type = "ECS"
  }
  
  # CORRECT: deployment_circuit_breaker is a separate top-level block
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  
  # Optional: Service Connect (remove if not needed)
  enable_execute_command = true
  
  depends_on = [
    module.iot_application_load_balancer,
    aws_ecs_task_definition.iot_dashboard
  ]

  tags = {
    Name        = "${var.project_name}-iot-dashboard-service"
    Environment = var.environment_tags.trusted
    Service     = "iot-dashboard"
  }
}

################################################################################
# Service Auto Scaling
################################################################################

# Auto Scaling Target for IoT API
resource "aws_appautoscaling_target" "iot_api" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${module.iot_ecs_cluster.cluster_name}/${aws_ecs_service.iot_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for IoT API (CPU-based)
resource "aws_appautoscaling_policy" "iot_api_cpu" {
  name               = "${var.project_name}-iot-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.iot_api.resource_id
  scalable_dimension = aws_appautoscaling_target.iot_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.iot_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for IoT Dashboard
resource "aws_appautoscaling_target" "iot_dashboard" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${module.iot_ecs_cluster.cluster_name}/${aws_ecs_service.iot_dashboard.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for IoT Dashboard (CPU-based)
resource "aws_appautoscaling_policy" "iot_dashboard_cpu" {
  name               = "${var.project_name}-iot-dashboard-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.iot_dashboard.resource_id
  scalable_dimension = aws_appautoscaling_target.iot_dashboard.scalable_dimension
  service_namespace  = aws_appautoscaling_target.iot_dashboard.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

################################################################################
# CloudWatch Alarms for ECS Services
################################################################################

# IoT API Service CPU Alarm
resource "aws_cloudwatch_metric_alarm" "iot_api_cpu_high" {
  count               = var.enable_enhanced_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-iot-api-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS service CPU utilization"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.iot_api.name
    ClusterName = module.iot_ecs_cluster.cluster_name
  }

  tags = {
    Name        = "${var.project_name}-iot-api-cpu-alarm"
    Environment = var.environment_tags.trusted
  }
}

# IoT API Service Memory Alarm
resource "aws_cloudwatch_metric_alarm" "iot_api_memory_high" {
  count               = var.enable_enhanced_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-iot-api-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS service memory utilization"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.iot_api.name
    ClusterName = module.iot_ecs_cluster.cluster_name
  }

  tags = {
    Name        = "${var.project_name}-iot-api-memory-alarm"
    Environment = var.environment_tags.trusted
  }
}
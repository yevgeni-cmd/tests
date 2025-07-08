################################################################################
# ECS Task Definitions for Streaming Services
################################################################################

# Streaming API Service Task Definition
resource "aws_ecs_task_definition" "streaming_api" {
  provider                 = aws.primary
  family                   = "${var.project_name}-streaming-api"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.streaming_task_cpu
  memory                  = var.streaming_task_memory
  execution_role_arn      = module.streaming_ecs_cluster.execution_role_arn
  task_role_arn          = module.streaming_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "streaming-api"
      image = "${aws_ecr_repository.trusted_devops.repository_url}:streaming-api-latest"
      
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
      ]
      
      secrets = [
        {
          name      = "DB_HOST"
          valueFrom = "${module.streaming_rds_database.master_user_secret_arn}:endpoint::"
        },
        {
          name      = "DB_USERNAME"
          valueFrom = "${module.streaming_rds_database.master_user_secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${module.streaming_rds_database.master_user_secret_arn}:password::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${module.streaming_rds_database.master_user_secret_arn}:dbname::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.streaming_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "streaming-api"
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
    Name        = "${var.project_name}-streaming-api-task"
    Environment = var.environment_tags.trusted
    Service     = "streaming-api"
  }
}

# Streaming Control Panel Task Definition
resource "aws_ecs_task_definition" "streaming_control" {
  provider                 = aws.primary
  family                   = "${var.project_name}-streaming-control"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.streaming_task_cpu
  memory                  = var.streaming_task_memory
  execution_role_arn      = module.streaming_ecs_cluster.execution_role_arn
  task_role_arn          = module.streaming_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "streaming-control"
      image = "${aws_ecr_repository.trusted_devops.repository_url}:streaming-control-latest"
      
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
          name  = "STREAMING_API_URL"
          value = "http://localhost:8080/api"
        },
        {
          name  = "PLAYER_BASE_URL"
          value = "http://localhost:8090"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.streaming_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "streaming-control"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:3000/control/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-streaming-control-task"
    Environment = var.environment_tags.trusted
    Service     = "streaming-control"
  }
}

# Video Player/Streaming Engine Task Definition
resource "aws_ecs_task_definition" "streaming_player" {
  provider                 = aws.primary
  family                   = "${var.project_name}-streaming-player"
  network_mode            = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.streaming_player_cpu    # Higher CPU for video processing
  memory                  = var.streaming_player_memory # Higher memory for video processing
  execution_role_arn      = module.streaming_ecs_cluster.execution_role_arn
  task_role_arn          = module.streaming_ecs_cluster.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "streaming-player"
      image = "${aws_ecr_repository.trusted_devops.repository_url}:streaming-player-latest"
      
      essential = true
      
      portMappings = [
        {
          containerPort = 8090
          protocol      = "tcp"
        },
        {
          containerPort = 1935  # RTMP
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "HTTP_PORT"
          value = "8090"
        },
        {
          name  = "RTMP_PORT"
          value = "1935"
        },
        {
          name  = "VIDEO_PROCESSING_QUEUE_URL"
          value = module.streaming_video_queue.queue_url
        },
        {
          name  = "RESULTS_QUEUE_URL"
          value = module.streaming_transcoding_queue.queue_url
        }
      ]
      
      # Mount points for video storage (if using EFS)
      mountPoints = []
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = module.streaming_ecs_cluster.log_group_name
          "awslogs-region"        = var.primary_region
          "awslogs-stream-prefix" = "streaming-player"
        }
      }
      
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:8090/player/health || exit 1"
        ]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 120  # Longer startup time for video processing
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-streaming-player-task"
    Environment = var.environment_tags.trusted
    Service     = "streaming-player"
  }
}

################################################################################
# ECS Services for Streaming Platform
################################################################################

# Streaming API Service
resource "aws_ecs_service" "streaming_api" {
  provider        = aws.primary
  name            = "${var.project_name}-streaming-api-service"
  cluster         = module.streaming_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.streaming_api.arn
  desired_count   = var.streaming_desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_streaming.private_subnets_by_name["ecs-containers"].id]
    security_groups = [aws_security_group.streaming_ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.streaming_application_load_balancer.target_group_arns["streaming_api"]
    container_name   = "streaming-api"
    container_port   = 8080
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
    aws_ecs_task_definition.streaming_api
  ]

  tags = {
    Name        = "${var.project_name}-streaming-api-service"
    Environment = var.environment_tags.trusted
    Service     = "streaming-api"
  }
}

# Streaming Control Service
resource "aws_ecs_service" "streaming_control" {
  provider        = aws.primary
  name            = "${var.project_name}-streaming-control-service"
  cluster         = module.streaming_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.streaming_control.arn
  desired_count   = var.streaming_desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_streaming.private_subnets_by_name["ecs-containers"].id]
    security_groups = [aws_security_group.streaming_ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.streaming_application_load_balancer.target_group_arns["streaming_control"]
    container_name   = "streaming-control"
    container_port   = 3000
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
    aws_ecs_task_definition.streaming_control
  ]

  tags = {
    Name        = "${var.project_name}-streaming-control-service"
    Environment = var.environment_tags.trusted
    Service     = "streaming-control"
  }
}

# Streaming Player Service
resource "aws_ecs_service" "streaming_player" {
  provider        = aws.primary
  name            = "${var.project_name}-streaming-player-service"
  cluster         = module.streaming_ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.streaming_player.arn
  desired_count   = var.streaming_player_desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  
  network_configuration {
    subnets         = [module.trusted_vpc_streaming.private_subnets_by_name["ecs-containers"].id]
    security_groups = [aws_security_group.streaming_ecs_services_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = module.streaming_application_load_balancer.target_group_arns["streaming_player"]
    container_name   = "streaming-player"
    container_port   = 8090
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
    aws_ecs_task_definition.streaming_player
  ]

  tags = {
    Name        = "${var.project_name}-streaming-player-service"
    Environment = var.environment_tags.trusted
    Service     = "streaming-player"
  }
}

################################################################################
# Service Auto Scaling for Streaming Services
################################################################################

# Auto Scaling Target for Streaming API
resource "aws_appautoscaling_target" "streaming_api" {
  max_capacity       = 20
  min_capacity       = 2
  resource_id        = "service/${module.streaming_ecs_cluster.cluster_name}/${aws_ecs_service.streaming_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for Streaming API (CPU-based)
resource "aws_appautoscaling_policy" "streaming_api_cpu" {
  name               = "${var.project_name}-streaming-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_api.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60.0  # Lower threshold for streaming services
  }
}

# Auto Scaling Policy for Streaming API (Memory-based)
resource "aws_appautoscaling_policy" "streaming_api_memory" {
  name               = "${var.project_name}-streaming-api-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_api.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for Streaming Control
resource "aws_appautoscaling_target" "streaming_control" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${module.streaming_ecs_cluster.cluster_name}/${aws_ecs_service.streaming_control.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for Streaming Control
resource "aws_appautoscaling_policy" "streaming_control_cpu" {
  name               = "${var.project_name}-streaming-control-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_control.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_control.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_control.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for Streaming Player
resource "aws_appautoscaling_target" "streaming_player" {
  max_capacity       = 15
  min_capacity       = 2  # Always keep at least 2 for HA
  resource_id        = "service/${module.streaming_ecs_cluster.cluster_name}/${aws_ecs_service.streaming_player.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy for Streaming Player (CPU-based)
resource "aws_appautoscaling_policy" "streaming_player_cpu" {
  name               = "${var.project_name}-streaming-player-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_player.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_player.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_player.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 50.0  # Lower threshold for video processing
  }
}

# Auto Scaling Policy for Streaming Player (Memory-based)
resource "aws_appautoscaling_policy" "streaming_player_memory" {
  name               = "${var.project_name}-streaming-player-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.streaming_player.resource_id
  scalable_dimension = aws_appautoscaling_target.streaming_player.scalable_dimension
  service_namespace  = aws_appautoscaling_target.streaming_player.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 60.0  # Lower threshold for video processing
  }
}

################################################################################
# CloudWatch Alarms for Streaming Services
################################################################################

# Streaming API Service Alarms
resource "aws_cloudwatch_metric_alarm" "streaming_api_cpu_high" {
  count               = var.enable_enhanced_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-streaming-api-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Streaming API service CPU utilization is high"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.streaming_api.name
    ClusterName = module.streaming_ecs_cluster.cluster_name
  }

  tags = {
    Name        = "${var.project_name}-streaming-api-cpu-alarm"
    Environment = var.environment_tags.trusted
  }
}

# Streaming Player Service Alarms
resource "aws_cloudwatch_metric_alarm" "streaming_player_cpu_high" {
  count               = var.enable_enhanced_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-streaming-player-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"  # Longer evaluation for video processing
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"  # Higher threshold for video processing
  alarm_description   = "Streaming player service CPU utilization is critically high"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    ServiceName = aws_ecs_service.streaming_player.name
    ClusterName = module.streaming_ecs_cluster.cluster_name
  }

  tags = {
    Name        = "${var.project_name}-streaming-player-cpu-alarm"
    Environment = var.environment_tags.trusted
  }
}

# Video Processing Queue Depth Alarm
resource "aws_cloudwatch_metric_alarm" "video_queue_depth" {
  count               = var.enable_enhanced_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-video-queue-depth-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"  # Alert when queue has more than 100 videos
  alarm_description   = "Video processing queue depth is high - may need more processing capacity"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    QueueName = module.streaming_video_queue.queue_name
  }

  tags = {
    Name        = "${var.project_name}-video-queue-depth-alarm"
    Environment = var.environment_tags.trusted
  }
}

# ALB Target Health Alarm
resource "aws_cloudwatch_metric_alarm" "streaming_alb_unhealthy_targets" {
  count               = var.enable_enhanced_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-streaming-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Streaming ALB has unhealthy targets"
  alarm_actions       = var.sns_alarm_topic_arn != null ? [var.sns_alarm_topic_arn] : []

  dimensions = {
    LoadBalancer = module.streaming_application_load_balancer.alb_arn
  }

  tags = {
    Name        = "${var.project_name}-streaming-alb-unhealthy-alarm"
    Environment = var.environment_tags.trusted
  }
}
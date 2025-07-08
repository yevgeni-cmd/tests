# =================================================================
# ECR (Elastic Container Registry) Repositories
# Defines private Docker image repositories for each service
# =================================================================

# --- Untrusted Environment Repository ---

resource "aws_ecr_repository" "untrusted_devops" {
  name                 = "${var.project_name}/untrusted-devops-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment_tags.untrusted
    Project     = var.project_name
    Purpose     = "DevOps CI/CD Images"
  }
}

# --- Trusted Environment Repository ---

resource "aws_ecr_repository" "trusted_devops" {
  name                 = "${var.project_name}/trusted-devops-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment_tags.trusted
    Project     = var.project_name
    Purpose     = "DevOps CI/CD Images"
  }
}

# =================================================================
# ECR Repository Policies
# Grants proper access for CI/CD and deployment workflows
# =================================================================

# --- Untrusted DevOps Repository Policy ---
data "aws_iam_policy_document" "untrusted_devops_policy" {
  # Allow untrusted DevOps host (primary CI/CD)
  statement {
    sid    = "AllowUntrustedDevOpsHost"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.untrusted_devops_host.iam_role_arn]
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }
  
  # Allow untrusted application hosts (for running containers)
  statement {
    sid    = "AllowUntrustedAppHosts"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [
        module.untrusted_ingress_host.iam_role_arn,
        module.untrusted_scrub_host.iam_role_arn
      ]
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

resource "aws_ecr_repository_policy" "untrusted_devops" {
  repository = aws_ecr_repository.untrusted_devops.name
  policy     = data.aws_iam_policy_document.untrusted_devops_policy.json
}

# --- Trusted DevOps Repository Policy ---
data "aws_iam_policy_document" "trusted_devops_policy" {
  # Allow trusted DevOps host (CI/CD and deployment)
  statement {
    sid    = "AllowTrustedDevOpsHost"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.trusted_devops_host.iam_role_arn]
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }
  
  # Allow trusted application hosts (for running containers)
  statement {
    sid    = "AllowTrustedAppHosts"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [
        module.trusted_scrub_host.iam_role_arn,
        module.trusted_streaming_host.iam_role_arn
      ]
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

resource "aws_ecr_repository_policy" "trusted_devops" {
  repository = aws_ecr_repository.trusted_devops.name
  policy     = data.aws_iam_policy_document.trusted_devops_policy.json
}

# =================================================================
# IAM ROLE POLICIES FOR EC2 INSTANCES (ALL ECR ACCESS)
# These attach to the IAM roles created by the EC2 modules
# =================================================================

# --- UNTRUSTED ENVIRONMENT ECR ACCESS ---

# Enhanced ECR access for untrusted DevOps host
resource "aws_iam_role_policy" "untrusted_devops_ecr_access" {
  name = "enhanced-ecr-access"
  role = split("/", module.untrusted_devops_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        # REVERTED: This role can ONLY access the untrusted repository.
        Resource = [
          aws_ecr_repository.untrusted_devops.arn
        ]
      }
    ]
  })

  depends_on = [module.untrusted_devops_host]
}

# ECR access for untrusted ingress host
resource "aws_iam_role_policy" "untrusted_ingress_ecr_access" {
  name = "ingress-ecr-access"
  role = split("/", module.untrusted_ingress_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [
          aws_ecr_repository.untrusted_devops.arn
        ]
      }
    ]
  })

  depends_on = [module.untrusted_ingress_host]
}

# ECR access for untrusted scrub host
resource "aws_iam_role_policy" "untrusted_scrub_ecr_access" {
  name = "scrub-ecr-access"
  role = split("/", module.untrusted_scrub_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [
          aws_ecr_repository.untrusted_devops.arn
        ]
      }
    ]
  })

  depends_on = [module.untrusted_scrub_host]
}

# --- TRUSTED ENVIRONMENT ECR ACCESS ---

# Enhanced ECR access for trusted DevOps host
resource "aws_iam_role_policy" "trusted_devops_ecr_access" {
  name = "enhanced-ecr-access"
  role = split("/", module.trusted_devops_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          aws_ecr_repository.trusted_devops.arn
        ]
      }
    ]
  })

  depends_on = [module.trusted_devops_host]
}

# ECR access for trusted scrub host
resource "aws_iam_role_policy" "trusted_scrub_ecr_access" {
  name = "scrub-ecr-access"
  role = split("/", module.trusted_scrub_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [
          aws_ecr_repository.trusted_devops.arn
        ]
      }
    ]
  })

  depends_on = [module.trusted_scrub_host]
}

# ECR access for trusted streaming host
resource "aws_iam_role_policy" "trusted_streaming_ecr_access" {
  name = "streaming-ecr-access"
  role = split("/", module.trusted_streaming_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = [
          aws_ecr_repository.trusted_devops.arn
        ]
      }
    ]
  })

  depends_on = [module.trusted_streaming_host]
}

# Enhanced ECS permissions for trusted DevOps host (to manage ECS)
resource "aws_iam_role_policy" "trusted_devops_ecs_management" {
  name = "ecs-management-access"
  role = split("/", module.trusted_devops_host.iam_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:*",
          "application-autoscaling:*",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          module.iot_ecs_cluster.execution_role_arn,
          module.iot_ecs_cluster.task_role_arn
        ]
      }
    ]
  })

  depends_on = [module.trusted_devops_host, module.iot_ecs_cluster]
}
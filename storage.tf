################################################################################
# Storage & Container Registry - S3 Buckets and ECR Repositories
################################################################################

# --- ECR Repositories ---

# ECR Repository for Untrusted DevOps images
module "untrusted_ecr" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/untrusted-devops-images"
}

# ECR Repository for Trusted DevOps images
module "trusted_ecr_devops" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/trusted-devops-images"
}

# ECR Repository for Trusted Streaming images
module "trusted_ecr_streaming" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/trusted-streaming-images"
}

# ECR Repository for Trusted IoT ECS services
module "trusted_ecr_iot" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/trusted-iot-services"
}

# --- S3 Buckets ---

# S3 Bucket for Untrusted Ingress Data
module "untrusted_s3_ingress" {
  source      = "./modules/s3_bucket"
  providers   = { aws = aws.primary }
  bucket_name = "${var.project_name}-untrusted-ingress-data-${data.aws_caller_identity.current.account_id}"
}

# S3 Bucket for Trusted Environment - General Application Data
module "trusted_s3_app" {
  source      = "./modules/s3_bucket"
  providers   = { aws = aws.primary }
  bucket_name = "${var.project_name}-trusted-app-data-${data.aws_caller_identity.current.account_id}"
}

# S3 Bucket for Trusted Streaming Data (VOD Platform)
module "trusted_s3_streaming" {
  source      = "./modules/s3_bucket"
  providers   = { aws = aws.primary }
  bucket_name = "${var.project_name}-trusted-streaming-data-${data.aws_caller_identity.current.account_id}"
}

# S3 Bucket for Trusted IoT Management Data
module "trusted_s3_iot" {
  source      = "./modules/s3_bucket"
  providers   = { aws = aws.primary }
  bucket_name = "${var.project_name}-trusted-iot-data-${data.aws_caller_identity.current.account_id}"
}

# ECR Policy for Untrusted Environment - Only untrusted instances can access
resource "aws_ecr_repository_policy" "untrusted_policy" {
  repository = module.untrusted_ecr.repository_url
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowUntrustedInstancesOnly"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-untrusted-*"
          ]
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# ECR Policy for Trusted DevOps - Only trusted instances can access
resource "aws_ecr_repository_policy" "trusted_devops_policy" {
  repository = module.trusted_ecr_devops.repository_url
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTrustedInstancesOnly"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-trusted-*"
          ]
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# ECR Policy for Trusted Streaming - Only trusted instances can access
resource "aws_ecr_repository_policy" "trusted_streaming_policy" {
  repository = module.trusted_ecr_streaming.repository_url
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTrustedInstancesOnly"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-trusted-*"
          ]
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# ECR Policy for Trusted IoT - Only trusted instances can access
resource "aws_ecr_repository_policy" "trusted_iot_policy" {
  repository = module.trusted_ecr_iot.repository_url
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTrustedInstancesOnly"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-trusted-*"
          ]
        }
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}
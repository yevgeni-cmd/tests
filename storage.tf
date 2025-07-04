# =================================================================
# ECR (Elastic Container Registry) Repositories
# Defines private Docker image repositories for each service
# =================================================================

# --- Untrusted Environment Repositories ---

resource "aws_ecr_repository" "untrusted_images" {
  name                 = "poc/untrusted-devops-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "Untrusted"
    Project     = "PoC"
  }
}

# --- Trusted Environment Repositories ---

resource "aws_ecr_repository" "trusted_devops_images" {
  name                 = "poc/trusted-devops-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "Trusted"
    Project     = "PoC"
  }
}

resource "aws_ecr_repository" "trusted_streaming_images" {
  name                 = "poc/trusted-streaming-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "Trusted"
    Project     = "PoC"
  }
}

resource "aws_ecr_repository" "trusted_iot_images" {
  name                 = "poc/trusted-iot-services"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "Trusted"
    Project     = "PoC"
  }
}


# =================================================================
# ECR Repository Policies
# Grants specific IAM roles access to push/pull images
# =================================================================

# --- FIXED: Untrusted DevOps Policy ---
data "aws_iam_policy_document" "untrusted_policy_doc" {
  statement {
    sid    = "AllowDevOpsHost"
    effect = "Allow"
    principals {
      type        = "AWS"
      # FIXED: This now correctly references the 'iam_role_arn' output
      # that you are adding to the ec2_instance module.
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
}

resource "aws_ecr_repository_policy" "untrusted_policy" {
  repository = aws_ecr_repository.untrusted_images.name
  policy     = data.aws_iam_policy_document.untrusted_policy_doc.json
}


# --- FIXED: Trusted DevOps Policy ---
data "aws_iam_policy_document" "trusted_devops_policy_doc" {
  statement {
    sid    = "AllowDevOpsHost"
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
}

resource "aws_ecr_repository_policy" "trusted_devops_policy" {
  repository = aws_ecr_repository.trusted_devops_images.name
  policy     = data.aws_iam_policy_document.trusted_devops_policy_doc.json
}


# --- FIXED: Trusted Streaming Policy ---
data "aws_iam_policy_document" "trusted_streaming_policy_doc" {
  statement {
    sid    = "AllowStreamingHost"
    effect = "Allow"
    principals {
      type        = "AWS"
      # Granting access to the trusted devops host to deploy to streaming
      identifiers = [module.trusted_devops_host.iam_role_arn]
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

resource "aws_ecr_repository_policy" "trusted_streaming_policy" {
  repository = aws_ecr_repository.trusted_streaming_images.name
  policy     = data.aws_iam_policy_document.trusted_streaming_policy_doc.json
}


# --- FIXED: Trusted IoT Policy ---
data "aws_iam_policy_document" "trusted_iot_policy_doc" {
  statement {
    sid    = "AllowIoTHost"
    effect = "Allow"
    principals {
      type        = "AWS"
      # Granting access to the trusted devops host to deploy to IoT
      identifiers = [module.trusted_devops_host.iam_role_arn]
    }
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

resource "aws_ecr_repository_policy" "trusted_iot_policy" {
  repository = aws_ecr_repository.trusted_iot_images.name
  policy     = data.aws_iam_policy_document.trusted_iot_policy_doc.json
}

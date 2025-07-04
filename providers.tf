terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias   = "primary"
  profile = var.aws_profile
  region  = var.primary_region
}

provider "aws" {
  alias   = "remote"
  profile = var.aws_profile
  region  = var.remote_region
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}



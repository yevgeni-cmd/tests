terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary AWS Provider with your profile
provider "aws" {
  alias   = "primary"
  region  = "il-central-1"
  profile = "728951503198_SystemAdministrator-8H"
}

# Default provider (same as primary)
provider "aws" {
  region  = "il-central-1"
  profile = "728951503198_SystemAdministrator-8H"
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}
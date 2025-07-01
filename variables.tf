################################################################################
# Core Configuration Variables
################################################################################

variable "aws_profile" {
  description = "The AWS CLI profile to use for authentication."
  type        = string
}

variable "project_name" {
  description = "A name for the project to prefix resources."
  type        = string
  default     = "final-arch"
}

variable "primary_region" {
  description = "The main AWS region where most resources will be deployed."
  type        = string
  default     = "il-central-1"
}

variable "remote_region" {
  description = "The secondary region for the remote IoT VPC."
  type        = string
  default     = "eu-west-1"
}

################################################################################
# Transit Gateway Variables
################################################################################

variable "trusted_asn" {
  description = "Private ASN for the trusted Transit Gateway."
  type        = number
  default     = 64512
}

variable "untrusted_asn" {
  description = "Private ASN for the untrusted Transit Gateway."
  type        = number
  default     = 64513
}

variable "remote_asn" {
  description = "Private ASN for the remote IoT Transit Gateway."
  type        = number
  default     = 64514
}

################################################################################
# VPC CIDR Block Variables
################################################################################

variable "untrusted_il_summary_routes" {
  description = "A map of valid summary routes for the untrusted IL environment."
  type        = map(string)
  default = {
    main = "172.17.16.0/20"
  }
}

variable "trusted_vpc_cidrs" {
  description = "A map of CIDR blocks for all VPCs in the trusted environment."
  type        = map(string)
  default = {
    "jacob_api_gw"    = "172.16.10.0/24"
    "iot_management"  = "172.16.11.0/24"
    "streaming"       = "172.16.12.0/24"
    "streaming_scrub" = "172.16.13.0/24"
    "devops"          = "172.16.14.0/24"
  }
}

variable "untrusted_vpc_cidrs" {
  description = "A map of CIDR blocks for all VPCs in the untrusted environment."
  type        = map(string)
  default = {
    "streaming_ingress" = "172.17.21.0/24"
    "streaming_scrub"   = "172.17.22.0/24"
    "iot_management"    = "172.17.23.0/24"
    "devops"            = "172.17.24.0/24"
  }
}

variable "remote_vpc_cidrs" {
  description = "A map of CIDR blocks for VPCs in the remote region."
  type        = map(string)
  default = {
    "iot_core" = "172.18.30.0/24"
  }
}

################################################################################
# Client VPN Variables
################################################################################

variable "vpn_authentication_type" {
  description = "The authentication method for the VPN. Can be 'certificate' or 'saml'."
  type        = string
  default     = "certificate"
  validation {
    condition     = contains(["certificate", "saml"], var.vpn_authentication_type)
    error_message = "Valid values for authentication_type are 'certificate' or 'saml'."
  }
}

variable "trusted_vpn_server_cert_arn" {
  description = "The ARN of an existing ACM certificate for the trusted Client VPN server."
  type        = string
}

variable "untrusted_vpn_server_cert_arn" {
  description = "The ARN of an existing ACM certificate for the untrusted Client VPN server."
  type        = string
}

variable "saml_identity_provider_arn" {
  description = "The ARN of the SAML 2.0 Identity Provider for MFA. Required if authentication_type is 'saml'."
  type        = string
  default     = null
}

variable "trusted_vpn_client_cidr" {
  description = "The CIDR block for clients connecting to the trusted VPN."
  type        = string
  default     = "172.30.0.0/22"
}

variable "untrusted_vpn_client_cidr" {
  description = "The CIDR block for clients connecting to the untrusted VPN."
  type        = string
  default     = "172.31.0.0/22"
}

################################################################################
# EC2 Instance Variables
################################################################################

variable "trusted_ssh_key_name" {
  description = "The name of the EC2 Key Pair for instances in the TRUSTED environment."
  type        = string
}

variable "untrusted_ssh_key_name" {
  description = "The name of the EC2 Key Pair for instances in the UNTRUSTED environment."
  type        = string
}

variable "instance_os" {
  description = "The operating system for the EC2 instances. Valid options: 'amazon', 'ubuntu'."
  type        = string
  default     = "amazon"
}

variable "default_instance_type" {
  description = "The default EC2 instance type to use for all servers."
  type        = string
  default     = "t3.micro"
}

variable "srt_udp_ports" {
  description = "A list of UDP ports to open for SRT ingress."
  type        = list(number)
  default     = [8090]
}

################################################################################
# Custom AMI Variables
################################################################################

variable "custom_ami_id" {
  description = "Default custom AMI ID with Docker and tools pre-installed. Used as fallback when specific environment AMIs are not provided."
  type        = string
  default     = null
}

variable "trusted_custom_ami_id" {
  description = "Custom AMI ID for trusted environment instances (standard AMI with Docker and tools)."
  type        = string
  default     = null
}

variable "untrusted_custom_ami_id" {
  description = "Custom AMI ID for untrusted environment instances (standard AMI with Docker and tools)."
  type        = string
  default     = null
}

variable "gpu_custom_ami_id" {
  description = "GPU-enabled custom AMI ID specifically for streaming host. Only used when streaming_host_use_gpu=true. Includes NVIDIA drivers and GPU-optimized Docker."
  type        = string
  default     = null
}

################################################################################
# Instance Type and GPU Variables
################################################################################

variable "gpu_instance_type" {
  description = "GPU instance type for trusted streaming host when GPU is enabled."
  type        = string
  default     = "g4dn.xlarge"
  validation {
    condition = contains([
      "g4dn.large", "g4dn.xlarge", "g4dn.2xlarge", "g4dn.4xlarge",
      "g5.large", "g5.xlarge", "g5.2xlarge", "g5.4xlarge"
    ], var.gpu_instance_type)
    error_message = "GPU instance type must be a valid GPU-enabled instance type (g4dn.* or g5.*)."
  }
}

variable "streaming_host_use_gpu" {
  description = "Whether to use GPU instance type and GPU-enabled AMI for trusted streaming host. Enables hardware-accelerated video processing."
  type        = bool
  default     = false
}
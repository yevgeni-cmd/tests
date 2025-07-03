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
# Custom AMI Configuration
################################################################################

# ADDED: Custom AMI variables
variable "custom_standard_ami_id" {
  description = "Custom AMI ID with Docker for standard instances (untrusted hosts, trusted non-GPU hosts)."
  type        = string
  default     = "ami-0ea2fce7f7afb4f4c"
}

variable "custom_gpu_ami_id" {
  description = "Custom AMI ID with Docker and GPU support for GPU instances (trusted streaming host - future use)."
  type        = string
  default     = null # Will be added when GPU AMI is ready
}

variable "use_custom_amis" {
  description = "Whether to use custom AMIs instead of default Ubuntu/Amazon Linux AMIs."
  type        = bool
  default     = true
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
    main = "172.19.16.0/20"
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
    "streaming_ingress" = "172.19.21.0/24"
    "streaming_scrub"   = "172.19.22.0/24"
    "iot_management"    = "172.19.23.0/24"
    "devops"            = "172.19.24.0/24"
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
  default     = "ubuntu"
}

variable "srt_udp_ports" {
  description = "A list of UDP ports to open for SRT ingress."
  type        = list(number)
  default     = [8890]
}

variable "peering_udp_port_range" {
  description = "UDP port range for traffic forwarding between untrusted and trusted scrub hosts"
  type = object({
    from = number
    to   = number
  })
  default = {
    from = 50000
    to   = 51000
  }
}

# Instance type configurations by role
variable "instance_types" {
  description = "Instance types for different server roles"
  type = object({
    # Untrusted environment
    untrusted_ingress    = string  # Needs more CPU/bandwidth for streaming ingress
    untrusted_scrub      = string  # Light forwarding only
    untrusted_devops     = string  # Development/management tasks
    
    # Trusted environment  
    trusted_scrub        = string  # Processing + containers
    trusted_streaming    = string  # Video streaming (GPU optional)
    trusted_devops       = string  # Development/management tasks
  })
  
  default = {
    # Untrusted environment
    untrusted_ingress    = "c5.large"    # 2 vCPU, 4GB RAM - good for network I/O
    untrusted_scrub      = "t3.micro"    # 2 vCPU, 1GB RAM - minimal for forwarding
    untrusted_devops     = "t3.medium"   # 2 vCPU, 4GB RAM - development work
    
    # Trusted environment
    trusted_scrub        = "c5.large"    # 2 vCPU, 4GB RAM - container processing
    trusted_streaming    = "c5.large"    # 2 vCPU, 4GB RAM - default (GPU optional)
    trusted_devops       = "t3.medium"   # 2 vCPU, 4GB RAM - development work
  }
}

# GPU-specific configuration
variable "use_gpu_for_streaming" {
  description = "Whether to use GPU instance for trusted streaming host"
  type        = bool
  default     = false
}

variable "gpu_instance_type" {
  description = "GPU instance type for streaming when use_gpu_for_streaming is true"
  type        = string
  default     = "g5.xlarge"
}

# Keep this for backward compatibility (deprecated)
variable "default_instance_type" {
  description = "Default EC2 instance type (deprecated - use instance_types instead)"
  type        = string
  default     = "t3.small"
}

# Azure DevOps Agent Configuration
variable "enable_ado_agents" {
  description = "Whether to install Azure DevOps agents on DevOps hosts"
  type        = bool
  default     = false
}

variable "ado_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/yourorg)"
  type        = string
  default     = ""
}

variable "ado_agent_pool_name" {
  description = "Azure DevOps agent pool name"
  type        = string
  default     = "Default"
}

variable "ado_pat_secret_name" {
  description = "AWS Secrets Manager secret name containing ADO Personal Access Token"
  type        = string
  default     = ""
}

# Deployment configuration
variable "enable_auto_deployment" {
  description = "Whether to enable auto-deployment capabilities from ADO agents"
  type        = bool
  default     = false
}

variable "deployment_ssh_key_secret_name" {
  description = "AWS Secrets Manager secret name containing SSH private key for deployments"
  type        = string
  default     = ""
}
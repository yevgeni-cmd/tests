variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "instance_os" {
  description = "Operating system for the instance (e.g., 'amazon', 'ubuntu')"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the instance"
  type        = string
}

variable "enable_ecr_access" {
  description = "Whether to attach ECR read-only policy"
  type        = bool
  default     = false
}

variable "enable_ec2_describe" {
  description = "Whether to allow EC2 describe permissions"
  type        = bool
  default     = false
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address"
  type        = bool
  default     = false
}

variable "custom_ami_id" {
  description = "Custom AMI ID to use (if null, use default AMI)"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script for the instance"
  type        = string
  default     = ""
}

variable "allowed_udp_ports" {
  description = "List of UDP ports to allow ingress"
  type        = list(number)
  default     = []
}

variable "allowed_udp_cidrs" {
  description = "List of CIDR blocks for UDP ingress"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "allowed_egress_udp_ports" {
  description = "List of UDP ports to allow egress"
  type        = list(number)
  default     = []
}

variable "allowed_egress_udp_cidrs" {
  description = "List of CIDR blocks for UDP egress"
  type        = list(string)
  default     = []
}

variable "ami_owners" {
  description = "AMI owners for default AMIs"
  type        = map(string)
  default = {
    amazon = "amazon"
    ubuntu = "099720109477" # Canonical
  }
}

variable "ami_filters" {
  description = "AMI name filters for default AMIs"
  type        = map(string)
  default = {
    amazon = "amzn2-ami-hvm-*-x86_64-gp2"
    ubuntu = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
  }
}
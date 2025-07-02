variable "instance_name" {
  description = "The name for the EC2 instance and related resources."
  type        = string
}

variable "instance_os" {
  description = "The operating system for the EC2 instance. Valid options: 'amazon', 'ubuntu'."
  type        = string
  default     = "amazon"
}

variable "instance_type" {
  description = "The EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "The name of the EC2 Key Pair to associate with the instance."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet to launch the instance in."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC the instance belongs to."
  type        = string
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance."
  type        = bool
  default     = false
}

variable "enable_ecr_access" {
  description = "If true, attaches a policy allowing read-only access to ECR."
  type        = bool
  default     = false
}

# ADDED: Support for EC2 describe permissions (needed for dynamic IP discovery)
variable "enable_ec2_describe" {
  description = "If true, attaches a policy allowing EC2 describe permissions for dynamic IP discovery."
  type        = bool
  default     = false
}

variable "allowed_udp_ports" {
  description = "A list of UDP ports to allow ingress traffic from the internet."
  type        = list(number)
  default     = []
}

variable "allowed_ssh_cidrs" {
  description = "A list of CIDR blocks to allow SSH ingress traffic from."
  type        = list(string)
  default     = []
}

variable "allowed_ingress_cidrs" {
  description = "A list of CIDR blocks to allow all ingress traffic from."
  type        = list(string)
  default     = []
}

# ADDED: Custom AMI support
variable "custom_ami_id" {
  description = "Custom AMI ID to use instead of the default AMI filters. If null, uses ami_filters."
  type        = string
  default     = null
}

# ADDED: User data support
variable "user_data" {
  description = "User data script to run on instance launch."
  type        = string
  default     = null
}

variable "ami_filters" {
  description = "A map of AMI filters for different operating systems."
  type        = map(string)
  default = {
    amazon = "amzn2-ami-hvm-*-x86_64-gp2"
    ubuntu = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  }
}

variable "ami_owners" {
  description = "A map of AMI owners for different operating systems."
  type        = map(string)
  default = {
    amazon = "amazon"
    ubuntu = "099720109477" # Canonical's AWS account ID
  }
}
variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "The CIDR block must be a valid IPv4 CIDR."
  }
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "public_subnet_names" {
  description = "List of public subnet names"
  type        = list(string)
  default     = []
}

variable "private_subnet_names" {
  description = "List of private subnet names"
  type        = list(string)
  default     = []
}

variable "create_igw" {
  description = "Whether to create an Internet Gateway"
  type        = bool
  default     = false
}

variable "create_nat_gateway" {
  description = "Whether to create a NAT Gateway"
  type        = bool
  default     = false
}

variable "tgw_id" {
  description = "Transit Gateway ID for attachment"
  type        = string
  default     = null
}

variable "vpc_endpoints" {
  description = "List of VPC endpoints to create"
  type        = list(string)
  default     = []
}

variable "create_custom_dns" {
  description = "Whether to create custom Route53 records for VPC endpoints"
  type        = bool
  default     = false
}
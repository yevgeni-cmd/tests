variable "name" {
  description = "The name of the VPC and a prefix for its resources."
  type        = string
}

variable "cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "A list of Availability Zones to use for the subnets."
  type        = list(string)
}

variable "subnets" {
  description = "A map of subnet configurations. Key is the logical name. Value contains cidr_suffix and type ('public' or 'private')."
  type        = map(object({
    cidr_suffix = number
    type        = string
    name        = string
    az          = optional(string)
  }))
}

variable "tgw_id" {
  description = "The ID of the Transit Gateway to attach this VPC to."
  type        = string
  default     = null
}

variable "tgw_routes" {
  description = "A map of routes to add to the VPC's route tables for TGW connectivity."
  type        = map(string)
  default     = {}
}

variable "create_igw" {
  description = "If true, an Internet Gateway will be created for this VPC."
  type        = bool
  default     = false
}

variable "create_nat_gateway" {
  description = "If true, a NAT Gateway will be created in a 'public' subnet."
  type        = bool
  default     = false
}

variable "vpc_endpoints" {
  description = "A list of AWS services to create VPC endpoints for (e.g., 's3', 'ecr.api')."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "The AWS region where the VPC is being created."
  type        = string
}

variable "manage_nacl" {
  description = "Flag to create and manage a Network ACL for the app subnet."
  type        = bool
  default     = false
}

variable "nacl_udp_ports" {
  description = "A list of UDP ports to allow in the Network ACL."
  type        = list(number)
  default     = []
}

variable "nacl_ssh_source_cidr" {
  description = "The source CIDR for SSH traffic in the NACL (typically the VPN client CIDR)."
  type        = string
  default     = null
}

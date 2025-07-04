variable "name_prefix" {
  description = "The name prefix for the Client VPN endpoint."
  type        = string
}

variable "client_cidr_block" {
  description = "The CIDR block for clients connecting to the VPN."
  type        = string
}

variable "server_certificate_arn" {
  description = "The ARN of the ACM server certificate."
  type        = string
}

variable "target_vpc_subnet_id" {
  description = "The ID of the subnet to associate the VPN with."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC to associate the VPN endpoint with."
  type        = string
}

variable "authorized_network_cidrs" {
  description = "A map of network CIDRs to authorize access to. Key is a description."
  type        = map(string)
  default     = {}
}

# ADDED: Separate variable for route creation to avoid duplicate routes
variable "route_network_cidrs" {
  description = "A map of network CIDRs to create routes for. Should exclude the associated VPC CIDR to avoid duplicates with AWS auto-created routes. Key is a description."
  type        = map(string)
  default     = {}
}

variable "authentication_type" {
  description = "The authentication method. Can be 'certificate' or 'saml'."
  type        = string
  default     = "certificate"
  validation {
    condition     = contains(["certificate", "saml"], var.authentication_type)
    error_message = "Valid values for authentication_type are 'certificate' or 'saml'."
  }
}

variable "saml_provider_arn" {
  description = "The ARN of the SAML 2.0 Identity Provider for MFA. Required if authentication_type is 'saml'."
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "A list of security group IDs to apply to the Client VPN endpoint."
  type        = list(string)
  default     = []
}

variable "dns_servers" {
  description = "A list of DNS server IPs to push to the client."
  type        = list(string)
  default     = []
}

variable "project_name" {
  description = "A name for the project to prefix resources."
  type        = string
  default     = "final-arch"
}
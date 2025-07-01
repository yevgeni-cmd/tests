variable "name_prefix" {
  description = "Name prefix for the Transit Gateway"
  type        = string
}

variable "description" {
  description = "Description for the Transit Gateway"
  type        = string
}

variable "asn" {
  description = "Private Autonomous System Number (ASN) for the Amazon side of a BGP session"
  type        = number
  default     = 64512
}
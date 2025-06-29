# modules/tgw/variables.tf

variable "name_prefix" {
  description = "Prefix for the TGW name tag."
  type        = string
}

variable "description" {
  description = "Description for the TGW."
  type        = string
}

variable "asn" {
  description = "Private Autonomous System Number (ASN) for the TGW."
  type        = number
}

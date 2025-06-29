terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_ec2_transit_gateway" "this" {
  description                 = var.description
  amazon_side_asn             = var.asn
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  tags = { Name = var.name_prefix }
}

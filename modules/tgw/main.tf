terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Transit Gateway - keep defaults enabled since they're already created
resource "aws_ec2_transit_gateway" "this" {
  description                     = var.description
  amazon_side_asn                = var.asn
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"   # Keep default behavior
  default_route_table_propagation = "enable"   # Keep default behavior

  tags = {
    Name = var.name_prefix
  }
}

# Data source to get the default route table that AWS creates
data "aws_ec2_transit_gateway_route_table" "default" {
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }
  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.this.id]
  }
}


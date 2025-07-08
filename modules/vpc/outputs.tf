output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = length(aws_internet_gateway.this) > 0 ? aws_internet_gateway.this[0].id : null
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = length(aws_nat_gateway.nat) > 0 ? aws_nat_gateway.nat[0].id : null
}

# Public Subnets
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnets_by_name" {
  description = "Map of public subnets by name"
  value = {
    # FIX: Iterate directly over the subnet resources to prevent index errors.
    # This assumes var.public_subnet_names has the same number of elements
    # and is in the same order as the created subnets.
    for i, subnet in aws_subnet.public : var.public_subnet_names[i] => {
      id         = subnet.id
      cidr_block = subnet.cidr_block
      az         = subnet.availability_zone
    }
  }
}

# Private Subnets
output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnets_by_name" {
  description = "Map of private subnets by name"
  value = {
    for i, subnet in aws_subnet.private : var.private_subnet_names[i] => {
      id         = subnet.id
      cidr_block = subnet.cidr_block
      az         = subnet.availability_zone
    }
  }
}

# Route Tables
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = length(aws_route_table.public) > 0 ? aws_route_table.public[0].id : null
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = length(aws_route_table.private) > 0 ? aws_route_table.private[0].id : null
}

# TGW Attachment
output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment"
  value       = length(aws_ec2_transit_gateway_vpc_attachment.this) > 0 ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

# VPC Endpoints
output "vpc_endpoint_gateway_ids" {
  description = "Map of Gateway VPC endpoint IDs by service name"
  value = {
    for k, v in aws_vpc_endpoint.gateway : k => v.id
  }
}

output "vpc_endpoint_interface_ids" {
  description = "Map of Interface VPC endpoint IDs by service name"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.id
  }
}

# Combined endpoint IDs for backward compatibility
output "vpc_endpoint_ids" {
  description = "Map of all VPC endpoint IDs by service name"
  value = merge(
    { for k, v in aws_vpc_endpoint.gateway : k => v.id },
    { for k, v in aws_vpc_endpoint.interface : k => v.id }
  )
}

# Security Groups
output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = length(aws_security_group.vpc_endpoints) > 0 ? aws_security_group.vpc_endpoints[0].id : null
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = aws_route_table.public[*].id
}
output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the created VPC."
  value       = aws_vpc.this.cidr_block
}

output "vpc_dns_server" {
  description = "The IP address of the VPC's default DNS server."
  value       = cidrhost(var.cidr, 2)
}

output "subnets" {
  description = "A map of the created subnets, with their IDs and other attributes."
  value       = aws_subnet.this
}

output "private_route_table_id" {
  description = "The ID of the private route table, if one was created."
  value       = length(aws_route_table.private) > 0 ? aws_route_table.private[0].id : null
}

output "public_route_table_id" {
  description = "The ID of the public route table, if one was created."
  value       = length(aws_route_table.public) > 0 ? aws_route_table.public[0].id : null
}

output "tgw_attachment_id" {
  description = "The ID of the TGW attachment, if one was created."
  value       = length(aws_ec2_transit_gateway_vpc_attachment.this) > 0 ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

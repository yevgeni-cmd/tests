output "tgw_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "tgw_default_route_table_id" {
  description = "ID of the default Transit Gateway route table"
  value       = data.aws_ec2_transit_gateway_route_table.default.id
}

# For backward compatibility
output "default_route_table_id" {
  description = "ID of the default Transit Gateway route table (alias)"
  value       = data.aws_ec2_transit_gateway_route_table.default.id
}

output "main_route_table_id" {
  description = "ID of the main Transit Gateway route table (alias)"
  value       = data.aws_ec2_transit_gateway_route_table.default.id
}
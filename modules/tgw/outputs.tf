output "tgw_id" {
  description = "The ID of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "tgw_arn" {
  description = "The ARN of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.arn
}

output "association_default_route_table_id" {
  description = "The ID of the default association route table."
  value       = aws_ec2_transit_gateway.this.association_default_route_table_id
}

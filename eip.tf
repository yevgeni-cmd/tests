# ================================================================
# Elastic IP Configuration for Untrusted Ingress Host
# This provides a static public IP that persists across instance replacements
# ================================================================

# Elastic IP for the untrusted ingress host
resource "aws_eip" "untrusted_ingress" {
  provider = aws.primary
  domain   = "vpc"
  
  tags = {
    Name        = "${var.project_name}-untrusted-ingress-eip"
    Environment = var.environment_tags.untrusted
    Purpose     = "Static IP for streaming ingress"
  }

  # Ensure the EIP is created after the VPC and IGW are ready
  depends_on = [
    module.untrusted_vpc_streaming_ingress
  ]
}

# Associate the EIP with the untrusted ingress host
resource "aws_eip_association" "untrusted_ingress" {
  provider    = aws.primary
  instance_id = module.untrusted_ingress_host.instance_id
  allocation_id = aws_eip.untrusted_ingress.id

  # Ensure the association happens after the instance is created
  depends_on = [
    module.untrusted_ingress_host,
    aws_eip.untrusted_ingress
  ]
}

# Output the static public IP for easy reference
output "untrusted_ingress_static_ip" {
  description = "Static public IP address for the untrusted ingress host"
  value       = aws_eip.untrusted_ingress.public_ip
}

output "untrusted_ingress_eip_allocation_id" {
  description = "Allocation ID of the EIP for the untrusted ingress host"
  value       = aws_eip.untrusted_ingress.id
}
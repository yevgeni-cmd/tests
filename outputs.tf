################################################################################
# Outputs - Instance IDs, IPs, and Network Information
################################################################################

# --- Instance IDs ---

output "untrusted_ingress_instance_id" {
  description = "Instance ID of the untrusted ingress host."
  value       = module.untrusted_ingress_host.instance_id
}

output "untrusted_scrub_instance_id" {
  description = "Instance ID of the untrusted scrub host."
  value       = module.untrusted_scrub_host.instance_id
}

output "untrusted_devops_instance_id" {
  description = "Instance ID of the untrusted DevOps agent."
  value       = module.untrusted_devops_agent.instance_id
}

output "trusted_scrub_instance_id" {
  description = "Instance ID of the trusted scrub host."
  value       = module.trusted_scrub_host.instance_id
}

output "trusted_devops_instance_id" {
  description = "Instance ID of the trusted DevOps agent."
  value       = module.trusted_devops_agent.instance_id
}

output "trusted_streaming_instance_id" {
  description = "Instance ID of the trusted streaming host."
  value       = module.trusted_streaming_host.instance_id
}

# --- IP Addresses ---

output "untrusted_instance_ips" {
  description = "Private IP addresses for untrusted instances."
  value = {
    ingress_host = module.untrusted_ingress_host.private_ip
    scrub_host   = module.untrusted_scrub_host.private_ip
    devops_agent = module.untrusted_devops_agent.private_ip
  }
}

output "trusted_instance_ips" {
  description = "Private IP addresses for trusted instances."
  value = {
    scrub_host     = module.trusted_scrub_host.private_ip
    streaming_host = module.trusted_streaming_host.private_ip
    devops_agent   = module.trusted_devops_agent.private_ip
  }
}

output "public_instance_ips" {
  description = "Public IP addresses for instances with internet access."
  value = {
    untrusted_ingress = module.untrusted_ingress_host.public_ip
    untrusted_devops  = module.untrusted_devops_agent.public_ip
    trusted_devops    = module.trusted_devops_agent.public_ip
  }
}

# --- VPC Information ---

output "untrusted_vpc_ids" {
  description = "VPC IDs for the untrusted environment."
  value = {
    devops            = module.untrusted_vpc_devops.vpc_id
    streaming_ingress = module.untrusted_vpc_streaming_ingress.vpc_id
    streaming_scrub   = module.untrusted_vpc_streaming_scrub.vpc_id
    iot_management    = module.untrusted_vpc_iot.vpc_id
  }
}

output "trusted_vpc_ids" {
  description = "VPC IDs for the trusted environment."
  value = {
    devops           = module.trusted_vpc_devops.vpc_id
    streaming_scrub  = module.trusted_vpc_streaming_scrub.vpc_id
    streaming        = module.trusted_vpc_streaming.vpc_id
    iot_management   = module.trusted_vpc_iot.vpc_id
    jacob_api_gw     = module.trusted_vpc_jacob.vpc_id
  }
}

# --- Security Group Information ---

output "untrusted_security_group_ids" {
  description = "Security Group IDs for the untrusted environment."
  value = {
    vpn_sg     = aws_security_group.untrusted_vpn_sg.id
    ingress_sg = aws_security_group.untrusted_ingress_sg.id
    scrub_sg   = aws_security_group.untrusted_scrub_sg.id
    agent_sg   = aws_security_group.untrusted_agent_sg.id
  }
}

output "trusted_security_group_ids" {
  description = "Security Group IDs for the trusted environment."
  value = {
    vpn_sg       = aws_security_group.trusted_vpn_sg.id
    scrub_sg     = aws_security_group.trusted_scrub_sg.id
    streaming_sg = aws_security_group.trusted_streaming_sg.id
    agent_sg     = aws_security_group.trusted_agent_sg.id
  }
}

# --- Network Infrastructure ---

output "untrusted_tgw_id" {
  description = "Transit Gateway ID for the untrusted environment."
  value       = module.untrusted_tgw.tgw_id
}

output "trusted_tgw_id" {
  description = "Transit Gateway ID for the trusted environment."
  value       = module.trusted_tgw.tgw_id
}

# FIXED: Uncommented VPC peering connection output
output "vpc_peering_connection_id" {
  description = "VPC Peering Connection ID between untrusted and trusted scrub."
  value       = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}

# --- VPN Information ---

output "untrusted_vpn_endpoint_id" {
  description = "Client VPN Endpoint ID for the untrusted environment."
  value       = module.untrusted_vpn.endpoint_id
}

output "trusted_vpn_endpoint_id" {
  description = "Client VPN Endpoint ID for the trusted environment."
  value       = module.trusted_vpn.endpoint_id
}
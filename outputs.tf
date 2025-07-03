# Untrusted Environment IPs
output "untrusted_instance_ips" {
  description = "IP addresses for untrusted instances"
  value = {
    ingress_public  = module.untrusted_ingress_host.public_ip
    ingress_private = module.untrusted_ingress_host.private_ip
    scrub_private   = module.untrusted_scrub_host.private_ip
    devops_public   = module.untrusted_devops_host.public_ip 
    devops_private  = module.untrusted_devops_host.private_ip
  }
}

# Trusted Environment IPs  
output "trusted_instance_ips" {
  description = "IP addresses for trusted instances"
  value = {
    scrub_private     = module.trusted_scrub_host.private_ip
    streaming_private = module.trusted_streaming_host.private_ip
    devops_public     = module.trusted_devops_host.public_ip
    devops_private    = module.trusted_devops_host.private_ip
  }
}

# Elastic IP for Untrusted Ingress (when you add it)
output "untrusted_ingress_elastic_ip" {
  description = "Static Elastic IP for untrusted ingress host"
  value       = aws_eip.untrusted_ingress_eip.public_ip
}
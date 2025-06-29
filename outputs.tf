output "trusted_vpn_endpoint_id" {
  description = "The ID of the Client VPN endpoint for the Trusted environment."
  value       = module.trusted_vpn.endpoint_id
}

output "untrusted_vpn_endpoint_id" {
  description = "The ID of the Client VPN endpoint for the Untrusted environment."
  value       = module.untrusted_vpn.endpoint_id
}

output "untrusted_ingress_server_public_ip" {
  description = "The public IP address of the Untrusted Streaming Ingress server."
  value       = module.untrusted_ingress_docker_host.public_ip
}

output "trusted_vpn_user_policy_arn" {
  description = "The ARN of the IAM policy for Trusted VPN users. Attach this to your SAML role."
  value       = module.trusted_vpn_user_policy.policy_arn
}

output "untrusted_vpn_user_policy_arn" {
  description = "The ARN of the IAM policy for Untrusted VPN users. Attach this to your SAML role."
  value       = module.untrusted_vpn_user_policy.policy_arn
}

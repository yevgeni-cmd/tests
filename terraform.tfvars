# ----------------------------------------------------------------
#                 Terraform Variables Configuration
# ----------------------------------------------------------------

# --- AWS Configuration ---
aws_profile = "728951503198_SystemAdministrator-8H"

# --- Project Configuration ---
project_name = "poc"
instance_os  = "ubuntu"

# --- SSH Key Configuration ---
trusted_ssh_key_name   = "sky-trusted"
untrusted_ssh_key_name = "sky-untrusted"

# --- VPN Configuration ---
trusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/e42ef4ec-db4c-4537-b16e-81d3c2c0b4e2"
untrusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/0c87fe07-ed4d-4810-b069-f6c6fe8c2f92"

# Use custom AMIs for EC2 instances
# Set to true to enable custom AMIs
# If false, default AMIs will be used based on the instance_os variable
use_custom_amis = false
# Custom AMI IDs (replace with your actual AMI IDs)
custom_standard_ami_id = "ami-0ea2fce7f7afb4f4c"

# Instance type configurations (customize as needed)
instance_types = {
  # Untrusted environment
  untrusted_ingress    = "c5.xlarge"   # Upgrade for high-bandwidth streaming ingress
  untrusted_scrub      = "t3.micro"    # Minimal - just traffic forwarding
  untrusted_devops     = "t3.medium"   # DevOps management
  
  # Trusted environment
  trusted_scrub        = "c5.large"    # Container processing workload
  trusted_streaming    = "c5.large"    # Default (will be overridden if GPU enabled)
  trusted_devops       = "t3.medium"   # DevOps management
}

# GPU configuration for streaming
use_gpu_for_streaming = true          # Set to true to enable GPU
gpu_instance_type     = "g5.xlarge"   # GPU instance type when enabled

# GPU-enabled custom AMI (create this after building GPU AMI)
custom_gpu_ami_id = "ami-0ea2fce7f7afb4f4c"  # Replace with your GPU AMI ID when available

# UDP ports for SRT streaming
srt_udp_ports = [8890]

# --- Optional: SAML/MFA Configuration ---
# vpn_authentication_type    = "saml"
# saml_identity_provider_arn = "arn:aws:iam::123456789012:saml-provider/YourIdPName"


# Azure DevOps Agent Configuration
enable_ado_agents      = false
ado_organization_url   = "https://dev.azure.com/cloudburstnet"
ado_agent_pool_name    = "Self-Hosted-AWS"
ado_pat_secret_name    = "poc-ado-pat"           

# Auto-deployment configuration
enable_auto_deployment         = false
deployment_ssh_key_secret_name = "poc-deployment-ssh-key"         # Will be created by Terraform

peering_udp_port = 50555

trusted_asn = 64512
untrusted_asn = 64513

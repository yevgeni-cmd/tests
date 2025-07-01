# ----------------------------------------------------------------
#                 Terraform Variables Configuration
#
# This file contains all the required variables for your infrastructure
# ----------------------------------------------------------------

# --- AWS Configuration ---
aws_profile = "728951503198_SystemAdministrator-8H"

# --- VPN Certificates ---
trusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/e42ef4ec-db4c-4537-b16e-81d3c2c0b4e2"
untrusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/0c87fe07-ed4d-4810-b069-f6c6fe8c2f92"

# --- Project Configuration ---
project_name = "poc"
instance_os = "ubuntu"

# --- SSH Key Names ---
trusted_ssh_key_name = "sky-trusted"
untrusted_ssh_key_name = "sky-untrusted"

# --- Custom AMI Configuration ---
# IMPORTANT: You MUST build these AMIs since trusted environment has no internet
# See GPU-AMI-BUILD-GUIDE.md for detailed build instructions

# TODO: Replace with your actual AMI IDs after building them
# Standard AMI for untrusted environment (built with: sudo ./setup-custom-ami.sh standard)
untrusted_custom_ami_id = "ami-0ea2fce7f7afb4f4c"

# GPU-enabled AMI for trusted streaming host (built with: sudo ./setup-custom-ami.sh gpu)
trusted_custom_ami_id = "ami-0ea2fce7f7afb4f4c"

# GPU AMI only for streaming host (optional - only when GPU enabled)
# gpu_custom_ami_id = "ami-REPLACE_WITH_GPU_AMI_ID"  # Build this later when needed

# --- GPU Configuration for Trusted Streaming Host ---
# Enable GPU instance for video processing workloads
streaming_host_use_gpu = false

# GPU instance type - choose based on performance needs and budget
gpu_instance_type = "g4dn.xlarge"  # Example GPU instance type

# --- Optional: VPN Authentication (uncomment if using SAML/MFA) ---
# vpn_authentication_type    = "saml"
# saml_identity_provider_arn = "arn:aws:iam::728951503198:saml-provider/YourIdPName"

# --- Optional: Instance Type Overrides ---
# default_instance_type = "t3.small"  # For non-GPU instances

# --- Optional: Streaming Port Overrides ---
# srt_udp_ports = [8090, 8091]

# --- Optional: Region Overrides (using defaults) ---
# primary_region = "il-central-1"
# remote_region  = "eu-west-1"

# --- Optional: VPC CIDR Overrides (using defaults) ---
# untrusted_vpc_cidrs = {
#   "streaming_ingress" = "172.17.21.0/24"
#   "streaming_scrub"   = "172.17.22.0/24"
#   "iot_management"    = "172.17.23.0/24"
#   "devops"            = "172.17.24.0/24"
# }
# 
# trusted_vpc_cidrs = {
#   "jacob_api_gw"    = "172.16.10.0/24"
#   "iot_management"  = "172.16.11.0/24"
#   "streaming"       = "172.16.12.0/24"
#   "streaming_scrub" = "172.16.13.0/24"
#   "devops"          = "172.16.14.0/24"
# }

# --- Optional: VPN Client CIDR Overrides (using defaults) ---
# trusted_vpn_client_cidr   = "172.30.0.0/22"
# untrusted_vpn_client_cidr = "172.31.0.0/22"
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

# --- Custom AMI Configuration ---
# Enable custom AMIs
use_custom_amis = true

# Standard AMI with Docker (needs Docker network fix for untrusted)
custom_standard_ami_id = "ami-0ea2fce7f7afb4f4c"

# GPU AMI for trusted streaming host (when ready)
custom_gpu_ami_id = null

# --- Instance Configuration ---
default_instance_type = "t3.micro"

# UDP ports for SRT streaming
srt_udp_ports = [8090]

# --- Optional: SAML/MFA Configuration ---
# vpn_authentication_type    = "saml"
# saml_identity_provider_arn = "arn:aws:iam::123456789012:saml-provider/YourIdPName"
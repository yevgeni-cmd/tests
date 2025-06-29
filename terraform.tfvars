# ----------------------------------------------------------------
#                 Example Variables File
#
# Create a file named 'terraform.tfvars' and copy the contents
# of this file into it. Then, set your required values.
# ----------------------------------------------------------------

# (Required) The name of the AWS profile in your ~/.aws/credentials file.
aws_profile = "728951503198_SystemAdministrator-8H"

# (Required) The ARN of a server certificate from AWS Certificate Manager (ACM)
# located in the 'primary_region' (il-central-1) for the TRUSTED VPN.
trusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/e42ef4ec-db4c-4537-b16e-81d3c2c0b4e2"

# (Required) The ARN of a server certificate from AWS Certificate Manager (ACM)
# located in the 'primary_region' (il-central-1) for the UNTRUSTED VPN.
untrusted_vpn_server_cert_arn = "arn:aws:acm:il-central-1:728951503198:certificate/0c87fe07-ed4d-4810-b069-f6c6fe8c2f92"

# --- Optional Variables ---

# To use SAML/MFA for VPN authentication, uncomment the following lines and
# provide the ARN of the SAML Identity Provider you have configured in AWS IAM.
# vpn_authentication_type    = "saml"
# saml_identity_provider_arn = "arn:aws:iam::123456789012:saml-provider/YourIdPName"

project_name = "poc"
instance_os = "ubuntu"

trusted_ssh_key_name = "sky-trusted"
untrusted_ssh_key_name = "sky-untrusted"

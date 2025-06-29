# Unified Multi-Environment AWS Infrastructure

This Terraform project deploys a complete and complex AWS network architecture based on the provided diagram. It creates two fully isolated environments, "Trusted" and "Untrusted," primarily within the `il-central-1` region, and includes a remote "Untrusted IoT" VPC in `eu-west-1`.

## Architecture Overview

The infrastructure is logically divided into three distinct zones:

### 1. Untrusted Environment (`il-central-1`)
* **Network:** A dedicated **Transit Gateway (`untrusted-tgw`)** connects all VPCs in this environment.
* **VPCs:** `Streaming Ingress` (Public), `Streaming Scrub` (Private), `IoT Management` (Private), and `DevOps` (Private).
* **Access:** A dedicated **Client VPN** provides secure access. By default, it uses certificate-based authentication, but can be switched to SAML/MFA.

### 2. Trusted Environment (`il-central-1`)
* **Network:** A separate, dedicated **Transit Gateway (`trusted-tgw`)**. It is completely isolated from the untrusted TGW.
* **VPCs:** `Streaming Scrub`, `Streaming (VOD)`, `IoT Management`, `JACOB (API GW)`, and `DevOps`.
* **Access:** A separate **Client VPN** provides secure, granular access only to the DevOps and Streaming Scrub VPCs.

### 3. Remote IoT Environment (`eu-west-1`)
* A single `IoT-eu` VPC connected via TGW Peering to the **Untrusted TGW**.

### . Create an EC2 Key Pair for SSH Access
This key pair is required to securely connect to the EC2 instances via SSH.

1.  Navigate to the **EC2 service** in the AWS Management Console.
2.  **Important:** In the top-right corner, ensure your region is set to the primary region for this project (e.g., **`il-central-1`**).
3.  In the left navigation pane, under "Network & Security," click **Key Pairs**.
4.  Click the **Create key pair** button.
5.  Enter a **Name** for your key pair (e.g., `my-project-key`). This is the name you will provide in your `.tfvars` file.
6.  For **Private key file format**, select **`.pem`** (for use with OpenSSH on macOS/Linux) or **`.ppk`** (for use with PuTTY on Windows).
7.  Click **Create key pair**. Your browser will automatically download the private key file.
8.  **Important:** Save this file in a secure location (like your `~/.ssh/` directory). This is the only time you can download it.

## Prerequisites

1.  **Terraform & AWS CLI:** Ensure both are installed and configured with a credentials profile.
2.  **EC2 Key Pair:** You must have an EC2 Key Pair created in the `il-central-1` region. You will need its name for SSH access to the instances.
3.  **ACM Certificates:** You must pre-create a server certificate in AWS Certificate Manager (ACM) in the `il-central-1` region for **each** of the two Client VPNs.

## File Structure


.
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── modules/
└── ...


## How to Execute

### 1. Create a `terraform.tfvars` file

Create a file named `terraform.tfvars` in the project's root directory. Use `terraform.tfvars.example` as a template and provide your specific values.

**`terraform.tfvars`:**
```hcl
aws_profile                  = "YOUR_PROFILE_NAME_HERE"
ssh_key_name                 = "YOUR_EC2_KEY_PAIR_NAME"
trusted_vpn_server_cert_arn  = "arn:aws:acm:..."
untrusted_vpn_server_cert_arn = "arn:aws:acm:..."

2. Initialization, Plan & Apply
This consolidated project can be deployed with a standard, single-pass apply.

terraform init
terraform plan
terraform apply

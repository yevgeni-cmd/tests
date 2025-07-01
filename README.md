# Final Multi-Environment AWS Infrastructure

This Terraform project deploys a complete and complex AWS network architecture based on the provided diagram. It creates two fully isolated environments, "Trusted" and "Untrusted," primarily within the `il-central-1` region, and includes a remote "Untrusted IoT" VPC in `eu-west-1`.

This version features a highly modular design with multi-subnet VPCs to correctly segregate application workloads, TGW attachments, and VPC endpoints, with granular routing and security for each.

## Architecture Overview

### 1. Untrusted Environment (`il-central-1`)
* **Network:** A dedicated **Transit Gateway (`untrusted-tgw`)** connects all VPCs in this environment.
* **VPCs:**
    * `Streaming Ingress` (Public): Receives SRT streams.
    * `Streaming Scrub` (Private): Processes streams. Connected via **VPC Peering** to the Trusted `Streaming Scrub` VPC.
    * `IoT Management` (Private): For managing untrusted IoT devices.
    * `DevOps` (Private): Management VPC with a public subnet for the ADO agent's internet access, and private subnets for the VPN and ECR endpoints.
* **Connectivity:** Connects to the remote `IoT-eu` VPC via **Cross-Region TGW Peering**.

### 2. Trusted Environment (`il-central-1`)
* **Network:** A separate, dedicated **Transit Gateway (`trusted-tgw`)**. It is completely isolated from the untrusted TGW.
* **VPCs:**
    * `Streaming Scrub`: Receives the one-way UDP stream from the untrusted scrub VPC via VPC Peering.
    * `Streaming (VOD)`: For internal video processing.
    * `IoT Management`: For trusted IoT services.
    * `JACOB (API GW)`: To host trusted API Gateways.
    * `DevOps`: The central management VPC with a public subnet for the ADO agent's internet access, and private subnets for the VPN and ECR endpoints.

### 3. Remote IoT Environment (`eu-west-1`)
* A single `IoT-eu` VPC connected via TGW Peering to the **Untrusted TGW**.

### Security & Access
* **Client VPN with MFA/Certificate:** Two separate Client VPN endpoints provide secure access. The authentication method is configurable.
* **VPC Endpoint Policies:** All VPC endpoints have policies restricting access to principals within your AWS account.
* **Security Groups & NACLs:** Granular rules are applied. SSH access is restricted to VPN clients. NACLs on scrub VPCs provide an extra layer of defense.

## Prerequisites

1.  **Terraform & AWS CLI:** Ensure both are installed and configured.
2.  **EC2 Key Pairs:** You must pre-create two EC2 Key Pairs in `il-central-1`: one for trusted instances and one for untrusted.
3.  **ACM Certificates:** You must pre-create a server certificate in ACM in `il-central-1` for **each** of the two Client VPNs.
4.  **(Optional) SAML IdP:** If using MFA, you must have a SAML Identity Provider configured in AWS IAM and provide its ARN.

## How to Execute

1.  **Create `terraform.tfvars`:** Use `terraform.tfvars.example` as a template and provide your specific values.
2.  **Initialize, Plan & Apply:**

    ```bash
    terraform init -upgrade
    terraform plan
    terraform apply
    ```

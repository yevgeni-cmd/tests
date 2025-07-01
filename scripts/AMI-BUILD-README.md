# Files to Create/Update for Dynamic IP + GPU Support

## ✅ FILES TO UPDATE (Replace existing content)

### 1. **terraform.tfvars**
```bash
# Replace your current terraform.tfvars with the fixed version
# Update the AMI IDs after building your custom AMIs
```
**Status**: REPLACE with fixed version above

### 2. **variables.tf**
```bash
# Add these new variables to your existing variables.tf
```
**Add these sections**:
```hcl
################################################################################
# Custom AMI Variables
################################################################################
variable "custom_ami_id" {
  description = "Custom AMI ID with Docker and tools pre-installed."
  type        = string
  default     = null
}

variable "trusted_custom_ami_id" {
  description = "Custom AMI ID for trusted environment instances."
  type        = string
  default     = null
}

variable "untrusted_custom_ami_id" {
  description = "Custom AMI ID for untrusted environment instances."
  type        = string
  default     = null
}

################################################################################
# Instance Type Variables
################################################################################
variable "gpu_instance_type" {
  description = "GPU instance type for trusted streaming host"
  type        = string
  default     = "g4dn.xlarge"
}

variable "streaming_host_use_gpu" {
  description = "Whether to use GPU instance type for trusted streaming host"
  type        = bool
  default     = false
}
```

### 3. **modules/ec2_instance/main.tf**
**Update these sections**:
```hcl
# Replace the data source and locals
data "aws_ami" "selected" {
  count       = var.custom_ami_id == null ? 1 : 0
  most_recent = true
  owners      = [var.ami_owners[var.instance_os]]
  
  filter {
    name   = "name"
    values = [var.ami_filters[var.instance_os]]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.custom_ami_id != null ? var.custom_ami_id : data.aws_ami.selected[0].id
}

# Update the instance resource
resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data
  tags                        = { Name = var.instance_name }
}
```

### 4. **modules/ec2_instance/variables.tf**
**Add these variables**:
```hcl
variable "user_data" {
  description = "User data script to run on instance launch"
  type        = string
  default     = null
}

variable "custom_ami_id" {
  description = "Custom AMI ID to use instead of auto-discovery"
  type        = string
  default     = null
}
```

### 5. **trusted-infrastructure.tf**
**Replace the trusted streaming host section**:
```hcl
# Trusted Streaming Docker Host with GPU support
module "trusted_streaming_host" {
  source        = "./modules/ec2_instance"
  providers     = { aws = aws.primary }
  instance_name = "${var.project_name}-trusted-streaming-host"
  key_name      = var.trusted_ssh_key_name
  instance_os   = var.instance_os
  instance_type = var.streaming_host_use_gpu ? var.gpu_instance_type : var.default_instance_type
  subnet_id     = module.trusted_vpc_streaming.private_subnets_by_name["streaming-docker"].id
  vpc_id        = module.trusted_vpc_streaming.vpc_id
  custom_ami_id = var.trusted_custom_ami_id != null ? var.trusted_custom_ami_id : var.custom_ami_id
  user_data     = var.streaming_host_use_gpu ? base64encode(templatefile("${path.module}/user-data/gpu-optimization-userdata.sh", {
    aws_region = var.primary_region
  })) : null
}
```

### 6. **untrusted-infrastructure.tf**
**Replace the untrusted scrub host section**:
```hcl
# Streaming Scrub Host with UDP forwarding
module "untrusted_scrub_host" {
  source        = "./modules/ec2_instance"
  providers     = { aws = aws.primary }
  instance_name = "${var.project_name}-untrusted-scrub-host"
  key_name      = var.untrusted_ssh_key_name
  instance_os   = var.instance_os
  instance_type = var.default_instance_type
  subnet_id     = module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
  vpc_id        = module.untrusted_vpc_streaming_scrub.vpc_id
  custom_ami_id = var.untrusted_custom_ami_id != null ? var.untrusted_custom_ami_id : var.custom_ami_id
  user_data     = base64encode(templatefile("${path.module}/user-data/untrusted-scrub-userdata.sh", {
    trusted_scrub_vpc_cidr = var.trusted_vpc_cidrs["streaming_scrub"]
    udp_port              = var.srt_udp_ports[0]
    aws_region            = var.primary_region
  }))
}
```

## 📁 NEW FILES TO CREATE

### 7. **setup-custom-ami.sh** (Root directory)
```bash
# Create this file in your terraform root directory
# Use the content from the ami_setup_script artifact
```
**Purpose**: Script to build both standard and GPU AMIs

### 8. **user-data/** (New directory)
```bash
mkdir user-data
```

#### 8a. **user-data/untrusted-scrub-userdata.sh**
```bash
# Template for dynamic IP discovery and UDP forwarding
```
**Purpose**: Automatically configures UDP forwarding with dynamic IP discovery

#### 8b. **user-data/gpu-optimization-userdata.sh**
```bash
# Template for GPU optimization on trusted streaming host
```
**Purpose**: Optimizes GPU settings since drivers are pre-installed in AMI

### 9. **GPU-AMI-BUILD-GUIDE.md** (Root directory)
```bash
# Detailed instructions for building both AMIs
```
**Purpose**: Step-by-step guide for creating standard and GPU AMIs

### 10. **udp-forwarding-setup.sh** (Standalone script)
```bash
# Updated script without hardcoded IPs
```
**Purpose**: Used within AMIs for UDP forwarding management

## 🔧 IMPLEMENTATION ORDER

### Phase 1: Update Existing Files (5 minutes)
1. ✅ **terraform.tfvars** - Replace with fixed version
2. ✅ **variables.tf** - Add GPU and AMI variables  
3. ✅ **modules/ec2_instance/main.tf** - Add custom AMI support
4. ✅ **modules/ec2_instance/variables.tf** - Add new variables
5. ✅ **trusted-infrastructure.tf** - Update streaming host
6. ✅ **untrusted-infrastructure.tf** - Update scrub host

### Phase 2: Create New Files (10 minutes)
7. ✅ **setup-custom-ami.sh** - AMI build script
8. ✅ **user-data/** directory and scripts
9. ✅ **GPU-AMI-BUILD-GUIDE.md** - Build instructions

### Phase 3: Build AMIs (30-45 minutes)
10. ✅ Launch t3.medium → run `sudo ./setup-custom-ami.sh standard` → create standard AMI
11. ✅ Launch g4dn.xlarge → run `sudo ./setup-custom-ami.sh gpu` → create GPU AMI
12. ✅ Update terraform.tfvars with actual AMI IDs

### Phase 4: Deploy (5 minutes)
13. ✅ `terraform plan` - verify GPU instance type and AMI IDs
14. ✅ `terraform apply` - deploy with dynamic configuration

## 📋 QUICK VERIFICATION CHECKLIST

After implementation:
- [ ] Both AMIs built and IDs updated in terraform.tfvars
- [ ] `streaming_host_use_gpu = true` in terraform.tfvars
- [ ] terraform plan shows GPU instance type for trusted streaming
- [ ] terraform apply succeeds
- [ ] Untrusted scrub automatically discovers trusted scrub IP
- [ ] UDP forwarding works: ingress → untrusted scrub → trusted scrub
- [ ] Trusted streaming host has working GPU: `nvidia-smi`

## 🚨 CRITICAL NOTES

1. **AMI IDs Required**: You MUST build and update AMI IDs before terraform apply
2. **GPU AMI Must Be Built on GPU Instance**: Standard instance won't have GPU drivers
3. **Dynamic IP Discovery**: No more hardcoded IPs, everything discovered automatically
4. **Internet Access for AMI Building**: Only needed during AMI creation, not deployment
5. **Test GPU AMI**: Verify `nvidia-smi` and `docker run --gpus all` work before creating AMI

This ensures your infrastructure works with dynamic IPs and has GPU support for streaming workloads!
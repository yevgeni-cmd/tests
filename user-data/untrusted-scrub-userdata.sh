#!/bin/bash

# =================================================================
# User-Data Script for Untrusted Scrub Host (Terraform Fix)
#
# This script automatically discovers the private IP of the trusted
# scrub host and configures iptables for UDP forwarding.
# It is designed to be robust and handle EC2 initialization timing.
# =================================================================

# Log all output to a dedicated user-data log file for easier debugging
exec > >(tee /var/log/user-data-all.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Starting user-data script at $(date) ---"

# --- Configuration (Passed from Terraform) ---
# THE FIX: Removed the ":-default" syntax which conflicts with Terraform's
# templatefile function. The values are now passed directly from Terraform.
TRUSTED_SCRUB_VPC_CIDR="${trusted_scrub_vpc_cidr}"
UDP_PORT="${udp_port}"
AWS_REGION="${aws_region}"
TRUSTED_HOST_TAG_NAME="*trusted-scrub-host*" # The 'Name' tag of the trusted EC2 instance

echo "Configuration:"
echo "  UDP_PORT: $UDP_PORT"
echo "  AWS_REGION: $AWS_REGION"
echo "  TRUSTED_HOST_TAG_NAME: $TRUSTED_HOST_TAG_NAME"

# --- Wait for System Initialization ---
# This is a critical step to prevent race conditions. It ensures that
# cloud-init has finished its setup, including network configuration.
echo "Waiting for cloud-init to complete..."
cloud-init status --wait
echo "Cloud-init finished. Proceeding with script."


# --- Dynamic IP Discovery Function ---
# This function is more resilient and retries the AWS CLI command.
discover_trusted_scrub_ip() {
    local max_retries=5
    local retry_delay=15
    local attempt=1
    local trusted_ip=""

    echo "Attempting to discover trusted scrub host IP using AWS CLI..."

    while [ $attempt -le $max_retries ]; do
        echo "Attempt #$attempt of $max_retries..."
        
        # Query AWS for the private IP of the running instance with the specified tag.
        trusted_ip=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=$TRUSTED_HOST_TAG_NAME" "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[?PrivateIpAddress!=null].PrivateIpAddress' \
            --output text)

        if [[ -n "$trusted_ip" ]] && [[ "$trusted_ip" != "None" ]]; then
            echo "SUCCESS: Discovered trusted scrub IP: $trusted_ip"
            echo "$trusted_ip"
            return 0
        fi

        echo "WARN: Could not find trusted scrub IP on attempt $attempt. Retrying in $retry_delay seconds..."
        sleep $retry_delay
        ((attempt++))
    done

    echo "ERROR: Failed to discover trusted scrub IP after $max_retries attempts."
    return 1
}

# --- Main Execution ---

# Discover the trusted scrub IP. Exit if not found.
TRUSTED_SCRUB_IP=$(discover_trusted_scrub_ip)
if [ -z "$TRUSTED_SCRUB_IP" ]; then
    echo "CRITICAL: UDP forwarding cannot be configured. Aborting."
    exit 1
fi

# Export the variables so they can be used by the child script.
# This is the correct way to pass environment variables.
export TRUSTED_SCRUB_IP
export UDP_PORT

echo "Setting up UDP forwarding to -> $TRUSTED_SCRUB_IP:$UDP_PORT"

# Check if the setup script from the AMI exists and run it.
if [ -f /usr/local/bin/udp-forwarding-setup.sh ]; then
    /usr/local/bin/udp-forwarding-setup.sh setup
    echo "SUCCESS: UDP forwarding setup script completed."
else
    echo "ERROR: The setup script '/usr/local/bin/udp-forwarding-setup.sh' was not found in the AMI."
    exit 1
fi

# --- Final Verification ---
echo "--- UDP Forwarding Configuration Summary ---"
/usr/local/bin/udp-forwarding-setup.sh status

echo "--- User-data script finished at $(date) ---"

exit 0

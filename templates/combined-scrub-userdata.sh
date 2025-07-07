#!/bin/bash

# =================================================================
# User-Data Script for Untrusted Scrub Host
# Receives the trusted IP directly from Terraform.
# =================================================================

exec > >(tee /var/log/user-data-forwarding.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Starting traffic forwarding script at $(date) ---"

# --- Configuration (Injected by Terraform) ---
# The IP is now static, provided directly at launch. No discovery needed.
TRUSTED_SCRUB_IP="${trusted_ip}"
AWS_REGION="${aws_region}"

echo "Configuration:"
echo "  AWS_REGION: $AWS_REGION"
echo "  TRUSTED_SCRUB_IP: $TRUSTED_SCRUB_IP (Received from Terraform)"

# --- Main Execution ---
if [ -z "$TRUSTED_SCRUB_IP" ]; then
    echo "CRITICAL: Trusted scrub IP was not provided by Terraform. Halting script."
    exit 1
fi

echo "Setting up ALL traffic forwarding to -> $TRUSTED_SCRUB_IP"

# --- Setup iptables Forwarding Rules ---
setup_all_traffic_forwarding() {
    echo "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    
    echo "Flushing old NAT and Filter rules..."
    iptables -t nat -F
    iptables -F FORWARD

    echo "Setting up iptables rules..."
    
    # PREROUTING (DNAT): Redirect all incoming traffic (except for SSH) to the trusted scrub host.
    iptables -t nat -A PREROUTING -p tcp ! --dport 22 -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A PREROUTING -p icmp -j DNAT --to-destination $TRUSTED_SCRUB_IP
    
    # POSTROUTING (MASQUERADE)
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    # FORWARD chain
    iptables -A FORWARD -i eth0 -p tcp ! --dport 22 -d $TRUSTED_SCRUB_IP -j ACCEPT
    iptables -A FORWARD -i eth0 -p udp -d $TRUSTED_SCRUB_IP -j ACCEPT
    iptables -A FORWARD -i eth0 -p icmp -d $TRUSTED_SCRUB_IP -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    echo "Saving iptables rules for persistence..."
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    
    echo "ALL traffic forwarding setup completed."
}

# Execute the forwarding setup
setup_all_traffic_forwarding

# --- Final Status Check ---
echo "--- Traffic Forwarding Configuration Summary ---"
echo "Forwarding ALL traffic (except SSH on port 22) to: $TRUSTED_SCRUB_IP"
echo ""
echo "Current iptables NAT rules:"
iptables -t nat -L -n --line-numbers

echo "--- Script finished at $(date) ---"
exit 0
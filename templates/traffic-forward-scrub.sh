#!/bin/bash

# =================================================================
# Traffic Forwarding Script for Untrusted Scrub Host
# Forwards all traffic (except SSH) to trusted scrub host
# =================================================================

exec > >(tee /var/log/traffic-forward.log | logger -t traffic-forward -s 2>/dev/console) 2>&1

echo "--- Starting traffic forwarding setup at $(date) ---"

# --- Configuration (Injected by Terraform) ---
TRUSTED_SCRUB_IP="${trusted_ip}"
AWS_REGION="${aws_region}"

echo "Configuration:"
echo "  AWS_REGION: $AWS_REGION"
echo "  TRUSTED_SCRUB_IP: $TRUSTED_SCRUB_IP"

# FIX: Wait for system to be ready and DNS to work
echo "Waiting for system initialization..."
sleep 30

# FIX: Set hostname resolution fallback
echo "127.0.0.1 $(hostname)" >> /etc/hosts

# --- Main Execution ---
if [ -z "$TRUSTED_SCRUB_IP" ]; then
    echo "CRITICAL: Trusted scrub IP was not provided by Terraform. Halting script."
    exit 1
fi

echo "=== Setting up traffic forwarding to -> $TRUSTED_SCRUB_IP ==="

# Check if iptables is available
if ! command -v iptables &> /dev/null; then
    echo "ERROR: iptables not found!"
    exit 1
fi

# Check if we can run iptables (need root)
if ! iptables -L >/dev/null 2>&1; then
    echo "ERROR: Cannot run iptables (need root privileges)"
    exit 1
fi

echo "Checking current trusted scrub IP connectivity..."
ping -c 1 $TRUSTED_SCRUB_IP && echo "✅ Can reach trusted scrub" || echo "⚠️ Cannot ping trusted scrub (may be expected)"

setup_traffic_forwarding() {
    echo "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    
    echo "Flushing old NAT and Filter rules..."
    iptables -t nat -F PREROUTING
    iptables -t nat -F POSTROUTING
    iptables -F FORWARD

    echo "Setting up iptables rules..."
    
    # PREROUTING (DNAT): Redirect all incoming traffic (except SSH) to trusted scrub
    echo "Adding PREROUTING DNAT rules..."
    iptables -t nat -A PREROUTING -p tcp ! --dport 22 -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A PREROUTING -p icmp -j DNAT --to-destination $TRUSTED_SCRUB_IP
    
    # POSTROUTING (MASQUERADE)
    echo "Adding POSTROUTING MASQUERADE rule..."
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    # FORWARD chain - CRITICAL: Allow traffic to trusted scrub IP
    echo "Setting up FORWARD rules for traffic to trusted scrub..."
    iptables -A FORWARD -d $TRUSTED_SCRUB_IP -j ACCEPT
    iptables -A FORWARD -s $TRUSTED_SCRUB_IP -j ACCEPT
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Verify rules were added
    echo "Verifying PREROUTING rules..."
    iptables -t nat -L PREROUTING -n -v --line-numbers
    
    echo "Verifying FORWARD rules..."
    iptables -L FORWARD -n -v --line-numbers
    
    echo "Saving iptables rules for persistence..."
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    
    echo "✅ Traffic forwarding setup completed."
}

# Execute traffic forwarding setup
setup_traffic_forwarding

# --- Final Status Check ---
echo "--- Traffic Forwarding Configuration Summary ---"
echo "✅ Forwarding ALL traffic (except SSH on port 22) to: $TRUSTED_SCRUB_IP"
echo ""
echo "Current iptables NAT rules:"
iptables -t nat -L -n --line-numbers
echo ""
echo "Current iptables FORWARD rules:"
iptables -L FORWARD -n --line-numbers

echo "--- Traffic forwarding script finished at $(date) ---"
exit 0
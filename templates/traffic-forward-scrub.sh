#!/bin/bash

# =================================================================
# Traffic Forwarding Script for Untrusted Scrub Host
# Forwards all traffic (except SSH) to trusted scrub host
# and ensures rules are persistent across reboots.
# =================================================================

exec > >(tee /var/log/traffic-forward.log | logger -t traffic-forward -s 2>/dev/console) 2>&1

echo "--- Starting traffic forwarding setup at $(date) ---"

# --- Configuration (Injected by Terraform) ---
TRUSTED_SCRUB_IP="${trusted_ip}"
AWS_REGION="${aws_region}" # Included for consistency, though not used in this script

echo "Configuration:"
echo "  TRUSTED_SCRUB_IP: $TRUSTED_SCRUB_IP"

# --- Validation ---
if [ -z "$TRUSTED_SCRUB_IP" ]; then
    echo "❌ CRITICAL: Trusted scrub IP was not provided by Terraform. Halting script."
    exit 1
fi

# Check if we can run iptables (need root)
if ! command -v iptables &> /dev/null || ! iptables -L >/dev/null 2>&1; then
    echo "❌ ERROR: iptables command not found or cannot be run (need root privileges)."
    exit 1
fi

# --- Main Setup Function ---
setup_traffic_forwarding() {
    echo "Enabling IP forwarding permanently..."
    # Ensure net.ipv4.ip_forward is set to 1 on boot
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ip-forward.conf
    # Apply the setting for the current session
    sysctl -p /etc/sysctl.d/99-ip-forward.conf
    
    echo "Flushing old NAT and Filter rules..."
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X

    echo "Setting up iptables rules..."
    
    # PREROUTING (DNAT): Redirect all incoming traffic (except SSH) to trusted scrub
    echo "Adding PREROUTING DNAT rules..."
    iptables -t nat -A PREROUTING -p tcp ! --dport 22 -j DNAT --to-destination "$TRUSTED_SCRUB_IP"
    iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination "$TRUSTED_SCRUB_IP"
    iptables -t nat -A PREROUTING -p icmp -j DNAT --to-destination "$TRUSTED_SCRUB_IP"
    
    # POSTROUTING (MASQUERADE): Change the source IP for forwarded packets
    echo "Adding POSTROUTING MASQUERADE rule..."
    iptables -t nat -A POSTROUTING -j MASQUERADE
    
    # FORWARD chain: Allow traffic to be forwarded to and from the trusted scrub IP
    echo "Setting up FORWARD rules for traffic to trusted scrub..."
    iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -d "$TRUSTED_SCRUB_IP" -j ACCEPT
    
    echo "✅ iptables rules configured."
}

# --- Persistence Setup Function ---
setup_persistence() {
    echo "--- Setting up reboot persistence ---"
    
    # 1. Save the currently configured iptables rules to a file
    echo "Saving iptables rules to /etc/iptables/rules.v4..."
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    
    # 2. Create a systemd service to restore these rules on boot
    echo "Creating systemd service to restore iptables rules..."
    cat > /etc/systemd/system/iptables-restore.service << 'EOF'
[Unit]
Description=IPv4 Packet Filtering Framework - Rule Restore
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # 3. Reload systemd and enable the new service to run on startup
    echo "Enabling iptables-restore service..."
    systemctl daemon-reload
    systemctl enable iptables-restore.service
    
    echo "✅ Persistence setup complete. Rules will be reloaded on reboot."
}

# --- Execute Setup ---
setup_traffic_forwarding
setup_persistence

# --- Final Status Check ---
echo "--- Traffic Forwarding Configuration Summary ---"
echo "✅ Forwarding ALL traffic (except SSH on port 22) to: $TRUSTED_SCRUB_IP"
echo ""
echo "Current iptables NAT rules:"
iptables -t nat -L -n -v --line-numbers
echo ""
echo "Current iptables FORWARD rules:"
iptables -L FORWARD -n -v --line-numbers
echo ""
echo "Systemd service status:"
systemctl status iptables-restore.service --no-pager

echo "--- Traffic forwarding script finished at $(date) ---"
exit 0

# Make it executable
chmod +x udp-forwarding-setup.sh

# Set up UDP forwarding (default action)
sudo ./udp-forwarding-setup.sh

# Or explicitly specify setup
sudo ./udp-forwarding-setup.sh setup

# Check current status
./udp-forwarding-setup.sh status

# Test connectivity
./udp-forwarding-setup.sh test

# Remove rules if needed
sudo ./udp-forwarding-setup.sh remove

# Show help
./udp-forwarding-setup.sh help
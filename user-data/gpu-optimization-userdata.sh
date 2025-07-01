#!/bin/bash

# User data script for GPU-enabled trusted streaming host
# Since GPU drivers are pre-installed in AMI, this just optimizes settings

# Log all output
exec > >(tee /var/log/gpu-optimization.log)
exec 2>&1

echo "Starting GPU optimization at $(date)"

# Configuration
AWS_REGION="${aws_region}"

# Wait for system to be ready
sleep 30

# Function to optimize GPU settings
optimize_gpu_performance() {
    echo "Optimizing GPU performance settings..."
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "NVIDIA GPU detected, applying optimizations..."
        
        # Enable persistence mode (reduces driver load/unload overhead)
        nvidia-smi -pm 1 2>/dev/null && echo "✅ GPU persistence mode enabled" || echo "⚠️ Could not enable persistence mode"
        
        # Set maximum performance clocks
        local max_clocks=$(nvidia-smi --query-gpu=clocks.max.memory,clocks.max.sm --format=csv,noheader,nounits | tr ',' ' ')
        if [[ -n "$max_clocks" ]]; then
            nvidia-smi -ac $max_clocks 2>/dev/null && echo "✅ Maximum performance clocks set" || echo "⚠️ Could not set maximum clocks"
        fi
        
        # Set power limit to maximum (if supported)
        local max_power=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits | head -1)
        if [[ -n "$max_power" ]] && [[ "$max_power" != "[Not Supported]" ]]; then
            nvidia-smi -pl $max_power 2>/dev/null && echo "✅ Maximum power limit set" || echo "⚠️ Could not set power limit"
        fi
        
        echo "GPU optimization completed"
    else
        echo "⚠️ nvidia-smi not found - GPU drivers may not be installed"
        echo "Expected: This should not happen with GPU-enabled AMI"
    fi
}

# Function to verify Docker GPU integration
verify_docker_gpu() {
    echo "Verifying Docker GPU integration..."
    
    # Wait for Docker to be ready
    local retry_count=0
    while ! docker info >/dev/null 2>&1 && [ $retry_count -lt 10 ]; do
        echo "Waiting for Docker to start... (attempt $((retry_count + 1))/10)"
        sleep 5
        retry_count=$((retry_count + 1))
    done
    
    if docker info >/dev/null 2>&1; then
        echo "✅ Docker is running"
        
        # Test GPU access from Docker
        if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi >/dev/null 2>&1; then
            echo "✅ Docker GPU integration is working"
        else
            echo "⚠️ Docker GPU integration test failed"
            echo "Checking Docker configuration..."
            cat /etc/docker/daemon.json 2>/dev/null || echo "No Docker daemon.json found"
        fi
    else
        echo "❌ Docker is not running"
    fi
}

# Function to set up GPU monitoring
setup_gpu_monitoring() {
    echo "Setting up GPU monitoring..."
    
    # Create a simple GPU monitoring service
    cat > /etc/systemd/system/gpu-monitor.service << 'EOF'
[Unit]
Description=GPU Monitoring Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/watch -n 10 nvidia-smi
Restart=always
User=ubuntu

[Install]
WantedBy=multi-user.target
EOF
    
    # Note: Don't enable by default to avoid cluttering logs
    # systemctl enable gpu-monitor.service
    
    echo "GPU monitoring service created (not enabled by default)"
    echo "To enable: sudo systemctl enable --now gpu-monitor.service"
}

# Function to create GPU status aliases
create_gpu_aliases() {
    echo "Creating GPU convenience aliases..."
    
    cat >> /home/ubuntu/.bashrc << 'EOF'

# GPU and streaming aliases
alias gpu='nvidia-smi'
alias gpu-watch='watch -n 2 nvidia-smi'
alias gpu-temp='nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits'
alias gpu-util='nvidia-smi --query-gpu=utilization.gpu,utilization.memory --format=csv,noheader'
alias docker-gpu-test='docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi'
alias streaming-start='cd ~/docker-templates && docker-compose -f gpu-streaming-compose.yml up -d'
alias streaming-stop='cd ~/docker-templates && docker-compose -f gpu-streaming-compose.yml down'
alias streaming-logs='cd ~/docker-templates && docker-compose -f gpu-streaming-compose.yml logs -f'
EOF
    
    # Copy GPU Docker templates to user directory
    if [ -d /etc/skel/docker-templates ]; then
        cp -r /etc/skel/docker-templates /home/ubuntu/
        chown -R ubuntu:ubuntu /home/ubuntu/docker-templates
        echo "✅ GPU Docker templates copied to /home/ubuntu/docker-templates/"
    fi
    
    echo "✅ GPU aliases and templates configured"
}

# Main execution
main() {
    echo "=== GPU-Enabled Trusted Streaming Host Setup ==="
    echo "AWS Region: $AWS_REGION"
    echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo 'Unknown')"
    echo ""
    
    # Run optimizations
    optimize_gpu_performance
    verify_docker_gpu
    setup_gpu_monitoring
    create_gpu_aliases
    
    # Final status report
    echo ""
    echo "=== Setup Summary ==="
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "GPU Status:"
        nvidia-smi --query-gpu=name,memory.total,utilization.gpu,temperature.gpu --format=csv
        echo ""
        
        echo "Docker GPU Test:"
        if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi >/dev/null 2>&1; then
            echo "✅ Docker GPU integration working"
        else
            echo "❌ Docker GPU integration failed"
        fi
    else
        echo "❌ NVIDIA drivers not detected"
        echo "Please ensure you're using the GPU-enabled AMI"
    fi
    
    echo ""
    echo "Available commands:"
    echo "  gpu               - Show GPU status"
    echo "  gpu-watch         - Monitor GPU in real-time"  
    echo "  docker-gpu-test   - Test Docker GPU integration"
    echo "  streaming-start   - Start GPU streaming services"
    echo "  /usr/local/bin/gpu-status.sh - Comprehensive GPU status"
    
    echo ""
    echo "GPU optimization completed at $(date)"
}

# Run main function
main
#!/bin/bash
# Script to copy setup files to Jetson when it's accessible

JETSON_IP="192.168.1.254"
JETSON_USER="yadin"

echo "=== Copy Files to Jetson ==="
echo "Jetson IP: $JETSON_IP"
echo "Username: $JETSON_USER"

# Test connectivity first
echo "Testing connectivity to Jetson..."
if ping -c 1 -W 3 "$JETSON_IP" >/dev/null 2>&1; then
    echo "✓ Jetson is reachable"
else
    echo "✗ Jetson is not reachable at $JETSON_IP"
    echo "Please check:"
    echo "1. Jetson is powered on"
    echo "2. Network connection is working"  
    echo "3. IP address is correct"
    exit 1
fi

# Test SSH connectivity
echo "Testing SSH connection..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$JETSON_USER@$JETSON_IP" "echo 'SSH OK'" 2>/dev/null; then
    echo "✓ SSH connection successful"
else
    echo "✗ SSH connection failed"
    echo "Please check:"
    echo "1. SSH is enabled on Jetson"
    echo "2. Username '$JETSON_USER' is correct"
    echo "3. SSH keys or password authentication is set up"
    exit 1
fi

# Copy setup script
echo "Copying setup script to Jetson..."
scp -o StrictHostKeyChecking=no jetson_complete_setup.sh "$JETSON_USER@$JETSON_IP:~/"
if [ $? -eq 0 ]; then
    echo "✓ Setup script copied successfully"
else
    echo "✗ Failed to copy setup script"
    exit 1
fi

# Run setup script on Jetson
echo "Running setup script on Jetson..."
ssh -o StrictHostKeyChecking=no "$JETSON_USER@$JETSON_IP" "chmod +x ~/jetson_complete_setup.sh && ~/jetson_complete_setup.sh"

echo ""
echo "=== Next Steps ==="
echo "1. If setup completed successfully, start streaming:"
echo "   ssh $JETSON_USER@$JETSON_IP"
echo "   python3 ~/stream_pacman_cameras.py"
echo ""
echo "2. On this computer, start the receiver:"
echo "   python3 pacman_depth_receiver.py --jetson-ip $JETSON_IP"



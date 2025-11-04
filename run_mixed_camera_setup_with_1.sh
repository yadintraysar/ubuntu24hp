#!/bin/bash

# PACMAN All 4 Cameras Combined Setup
# Cameras 1, 2, 3, 4 (ports 30000, 30002, 30004, 30006): All in combined receiver

echo "=== PACMAN 4-Camera Combined Setup ==="
echo "All cameras (1, 2, 3, 4) in one combined display"
echo ""

# Set up conda environment
echo "Activating conda environment..."
source ~/miniforge3/etc/profile.d/conda.sh
conda activate pacman

# Set Jetson IP
JETSON_IP=${1:-10.0.0.31}
echo "Using Jetson IP: $JETSON_IP"
echo ""

# Function to cleanup background processes
cleanup() {
    echo ""
    echo "Cleaning up processes..."
    if [ ! -z "$RECEIVER_PID" ]; then
        kill $RECEIVER_PID 2>/dev/null
        echo "Stopped 4-camera receiver (PID: $RECEIVER_PID)"
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start 4-camera receiver
echo "Starting 4-camera combined receiver..."
echo "Cameras: 1, 2, 3, 4"
echo "Ports: 30000, 30002, 30004, 30006"
cd /home/yadinlinux/Documents/SDKstream
python3 simple_4camera_receiver.py --ip $JETSON_IP &
RECEIVER_PID=$!
echo "4-camera receiver started with PID: $RECEIVER_PID"

echo ""
echo "All 4 cameras running in combined display!"
echo "Press Ctrl+C to stop"

# Wait for process
wait $RECEIVER_PID

echo "Receiver has stopped."




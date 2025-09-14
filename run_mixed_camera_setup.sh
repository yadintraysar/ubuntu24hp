#!/bin/bash

# PACMAN Mixed Camera Setup
# Camera 1 (port 30000): Uses separate pacman_camera_receiver.py
# Cameras 2, 3, 4 (ports 30002, 30004, 30006): Uses modified combined receiver

echo "=== PACMAN Mixed Camera Setup ==="
echo "Camera 1: Separate receiver (pacman_camera_receiver.py)"
echo "Cameras 2-4: Combined receiver (streaming_receiver_4cameras_combined.py)"
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
    if [ ! -z "$CAMERA1_PID" ]; then
        kill $CAMERA1_PID 2>/dev/null
        echo "Stopped camera 1 receiver (PID: $CAMERA1_PID)"
    fi
    if [ ! -z "$COMBINED_PID" ]; then
        kill $COMBINED_PID 2>/dev/null
        echo "Stopped combined receiver (PID: $COMBINED_PID)"
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Start Camera 1 receiver in background
echo "Starting Camera 1 receiver (port 30000)..."
cd /home/yadinlinux/Documents/SDKstream
python3 pacman_camera_receiver.py --ip $JETSON_IP --port 30000 &
CAMERA1_PID=$!
echo "Camera 1 receiver started with PID: $CAMERA1_PID"

# Wait a moment for camera 1 to initialize
sleep 2

# Start combined receiver for cameras 2, 3, 4 in background
echo "Starting combined receiver for cameras 2, 3, 4..."
python3 streaming_receiver_4cameras_combined.py --jetson_ip $JETSON_IP &
COMBINED_PID=$!
echo "Combined receiver started with PID: $COMBINED_PID"

echo ""
echo "Both receivers are running!"
echo "Camera 1: PID $CAMERA1_PID (separate window)"
echo "Cameras 2-4: PID $COMBINED_PID (combined window)"
echo ""
echo "Press Ctrl+C to stop all receivers"

# Wait for both processes
wait $CAMERA1_PID $COMBINED_PID

echo "All receivers have stopped."

#!/bin/bash

# Simple version: Run camera 1 separately and cameras 2-4 combined
# Usage: ./run_mixed_simple.sh [jetson_ip]

JETSON_IP=${1:-10.0.0.31}

# Activate conda and run camera 1 receiver in background
source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman && python3 pacman_camera_receiver.py --ip $JETSON_IP --port 30000 &

# Wait a moment then run the combined receiver for cameras 2-4
sleep 2
source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman && python3 streaming_receiver_4cameras_combined.py --jetson_ip $JETSON_IP

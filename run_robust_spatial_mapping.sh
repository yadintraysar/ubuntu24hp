#!/bin/bash
# Run robust PACMAN spatial mapping for long duration vehicle operation
# This script handles corrupted frames and keeps running

source ~/miniforge3/etc/profile.d/conda.sh
conda activate pacman

echo "=========================================="
echo "PACMAN Robust Spatial Mapping"
echo "Designed for hours-long vehicle operation"
echo "=========================================="
echo ""
echo "Controls:"
echo "  - Press SPACE to start/stop mapping"
echo "  - Press 'q' to quit"
echo "  - Ctrl+C for graceful shutdown"
echo ""

python3 /home/yadinlinux/Documents/SDKstream/streaming_receiver_spatial_mapping_robust.py --ip_address 10.0.0.31:30002 "$@"







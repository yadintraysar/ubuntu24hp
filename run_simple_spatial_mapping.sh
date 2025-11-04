#!/bin/bash
# Run simple PACMAN spatial mapping (no 3D viewer, more stable)

source ~/miniforge3/etc/profile.d/conda.sh
conda activate pacman

echo "=========================================="
echo "PACMAN Simple Spatial Mapping"
echo "=========================================="
echo "IMPORTANT: Press 'm' to START mapping after launch!"
echo "Then press 's' to save mesh anytime"
echo "Auto-saves every 5 minutes once mapping starts"
echo "=========================================="
echo ""

python3 /home/yadinlinux/Documents/SDKstream/streaming_receiver_spatial_mapping_simple.py --ip_address 10.0.0.31:30002 --resolution HD720 --auto_save_interval 300 "$@"


#!/bin/bash
# Real PACMAN Receiver using C++ samples (no Python API needed)

echo "=== PACMAN Real Receiver (C++) ==="
echo "Connecting to Jetson at 192.168.1.254"
echo ""

# Use the official PACMAN SDK C++ receiver sample
cd /usr/local/zed/samples/camera\ streaming/receiver/cpp/

# Build if not already built
if [ ! -d "build" ]; then
    echo "Building C++ receiver..."
    mkdir build
    cd build
    cmake ..
    make -j$(nproc)
    cd ..
fi

echo "Starting receivers for 4 cameras..."

# Start 4 receivers in background for each camera stream
cd build

echo "Camera 1 (Port 30000):"
./ZED_Streaming_Receiver --ip 192.168.1.254:30000 &
RECV1_PID=$!

echo "Camera 2 (Port 30002):"
./ZED_Streaming_Receiver --ip 192.168.1.254:30002 &
RECV2_PID=$!

echo "Camera 3 (Port 30004):"
./ZED_Streaming_Receiver --ip 192.168.1.254:30004 &
RECV3_PID=$!

echo "Camera 4 (Port 30006):"
./ZED_Streaming_Receiver --ip 192.168.1.254:30006 &
RECV4_PID=$!

echo ""
echo "All receivers started! PIDs: $RECV1_PID $RECV2_PID $RECV3_PID $RECV4_PID"
echo "Press Ctrl+C to stop all receivers"

# Wait for user interrupt
trap 'echo "Stopping all receivers..."; kill $RECV1_PID $RECV2_PID $RECV3_PID $RECV4_PID 2>/dev/null; exit' INT

# Keep script running
wait



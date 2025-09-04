#!/bin/bash
# Run the official PACMAN SDK receiver for each camera

echo "=== PACMAN Official SDK Receiver ==="
echo "Starting 4 receivers for cameras on Jetson 192.168.1.254"
echo ""

# Check if PACMAN Python API is available
python3 -c "import pyzed.sl as sl" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: PACMAN Python API not installed!"
    echo ""
    echo "To install:"
    echo "1. Fix apt dependencies: sudo apt --fix-broken install"
    echo "2. Install PACMAN API: python3 /usr/local/zed/get_python_api.py"
    echo ""
    exit 1
fi

echo "PACMAN Python API detected. Starting receivers..."

# Start receiver for each camera in separate terminals
echo "Camera 1 (Port 30000):"
python3 /usr/local/zed/samples/camera\ streaming/receiver/python/streaming_receiver.py --ip_address 192.168.1.254:30000 &
RECV1_PID=$!

echo "Camera 2 (Port 30002):"
python3 /usr/local/zed/samples/camera\ streaming/receiver/python/streaming_receiver.py --ip_address 192.168.1.254:30002 &
RECV2_PID=$!

echo "Camera 3 (Port 30004):"
python3 /usr/local/zed/samples/camera\ streaming/receiver/python/streaming_receiver.py --ip_address 192.168.1.254:30004 &
RECV3_PID=$!

echo "Camera 4 (Port 30006):"
python3 /usr/local/zed/samples/camera\ streaming/receiver/python/streaming_receiver.py --ip_address 192.168.1.254:30006 &
RECV4_PID=$!

echo ""
echo "All 4 PACMAN receivers started!"
echo "PIDs: $RECV1_PID $RECV2_PID $RECV3_PID $RECV4_PID"
echo "Press Ctrl+C to stop all receivers"

# Wait for user interrupt
trap 'echo "Stopping all receivers..."; kill $RECV1_PID $RECV2_PID $RECV3_PID $RECV4_PID 2>/dev/null; exit' INT

# Keep script running
wait



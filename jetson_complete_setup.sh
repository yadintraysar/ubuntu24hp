#!/bin/bash
# Complete PACMAN SDK Setup Script for NVIDIA Jetson
# Run this script on the Jetson device

set -e  # Exit on any error

echo "=== PACMAN SDK Jetson Setup Script ==="
echo "Starting setup on: $(hostname)"
echo "User: $(whoami)"
echo "Date: $(date)"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if PACMAN SDK is installed
check_zed_sdk() {
    if [ -d "/usr/local/zed" ]; then
        echo "✓ PACMAN SDK directory found"
        return 0
    else
        echo "✗ PACMAN SDK not found"
        return 1
    fi
}

# Function to download and install PACMAN SDK
install_zed_sdk() {
    echo "=== Installing PACMAN SDK ==="
    
    # Check if we're on Jetson
    if [ -f "/etc/nv_tegra_release" ]; then
        echo "✓ NVIDIA Jetson detected"
        JETPACK_VERSION=$(cat /etc/nv_tegra_release | grep -oP 'R\d+' | head -1)
        echo "JetPack version: $JETPACK_VERSION"
    else
        echo "⚠ Warning: Not detected as Jetson device"
    fi
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "Downloading PACMAN SDK for Jetson..."
    # Note: User needs to download the correct SDK version for their Jetson
    echo "Please download the PACMAN SDK for Jetson from:"
    echo "https://www.stereolabs.com/developers/release"
    echo "Look for: ZED SDK for Jetson (Ubuntu 22.04)"
    echo ""
    echo "Then run the installer manually:"
    echo "chmod +x ZED_SDK_*.run"
    echo "./ZED_SDK_*.run"
    echo ""
    read -p "Press Enter when you have installed the PACMAN SDK..."
}

# Function to create the streaming script
create_streaming_script() {
    echo "=== Creating Multi-Camera Streaming Script ==="
    
    SCRIPT_PATH="/home/$(whoami)/stream_pacman_cameras.py"
    
    cat > "$SCRIPT_PATH" << 'EOF'
#!/usr/bin/env python3
"""
PACMAN Multi-Camera Depth Streaming for Jetson
Streams up to 4 cameras with depth data enabled
"""

import pyzed.sl as sl
import threading
import signal
import time
import sys

exit_app = False

def signal_handler(signal, frame):
    global exit_app
    exit_app = True
    print("\nCtrl+C pressed. Exiting...")

def acquisition(zed, camera_id):
    """Acquisition thread for each camera"""
    infos = zed.get_camera_information()
    print(f"Camera {camera_id}: {infos.camera_model} S/N:{infos.serial_number} streaming...")
    
    frame_count = 0
    while not exit_app:
        if zed.grab() <= sl.ERROR_CODE.SUCCESS:
            frame_count += 1
            if frame_count % 300 == 0:  # Print every 10 seconds at 30fps
                print(f"Camera {camera_id}: {frame_count} frames processed")
        else:
            print(f"Camera {camera_id}: Grab error")
            time.sleep(0.1)
    
    print(f"Camera {camera_id}: Stopping stream (processed {frame_count} frames)")
    zed.disable_streaming()
    zed.close()

def open_camera_with_streaming(camera_id, serial_number, port):
    """Open camera and enable streaming with depth"""
    zed = sl.Camera()
    
    # Initialize with depth mode enabled
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.QUALITY  # Enable depth processing
    init_params.camera_resolution = sl.RESOLUTION.HD720  # 1280x720
    init_params.camera_fps = 30
    init_params.set_from_serial_number(serial_number)
    
    # Open camera
    print(f"Camera {camera_id}: Opening S/N:{serial_number}...")
    open_err = zed.open(init_params)
    if open_err != sl.ERROR_CODE.SUCCESS:
        print(f"Camera {camera_id}: Failed to open - {open_err}")
        return None
    
    # Enable streaming
    stream_params = sl.StreamingParameters()
    stream_params.port = port
    stream_params.codec = sl.STREAMING_CODEC.H264  # Use H264 for compatibility
    stream_params.bitrate = 4000  # 4 Mbps per camera
    
    print(f"Camera {camera_id}: Enabling streaming on port {port}...")
    stream_err = zed.enable_streaming(stream_params)
    if stream_err != sl.ERROR_CODE.SUCCESS:
        print(f"Camera {camera_id}: Failed to enable streaming - {stream_err}")
        zed.close()
        return None
    
    print(f"Camera {camera_id}: ✓ Streaming on port {port} with depth enabled")
    return zed

def main():
    global exit_app
    
    print("=== PACMAN Multi-Camera Depth Streaming ===")
    print(f"Host: {socket.gethostname()}")
    print(f"Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Get available cameras
    cameras = sl.Camera.get_device_list()
    print(f"\nFound {len(cameras)} cameras:")
    
    for i, cam in enumerate(cameras):
        print(f"  Camera {i+1}: {cam.camera_model} S/N:{cam.serial_number} State:{cam.camera_state}")
    
    if len(cameras) == 0:
        print("No cameras detected!")
        print("Check USB connections and run: lsusb | grep -i stereolabs")
        return 1
    
    # Use up to 4 cameras
    num_cameras = min(len(cameras), 4)
    base_port = 30000
    
    print(f"\nInitializing {num_cameras} cameras for streaming...")
    
    # Open cameras and start streaming
    zeds = []
    threads = []
    
    for i in range(num_cameras):
        port = base_port + (i * 2)  # Ports: 30000, 30002, 30004, 30006
        camera_id = i + 1
        serial_number = cameras[i].serial_number
        
        print(f"\n--- Setting up Camera {camera_id} ---")
        zed = open_camera_with_streaming(camera_id, serial_number, port)
        if zed is not None:
            zeds.append(zed)
            # Start acquisition thread
            thread = threading.Thread(target=acquisition, args=(zed, camera_id))
            thread.start()
            threads.append(thread)
            print(f"Camera {camera_id}: Thread started")
        else:
            print(f"Camera {camera_id}: Failed to initialize")
        
        time.sleep(2)  # Stagger camera initialization
    
    if len(zeds) == 0:
        print("No cameras successfully opened!")
        return 1
    
    # Set up signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    print(f"\n🚀 Successfully streaming {len(zeds)} cameras with depth data!")
    print(f"Jetson IP: {get_local_ip()}")
    print("Receiver can connect to:")
    for i, zed in enumerate(zeds):
        port = base_port + (i * 2)
        print(f"  Camera {i+1}: {get_local_ip()}:{port}")
    
    print(f"\nBandwidth usage: ~{len(zeds) * 4} Mbps")
    print("Press Ctrl+C to stop streaming")
    print("=" * 50)
    
    # Main loop
    start_time = time.time()
    while not exit_app:
        time.sleep(1)
        if int(time.time() - start_time) % 30 == 0:  # Status every 30 seconds
            print(f"Status: {len(zeds)} cameras streaming for {int(time.time() - start_time)} seconds")
    
    # Wait for threads to finish
    print("\nStopping all cameras...")
    for thread in threads:
        thread.join(timeout=5)
    
    print("✓ All cameras stopped. Streaming session ended.")
    return 0

def get_local_ip():
    """Get local IP address"""
    import socket
    try:
        # Connect to a remote server to get local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "localhost"

if __name__ == "__main__":
    import socket
    sys.exit(main())
EOF

    chmod +x "$SCRIPT_PATH"
    echo "✓ Streaming script created: $SCRIPT_PATH"
}

# Function to test cameras
test_cameras() {
    echo "=== Testing Camera Detection ==="
    
    if command_exists python3; then
        python3 -c "
import pyzed.sl as sl
cameras = sl.Camera.get_device_list()
print(f'Found {len(cameras)} cameras:')
for i, cam in enumerate(cameras):
    print(f'  {i+1}: {cam.camera_model} S/N:{cam.serial_number}')
"
    else
        echo "Python3 not available for camera test"
    fi
}

# Function to configure firewall
configure_firewall() {
    echo "=== Configuring Firewall ==="
    
    if command_exists ufw; then
        echo "Opening streaming ports 30000-30007..."
        sudo ufw allow 30000:30007/tcp
        sudo ufw status | grep 30000 || echo "Firewall rules may not be active"
    else
        echo "UFW not available, check firewall manually"
    fi
}

# Function to show network info
show_network_info() {
    echo "=== Network Information ==="
    echo "Hostname: $(hostname)"
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    echo "Network interfaces:"
    ip addr show | grep -E "(inet |UP)" | head -10
}

# Main execution
main() {
    echo "Starting PACMAN SDK setup on Jetson..."
    
    # Check if PACMAN SDK is installed
    if ! check_zed_sdk; then
        echo "PACMAN SDK not found. Please install it first."
        install_zed_sdk
        
        # Check again after installation prompt
        if ! check_zed_sdk; then
            echo "PACMAN SDK still not found. Please install manually and re-run this script."
            exit 1
        fi
    fi
    
    echo "✓ PACMAN SDK found"
    
    # Create streaming script
    create_streaming_script
    
    # Test cameras
    test_cameras
    
    # Configure firewall
    configure_firewall
    
    # Show network info
    show_network_info
    
    echo ""
    echo "=== Setup Complete! ==="
    echo "To start streaming:"
    echo "  python3 ~/stream_pacman_cameras.py"
    echo ""
    echo "On the receiver computer, run:"
    echo "  python3 pacman_depth_receiver.py --jetson-ip $(hostname -I | awk '{print $1}')"
    echo ""
    echo "Streaming ports: 30000, 30002, 30004, 30006"
}

# Run main function
main "$@"



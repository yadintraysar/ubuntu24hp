# Jetson Setup Commands for PACMAN Streaming

## SSH into the Jetson
```bash
ssh user@192.168.1.254
# Replace 'user' with the actual username on your Jetson
```

## 1. Install PACMAN SDK on Jetson

### Download and Install
```bash
# Download PACMAN SDK for Jetson (check stereolabs.com for latest version)
# For Jetson with Ubuntu Jammy (22.04), use something like:
wget https://download.stereolabs.com/zedsdk/4.1/l4t35.4/jetsons

# Make it executable and install
chmod +x ZED_SDK_*.run
./ZED_SDK_*.run

# Follow the installation prompts
# Choose YES for Python API installation
# Choose YES for samples installation
```

### Verify Installation
```bash
ls /usr/local/zed/
# Should show: doc, firmware, include, lib, resources, samples, settings, tools

# Test camera detection
/usr/local/zed/tools/ZED_Explorer
# This should detect all 4 cameras
```

## 2. Configure Multi-Camera Streaming

### Navigate to Multi-Sender Sample
```bash
cd /usr/local/zed/samples/camera\ streaming/multi_sender/python/
ls -la
# Should show: streaming_senders.py, README.md
```

### Create Custom Streaming Script
```bash
# Create a custom script for 4-camera depth streaming
cat > stream_depth_cameras.py << 'EOF'
#!/usr/bin/env python3
"""
PACMAN Multi-Camera Depth Streaming for Jetson
Streams 4 cameras with depth data enabled
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
    
    while not exit_app:
        if zed.grab() <= sl.ERROR_CODE.SUCCESS:
            # Camera is grabbing frames and streaming
            pass
        else:
            print(f"Camera {camera_id}: Grab error")
            time.sleep(0.1)
    
    print(f"Camera {camera_id}: Stopping stream")
    zed.disable_streaming()
    zed.close()

def open_camera_with_streaming(camera_id, serial_number, port):
    """Open camera and enable streaming with depth"""
    zed = sl.Camera()
    
    # Initialize with depth mode enabled
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.QUALITY  # Enable depth processing
    init_params.camera_resolution = sl.RESOLUTION.HD720
    init_params.camera_fps = 30
    init_params.set_from_serial_number(serial_number)
    
    # Open camera
    open_err = zed.open(init_params)
    if open_err != sl.ERROR_CODE.SUCCESS:
        print(f"Camera {camera_id}: Failed to open - {open_err}")
        return None
    
    # Enable streaming
    stream_params = sl.StreamingParameters()
    stream_params.port = port
    stream_params.codec = sl.STREAMING_CODEC.H264  # Use H264 for compatibility
    stream_params.bitrate = 4000  # 4 Mbps per camera
    
    stream_err = zed.enable_streaming(stream_params)
    if stream_err != sl.ERROR_CODE.SUCCESS:
        print(f"Camera {camera_id}: Failed to enable streaming - {stream_err}")
        zed.close()
        return None
    
    print(f"Camera {camera_id}: Streaming on port {port} with depth enabled")
    return zed

def main():
    global exit_app
    
    print("=== PACMAN Multi-Camera Depth Streaming ===")
    
    # Get available cameras
    cameras = sl.Camera.get_device_list()
    print(f"Found {len(cameras)} cameras:")
    
    for i, cam in enumerate(cameras):
        print(f"  Camera {i+1}: {cam.camera_model} S/N:{cam.serial_number}")
    
    if len(cameras) == 0:
        print("No cameras detected!")
        return 1
    
    # Use up to 4 cameras
    num_cameras = min(len(cameras), 4)
    base_port = 30000
    
    # Open cameras and start streaming
    zeds = []
    threads = []
    
    for i in range(num_cameras):
        port = base_port + (i * 2)  # Ports: 30000, 30002, 30004, 30006
        camera_id = i + 1
        serial_number = cameras[i].serial_number
        
        zed = open_camera_with_streaming(camera_id, serial_number, port)
        if zed is not None:
            zeds.append(zed)
            # Start acquisition thread
            thread = threading.Thread(target=acquisition, args=(zed, camera_id))
            thread.start()
            threads.append(thread)
        
        time.sleep(1)  # Stagger camera initialization
    
    if len(zeds) == 0:
        print("No cameras successfully opened!")
        return 1
    
    # Set up signal handler
    signal.signal(signal.SIGINT, signal_handler)
    print(f"\nStreaming {len(zeds)} cameras with depth data...")
    print("Receiver can connect to:")
    for i, zed in enumerate(zeds):
        port = base_port + (i * 2)
        print(f"  Camera {i+1}: 192.168.1.254:{port}")
    print("\nPress Ctrl+C to stop streaming")
    
    # Main loop
    while not exit_app:
        time.sleep(0.1)
    
    # Wait for threads to finish
    print("Stopping all cameras...")
    for thread in threads:
        thread.join(timeout=5)
    
    print("Streaming stopped.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x stream_depth_cameras.py
```

## 3. Configure Firewall
```bash
# Open the streaming ports
sudo ufw allow 30000:30007/tcp
sudo ufw status
```

## 4. Start Depth Streaming
```bash
# Run the depth streaming script
python3 stream_depth_cameras.py
```

## 5. Verify Streaming is Active
```bash
# In another terminal, check if ports are listening
ss -tlnp | grep -E ":(30000|30002|30004|30006)"
# Should show the ports in LISTEN state
```

## Expected Output
When running the streaming script, you should see:
```
=== PACMAN Multi-Camera Depth Streaming ===
Found 4 cameras:
  Camera 1: ZED 2i S/N:12345
  Camera 2: ZED 2i S/N:12346
  Camera 3: ZED 2i S/N:12347
  Camera 4: ZED 2i S/N:12348
Camera 1: Streaming on port 30000 with depth enabled
Camera 2: Streaming on port 30002 with depth enabled
Camera 3: Streaming on port 30004 with depth enabled
Camera 4: Streaming on port 30006 with depth enabled

Streaming 4 cameras with depth data...
Receiver can connect to:
  Camera 1: 192.168.1.254:30000
  Camera 2: 192.168.1.254:30002
  Camera 3: 192.168.1.254:30004
  Camera 4: 192.168.1.254:30006

Press Ctrl+C to stop streaming
```

## Troubleshooting

### If cameras not detected:
```bash
# Check USB connections
lsusb | grep -i stereolabs

# Check camera permissions
sudo chmod 666 /dev/video*

# Restart udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### If streaming fails:
```bash
# Check if ports are available
sudo netstat -tlnp | grep -E ":(30000|30002|30004|30006)"

# Check system resources
htop
nvidia-smi  # If available on Jetson
```

### If Python API missing:
```bash
# Install Python API
python3 /usr/local/zed/get_python_api.py

# Or use pip if available
pip3 install pyzed
```

## Next Steps
Once streaming is active on the Jetson, you can start the receiver on your Ubuntu 24 computer:

```bash
# On Ubuntu 24 computer
cd /home/yadinlinux/Documents/SDKstream/
python3 pacman_depth_receiver.py --jetson-ip 192.168.1.254
```



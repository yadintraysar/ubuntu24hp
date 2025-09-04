# PACMAN Multi-Camera Depth Streaming System

## Overview
This system streams depth maps from 4 PACMAN cameras connected to an NVIDIA Jetson device to your Ubuntu 24 computer over the local network.

## Hardware Setup
- **NVIDIA Jetson**: Running Ubuntu Jammy Jellyfish with 4 PACMAN cameras connected
- **Ubuntu 24 Computer**: Intel Core i7 + NVIDIA GeForce RTX (receiver)
- **Network**: Both devices on the same local network

## Current Status
✅ PACMAN SDK v5.0.5 installed on Ubuntu 24 computer  
✅ CUDA 12.8 and TensorRT 10.9 installed  
✅ Receiver scripts created and ready  
⚠️ Python API needs manual setup (dependency issues)  
⚠️ Need Jetson IP address for testing  

## Execution Plan

### Phase 1: Complete Local Setup ✅
1. **Install PACMAN SDK** - ✅ DONE
   - SDK installed in `/usr/local/zed/`
   - CUDA 12.8 installed for RTX GPU acceleration
   - Core libraries and tools available

2. **Setup Python Environment** - ⚠️ PARTIAL
   ```bash
   # Install Python API (when pip issues resolved)
   python3 /usr/local/zed/get_python_api.py
   
   # Alternative: Use C++ samples directly
   cd /usr/local/zed/samples/camera\ streaming/receiver/cpp/
   mkdir build && cd build
   cmake .. && make
   ```

### Phase 2: Configure Jetson (Remote via SSH)
1. **SSH into Jetson**
   ```bash
   ssh user@<JETSON_IP>
   ```

2. **Install PACMAN SDK on Jetson**
   - Download appropriate Jetson version from stereolabs.com
   - Install with depth sensing enabled

3. **Setup Multi-Camera Streaming**
   - Use `/usr/local/zed/samples/camera streaming/multi_sender/`
   - Configure 4 cameras on ports 30000, 30002, 30004, 30006
   - Enable depth mode: `DEPTH_MODE.QUALITY`

4. **Start Streaming Service**
   ```bash
   cd /usr/local/zed/samples/camera\ streaming/multi_sender/python/
   python3 streaming_senders.py
   ```

### Phase 3: Network Configuration
1. **Firewall Setup**
   ```bash
   # On both Jetson and Ubuntu 24
   sudo ufw allow 30000:30007/tcp
   ```

2. **Network Testing**
   ```bash
   # Test connectivity
   python3 test_setup.py
   ```

### Phase 4: Start Depth Streaming

#### **On Jetson (Sender) - Required Steps:**

1. **SSH into Jetson**
   ```bash
   ssh nvidia@192.168.1.254
   ```

2. **Start Multi-Camera Streaming**
   ```bash
   cd '/usr/local/zed/samples/camera streaming/multi_sender/python'
   python3 streaming_senders.py
   ```

#### **Troubleshooting Jetson Streaming:**

If cameras show "state: NOT AVAILABLE" or "CAMERA STREAM FAILED TO START", run this diagnostic:

```bash
ssh -o StrictHostKeyChecking=no nvidia@192.168.1.254 "echo '=== What is using cameras? ==='; sudo lsof /dev/video* 2>/dev/null || echo 'no /dev/video*'; echo; echo '=== Any camera processes? ==='; ps aux | grep -E 'camera|zed|argus|nvargus|streaming' | grep -v grep || echo 'none found'; echo; echo '=== ZED daemon status ==='; systemctl status zed_x_daemon --no-pager -l || echo 'daemon not found'"
```

**If processes are found, kill them:**
```bash
ssh nvidia@192.168.1.254 "pkill -f 'streaming_senders.py'; sudo fuser -kv /dev/video*"
```

**Then restart streaming:**
```bash
ssh nvidia@192.168.1.254 "cd '/usr/local/zed/samples/camera streaming/multi_sender/python' && python3 streaming_senders.py"
```

#### **On Ubuntu 24 (Receiver) - Multiple Options:**

1. **Depth Map Visualization (NEURAL)**
   ```bash
   source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman
   python3 streaming_receiver_depth.py --ip_address 192.168.1.254:30000 --show_left --max_range_m 5
   ```

2. **3D Point Cloud (NEURAL_PLUS with filtering)**
   ```bash
   source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman
   python3 streaming_receiver_pointcloud.py --ip_address 192.168.1.254:30000 --stride 2 --max_range_m 4
   ```

3. **Body Tracking (NEURAL)**
   ```bash
   source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman
   python3 streaming_receiver_bodytracking.py --ip_address 192.168.1.254:30000 --confidence 40
   ```

4. **Spatial Mapping (3D Mesh Reconstruction)**
   ```bash
   source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman
   python3 "/usr/local/zed/samples/spatial mapping/spatial mapping/python/spatial_mapping.py" --ip_address 192.168.1.254:30000 --build_mesh
   ```

## NEURAL Depth Modes

Based on testing, we use different NEURAL depth modes for different applications:

### **NEURAL_LIGHT** (Fastest)
- **Range**: 0.3-5m
- **Best for**: Multi-camera setups, real-time applications
- **Accuracy**: < 1% error (0.3-3m), < 3% error (3-5m)
- **Use case**: Fast object detection, obstacle avoidance

### **NEURAL** (Balanced) 
- **Range**: 0.3-9m  
- **Best for**: General depth sensing, body tracking
- **Accuracy**: < 1% error (0.3-4m), < 2.5% error (4-6m), < 4% error (6-9m)
- **Use case**: Most applications, good balance of speed/quality

### **NEURAL_PLUS** (Highest Quality)
- **Range**: 0.3-12m
- **Best for**: 3D reconstruction, detailed point clouds
- **Accuracy**: < 1% error (0.3-9m), < 2% error (9-12m)  
- **Use case**: Spatial mapping, high-precision applications

## File Structure
```
/home/yadinlinux/Documents/SDKstream/
├── streaming_receiver_depth.py           # NEURAL depth map visualization
├── streaming_receiver_pointcloud.py      # NEURAL_PLUS 3D point cloud (interactive)
├── streaming_receiver_bodytracking.py    # NEURAL body/skeleton tracking
├── streaming_receiver_spatial_mapping.py # Real-time 3D mesh reconstruction
├── test_setup.py                         # Setup verification script
└── README.md                             # This file

/usr/local/zed/                           # PACMAN SDK installation
├── samples/camera streaming/             # Official streaming examples
├── samples/spatial mapping/              # 3D reconstruction samples
├── samples/body tracking/                # Human tracking samples
├── samples/object detection/             # Multi-class object detection
├── lib/                                  # SDK libraries
└── tools/                                # SDK tools
```

## Key Features

### Receiver Script (`pacman_depth_receiver.py`)
- Connects to 4 camera streams simultaneously
- Extracts RGB images and depth maps
- Real-time processing with threading
- Automatic depth map saving every 30 seconds
- Status monitoring and error handling
- Hardware acceleration via RTX GPU

### Network Configuration
- **Ports**: 30000, 30002, 30004, 30006 (even numbers for streaming)
- **Encoding**: H.264 for compatibility with RTX hardware acceleration
- **Resolution**: HD720 (1280x720) @ 30 FPS per camera
- **Total Bandwidth**: ~16 Mbps (4 cameras × 4 Mbps each)

### Performance Optimization
- Hardware encoding/decoding on both devices
- Multi-threaded receiver for concurrent streams
- Adaptive bitrate based on network conditions
- Frame dropping for network congestion
- GPU memory management for multiple streams

## Usage Examples

### Basic Usage
```bash
# Start receiver for Jetson at 192.168.1.100
python3 pacman_depth_receiver.py --jetson-ip 192.168.1.100
```

### Advanced Usage
```bash
# Custom configuration
python3 pacman_depth_receiver.py \
    --jetson-ip 192.168.1.100 \
    --base-port 30000 \
    --num-cameras 4 \
    --save-interval 60
```

### Test Setup
```bash
# Verify installation and connectivity
python3 test_setup.py
```

## Troubleshooting

### **Jetson Camera Issues**

#### **"CAMERA STREAM FAILED TO START" Error**
This is the most common issue. Follow these steps:

1. **Check what's using cameras:**
   ```bash
   ssh -o StrictHostKeyChecking=no nvidia@192.168.1.254 "echo '=== What is using cameras? ==='; sudo lsof /dev/video* 2>/dev/null || echo 'no /dev/video*'; echo; echo '=== Any camera processes? ==='; ps aux | grep -E 'camera|zed|argus|nvargus|streaming' | grep -v grep || echo 'none found'; echo; echo '=== ZED daemon status ==='; systemctl status zed_x_daemon --no-pager -l || echo 'daemon not found'"
   ```

2. **Kill blocking processes:**
   ```bash
   ssh nvidia@192.168.1.254 "pkill -f 'streaming_senders.py'; sudo fuser -kv /dev/video*"
   ```

3. **Restart streaming:**
   ```bash
   ssh nvidia@192.168.1.254 "cd '/usr/local/zed/samples/camera streaming/multi_sender/python' && python3 streaming_senders.py"
   ```

#### **Cameras show "NOT AVAILABLE" state**
- Usually means another process has exclusive access
- Kill all camera processes and restart
- If persistent, reboot the Jetson

### **Ubuntu 24 Receiver Issues**

#### **"pyzed not available" / Simulation mode**
1. **Install PACMAN Python API in isolated environment:**
   ```bash
   source ~/miniforge3/etc/profile.d/conda.sh && conda activate pacman
   pip install /home/yadinlinux/Documents/SDKstream/pyzed-5.0-cp312-cp312-linux_x86_64.whl
   ```

2. **Install missing dependencies:**
   ```bash
   sudo apt install -y libturbojpeg curl
   ```

#### **"libcuda.so.1: cannot open" Error**
- Install NVIDIA drivers: `sudo ubuntu-drivers autoinstall`
- Reboot after installation
- Verify with: `nvidia-smi`

#### **"NEURAL TRT NOT FOUND" Error**
- TensorRT version mismatch
- Solution: Re-run ZED SDK installer to install matching TensorRT 10.9
- Command: `./ZED_SDK_Ubuntu24_cuda12.8_tensorrt10.9_v5.0.5.zstd.run --accept --quiet`

### **Network/Streaming Issues**

#### **"Corrupted frame chunk" warnings**
- Network packet loss due to bandwidth/WiFi issues
- Solutions:
  - Use wired Ethernet connection
  - Reduce streaming resolution on Jetson
  - Lower bitrate in streaming parameters

#### **"Connection refused" to ports 30000-30006**
- Jetson streaming not active
- Check Jetson streaming process is running
- Verify firewall allows ports: `sudo ufw allow 30000:30007/tcp`

### **Performance Issues**

#### **Low FPS or high CPU usage**
- Switch to NEURAL_LIGHT for multi-camera setups
- Increase stride in point cloud viewer: `--stride 4`
- Reduce max range: `--max_range_m 3`

#### **Point cloud looks noisy**
- Use NEURAL_PLUS for highest accuracy
- Reduce max range to 3-5 meters
- Ensure good lighting and textured surfaces
- Use noise filtering (already enabled in pointcloud viewer)

### Performance Monitoring
- Monitor GPU usage: `nvidia-smi -l 1`
- Check network usage: `iftop` or `nethogs`
- Monitor system resources: `htop`

## Next Steps
1. Get Jetson IP address from network admin
2. SSH into Jetson and install PACMAN SDK
3. Configure multi-camera streaming on Jetson
4. Test end-to-end depth streaming
5. Optimize performance based on actual usage

## Hardware Specifications
- **RTX GPU**: Hardware H.264/H.265 encode/decode
- **Intel Core i7**: Multi-core processing for concurrent streams
- **Network**: Gigabit Ethernet recommended for 4-camera streaming
- **Storage**: SSD recommended for depth map recording

## Contact & Support
- PACMAN SDK Documentation: [Stereolabs Docs](https://www.stereolabs.com/docs/)
- SDK Samples: `/usr/local/zed/samples/`
- Community Forum: [Stereolabs Community](https://community.stereolabs.com/)



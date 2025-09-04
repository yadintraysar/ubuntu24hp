#!/usr/bin/env python3
"""
PACMAN Multi-Camera Depth Map Receiver
Receives depth map streams from NVIDIA Jetson with 4 cameras
"""

import sys
import threading
import time
import signal
import argparse
import socket
import cv2
import numpy as np
from datetime import datetime

# We'll import pyzed when available, but provide fallback for now
try:
    import pyzed.sl as sl
    PYZED_AVAILABLE = True
except ImportError:
    print("Warning: pyzed not available. Install it using: python3 /usr/local/zed/get_python_api.py")
    PYZED_AVAILABLE = False
    
    # Create mock classes for development
    class sl:
        class InitParameters:
            def __init__(self):
                self.depth_mode = None
                self.sdk_verbose = 1
            def set_from_stream(self, ip, port):
                pass
        
        class Camera:
            def open(self, params): return 0
            def grab(self, runtime): return 0
            def retrieve_image(self, mat, view): pass
            def retrieve_measure(self, mat, measure): pass
            def close(self): pass
            def get_camera_information(self): 
                class Info:
                    camera_model = "PACMAN"
                    serial_number = 12345
                return Info()
        
        class Mat:
            def get_data(self): return np.zeros((480, 640, 3), dtype=np.uint8)
        
        class RuntimeParameters: pass
        
        class DEPTH_MODE:
            ULTRA = "ULTRA"
            QUALITY = "QUALITY" 
            PERFORMANCE = "PERFORMANCE"
        
        class VIEW:
            LEFT = "LEFT"
            RIGHT = "RIGHT"
            
        class MEASURE:
            DEPTH = "DEPTH"
            XYZ = "XYZ"
            
        class ERROR_CODE:
            SUCCESS = 0

# Global variables
exit_app = False
camera_threads = []
depth_data = {}

def signal_handler(signal, frame):
    """Handle Ctrl+C to properly exit"""
    global exit_app
    exit_app = True
    print("\nCtrl+C pressed. Exiting...")

def validate_ip_port(ip_port_str):
    """Validate IP:PORT format"""
    try:
        host, port = ip_port_str.split(':')
        socket.inet_aton(host)
        port = int(port)
        if port < 1024 or port > 65535:
            raise ValueError("Port must be between 1024 and 65535")
        return host, port
    except (socket.error, ValueError) as e:
        raise argparse.ArgumentTypeError(f"Invalid IP:PORT format '{ip_port_str}': {e}")

def save_depth_map(depth_data, camera_id, timestamp):
    """Save depth map to file"""
    filename = f"depth_camera_{camera_id}_{timestamp.strftime('%Y%m%d_%H%M%S')}.png"
    # Normalize depth data for saving as image
    depth_normalized = cv2.normalize(depth_data, None, 0, 255, cv2.NORM_MINMAX, dtype=cv2.CV_8U)
    cv2.imwrite(filename, depth_normalized)
    print(f"Saved depth map: {filename}")

def camera_receiver_thread(camera_id, jetson_ip, jetson_port):
    """Thread function to receive stream from one camera"""
    global exit_app, depth_data
    
    print(f"Starting receiver for Camera {camera_id} at {jetson_ip}:{jetson_port}")
    
    if not PYZED_AVAILABLE:
        print(f"Camera {camera_id}: PACMAN SDK not available, simulating...")
        while not exit_app:
            # Simulate receiving depth data
            depth_data[camera_id] = {
                'timestamp': datetime.now(),
                'depth_map': np.random.randint(0, 255, (480, 640), dtype=np.uint8),
                'status': 'simulated'
            }
            time.sleep(0.1)  # 10 FPS simulation
        return
    
    # Initialize PACMAN camera for streaming
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.QUALITY  # Enable depth processing
    init_params.sdk_verbose = 1
    init_params.set_from_stream(jetson_ip, jetson_port)
    
    camera = sl.Camera()
    status = camera.open(init_params)
    
    if status != sl.ERROR_CODE.SUCCESS:
        print(f"Camera {camera_id}: Failed to open stream from {jetson_ip}:{jetson_port} - {status}")
        return
    
    # Get camera info
    cam_info = camera.get_camera_information()
    print(f"Camera {camera_id}: Connected to {cam_info.camera_model} S/N:{cam_info.serial_number}")
    
    # Create matrices for image and depth data
    image_mat = sl.Mat()
    depth_mat = sl.Mat()
    runtime_params = sl.RuntimeParameters()
    
    frame_count = 0
    last_save_time = time.time()
    
    while not exit_app:
        # Grab frame
        grab_status = camera.grab(runtime_params)
        
        if grab_status <= sl.ERROR_CODE.SUCCESS:
            # Retrieve RGB image
            camera.retrieve_image(image_mat, sl.VIEW.LEFT)
            rgb_data = image_mat.get_data()
            
            # Retrieve depth map
            camera.retrieve_measure(depth_mat, sl.MEASURE.DEPTH)
            depth_map = depth_mat.get_data()
            
            # Store data globally
            depth_data[camera_id] = {
                'timestamp': datetime.now(),
                'rgb_image': rgb_data,
                'depth_map': depth_map,
                'frame_count': frame_count,
                'status': 'active'
            }
            
            frame_count += 1
            
            # Save depth map every 30 seconds
            current_time = time.time()
            if current_time - last_save_time > 30:
                save_depth_map(depth_map, camera_id, datetime.now())
                last_save_time = current_time
                
        else:
            print(f"Camera {camera_id}: Error during grab - {grab_status}")
            time.sleep(0.1)
    
    print(f"Camera {camera_id}: Closing connection")
    camera.close()

def display_status():
    """Display status of all camera streams"""
    while not exit_app:
        print(f"\n=== PACMAN Depth Receiver Status - {datetime.now().strftime('%H:%M:%S')} ===")
        
        if not depth_data:
            print("No camera data received yet...")
        else:
            for cam_id in sorted(depth_data.keys()):
                data = depth_data[cam_id]
                status = data.get('status', 'unknown')
                frame_count = data.get('frame_count', 0)
                timestamp = data.get('timestamp', 'N/A')
                
                if hasattr(timestamp, 'strftime'):
                    time_str = timestamp.strftime('%H:%M:%S')
                else:
                    time_str = str(timestamp)
                
                print(f"Camera {cam_id}: {status} | Frames: {frame_count} | Last: {time_str}")
                
                # Display depth map stats if available
                depth_map = data.get('depth_map')
                if depth_map is not None and hasattr(depth_map, 'shape'):
                    if len(depth_map.shape) >= 2:
                        print(f"  Depth Map: {depth_map.shape[1]}x{depth_map.shape[0]} | "
                              f"Min: {np.min(depth_map):.2f}mm | Max: {np.max(depth_map):.2f}mm")
        
        time.sleep(5)  # Update every 5 seconds

def main():
    global exit_app, camera_threads
    
    parser = argparse.ArgumentParser(description='PACMAN Multi-Camera Depth Map Receiver')
    parser.add_argument('--jetson-ip', type=str, required=True,
                       help='IP address of NVIDIA Jetson device')
    parser.add_argument('--base-port', type=int, default=30000,
                       help='Base port number (default: 30000). Cameras use ports 30000, 30002, 30004, 30006')
    parser.add_argument('--num-cameras', type=int, default=4,
                       help='Number of cameras to receive (default: 4)')
    parser.add_argument('--save-interval', type=int, default=30,
                       help='Interval to save depth maps in seconds (default: 30)')
    
    args = parser.parse_args()
    
    # Validate Jetson IP
    try:
        socket.inet_aton(args.jetson_ip)
    except socket.error:
        print(f"Invalid Jetson IP address: {args.jetson_ip}")
        return 1
    
    print("=== PACMAN Multi-Camera Depth Receiver ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print(f"Base Port: {args.base_port}")
    print(f"Number of Cameras: {args.num_cameras}")
    print(f"PACMAN SDK Available: {PYZED_AVAILABLE}")
    
    if not PYZED_AVAILABLE:
        print("\nWARNING: Running in simulation mode!")
        print("Install PACMAN Python API with: python3 /usr/local/zed/get_python_api.py")
    
    # Set up signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start receiver threads for each camera
    for cam_id in range(args.num_cameras):
        port = args.base_port + (cam_id * 2)  # Ports: 30000, 30002, 30004, 30006
        thread = threading.Thread(
            target=camera_receiver_thread,
            args=(cam_id + 1, args.jetson_ip, port),
            name=f"Camera-{cam_id + 1}"
        )
        thread.start()
        camera_threads.append(thread)
        time.sleep(1)  # Stagger connection attempts
    
    # Start status display thread
    status_thread = threading.Thread(target=display_status, name="StatusDisplay")
    status_thread.start()
    
    print(f"\nReceiving depth streams from {args.num_cameras} cameras...")
    print("Press Ctrl+C to exit")
    
    # Main loop
    try:
        while not exit_app:
            time.sleep(0.1)
    except KeyboardInterrupt:
        exit_app = True
    
    # Wait for all threads to finish
    print("\nShutting down...")
    for thread in camera_threads:
        thread.join(timeout=5)
    
    status_thread.join(timeout=2)
    
    print("PACMAN Depth Receiver stopped.")
    return 0

if __name__ == "__main__":
    sys.exit(main())



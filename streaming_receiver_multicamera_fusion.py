#!/usr/bin/env python3
"""
PACMAN SDK - Multi-Camera Streaming Fusion Receiver

Connects to multiple PACMAN camera streams and displays them simultaneously
with synchronized depth sensing and optional point cloud fusion.

Based on PACMAN SDK multi-camera examples.
"""

import argparse
import cv2
import numpy as np
import pyzed.sl as sl
import sys
import time
import threading
import queue


class MultiCameraStreamingReceiver:
    def __init__(self, jetson_ip, base_port=30000, num_cameras=4):
        self.jetson_ip = jetson_ip
        self.base_port = base_port
        self.num_cameras = num_cameras
        self.cameras = []
        self.threads = []
        self.image_queues = []
        self.depth_queues = []
        self.running = True
        
        # Initialize queues for each camera
        for i in range(num_cameras):
            self.image_queues.append(queue.Queue(maxsize=2))
            self.depth_queues.append(queue.Queue(maxsize=2))

    def camera_thread(self, camera_id, port):
        """Thread function for each camera stream"""
        print(f"Starting Camera {camera_id} thread on port {port}")
        
        # Initialize camera for streaming
        init_params = sl.InitParameters()
        init_params.depth_mode = sl.DEPTH_MODE.NEURAL
        init_params.coordinate_units = sl.UNIT.METER
        init_params.sdk_verbose = 1
        init_params.set_from_stream(self.jetson_ip, port)
        
        cam = sl.Camera()
        status = cam.open(init_params)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Camera {camera_id}: Failed to open stream - {status}")
            return
        
        # Get camera info
        cam_info = cam.get_camera_information()
        print(f"Camera {camera_id}: Connected to {cam_info.camera_model} S/N:{cam_info.serial_number}")
        
        # Create data containers
        image_mat = sl.Mat()
        depth_mat = sl.Mat()
        runtime_params = sl.RuntimeParameters()
        runtime_params.confidence_threshold = 50
        
        frame_count = 0
        
        while self.running:
            if cam.grab(runtime_params) == sl.ERROR_CODE.SUCCESS:
                # Retrieve image and depth
                cam.retrieve_image(image_mat, sl.VIEW.LEFT)
                cam.retrieve_measure(depth_mat, sl.MEASURE.DEPTH)
                
                # Get data as numpy arrays
                image_data = image_mat.get_data()
                depth_data = depth_mat.get_data()
                
                # Add timestamp and camera info
                timestamp = cam.get_timestamp(sl.TIME_REFERENCE.CURRENT).data_ns
                
                frame_data = {
                    'camera_id': camera_id,
                    'image': image_data,
                    'depth': depth_data,
                    'timestamp': timestamp,
                    'frame_count': frame_count,
                    'resolution': f"{cam_info.camera_configuration.resolution.width}x{cam_info.camera_configuration.resolution.height}"
                }
                
                # Queue data (non-blocking)
                try:
                    self.image_queues[camera_id - 1].put_nowait(frame_data)
                    self.depth_queues[camera_id - 1].put_nowait(frame_data)
                except queue.Full:
                    # Skip frame if queue is full
                    pass
                
                frame_count += 1
            else:
                time.sleep(0.01)
        
        print(f"Camera {camera_id}: Closing (processed {frame_count} frames)")
        cam.close()

    def start_cameras(self):
        """Start all camera threads"""
        for i in range(self.num_cameras):
            camera_id = i + 1
            port = self.base_port + (i * 2)  # 30000, 30002, 30004, 30006
            
            thread = threading.Thread(
                target=self.camera_thread,
                args=(camera_id, port),
                name=f"Camera-{camera_id}"
            )
            thread.start()
            self.threads.append(thread)
            time.sleep(1)  # Stagger connections

    def run_display(self):
        """Main display loop showing all cameras"""
        print(f"\nMulti-Camera Fusion Display")
        print("Controls:")
        print("- 'q': Quit")
        print("- 'd': Toggle depth view")
        print("- 'f': Show FPS info")
        print("- '1-4': Focus on specific camera")
        
        show_depth = False
        show_fps = True
        focus_camera = None
        
        # Create display windows
        window_names = [f"Camera {i+1}" for i in range(self.num_cameras)]
        for name in window_names:
            cv2.namedWindow(name, cv2.WINDOW_AUTOSIZE)
        
        last_fps_time = time.time()
        fps_counters = [0] * self.num_cameras
        
        while self.running:
            current_time = time.time()
            
            # Process each camera
            for i in range(self.num_cameras):
                try:
                    # Get latest frame
                    if show_depth:
                        frame_data = self.depth_queues[i].get_nowait()
                        display_data = frame_data['depth']
                        # Normalize depth for display
                        if display_data is not None and display_data.size > 0:
                            depth_norm = cv2.normalize(display_data, None, 0, 255, cv2.NORM_MINMAX, dtype=cv2.CV_8U)
                            display_data = cv2.applyColorMap(depth_norm, cv2.COLORMAP_JET)
                    else:
                        frame_data = self.image_queues[i].get_nowait()
                        display_data = frame_data['image']
                    
                    if display_data is not None and display_data.size > 0:
                        # Add camera info overlay
                        camera_id = frame_data['camera_id']
                        frame_count = frame_data['frame_count']
                        resolution = frame_data['resolution']
                        
                        # Resize for display if too large
                        if display_data.shape[1] > 640:
                            scale = 640 / display_data.shape[1]
                            new_width = int(display_data.shape[1] * scale)
                            new_height = int(display_data.shape[0] * scale)
                            display_data = cv2.resize(display_data, (new_width, new_height))
                        
                        # Add text overlay
                        info_text = f"Cam {camera_id} | Frame: {frame_count}"
                        if show_fps:
                            fps_counters[i] += 1
                            if current_time - last_fps_time >= 1.0:
                                fps = fps_counters[i]
                                info_text += f" | FPS: {fps}"
                        
                        cv2.putText(display_data, info_text, (10, 30), 
                                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
                        
                        # Show specific camera in focus mode
                        if focus_camera is None or focus_camera == camera_id:
                            cv2.imshow(window_names[i], display_data)
                        
                except queue.Empty:
                    # No new frame available
                    pass
            
            # Reset FPS counters every second
            if current_time - last_fps_time >= 1.0:
                if show_fps:
                    total_fps = sum(fps_counters)
                    print(f"Total FPS: {total_fps} | Cameras: {fps_counters}")
                fps_counters = [0] * self.num_cameras
                last_fps_time = current_time
            
            # Handle keyboard input
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('d'):
                show_depth = not show_depth
                print(f"Depth view: {'ON' if show_depth else 'OFF'}")
            elif key == ord('f'):
                show_fps = not show_fps
                print(f"FPS display: {'ON' if show_fps else 'OFF'}")
            elif key in [ord('1'), ord('2'), ord('3'), ord('4')]:
                focus_camera = int(chr(key))
                if focus_camera <= self.num_cameras:
                    print(f"Focusing on Camera {focus_camera}")
                    # Hide other windows
                    for j, name in enumerate(window_names):
                        if j + 1 != focus_camera:
                            cv2.destroyWindow(name)
                else:
                    focus_camera = None
            elif key == ord('a'):  # Show all cameras
                focus_camera = None
                print("Showing all cameras")
                for name in window_names:
                    cv2.namedWindow(name, cv2.WINDOW_AUTOSIZE)
        
        # Cleanup
        cv2.destroyAllWindows()

    def stop(self):
        """Stop all camera threads"""
        print("Stopping all cameras...")
        self.running = False
        
        for thread in self.threads:
            thread.join(timeout=3)
        
        print("Multi-camera fusion stopped.")


def main():
    parser = argparse.ArgumentParser(description="PACMAN multi-camera streaming fusion")
    parser.add_argument(
        "--jetson_ip",
        type=str,
        default="192.168.1.254",
        help="Jetson IP address (default: 192.168.1.254)"
    )
    parser.add_argument(
        "--base_port",
        type=int,
        default=30000,
        help="Base port for camera streams (default: 30000)"
    )
    parser.add_argument(
        "--num_cameras",
        type=int,
        default=4,
        help="Number of cameras to connect to (default: 4)"
    )
    
    args = parser.parse_args()
    
    print("=== PACMAN Multi-Camera Streaming Fusion ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print(f"Connecting to {args.num_cameras} cameras starting from port {args.base_port}")
    print("Camera ports:", [args.base_port + i*2 for i in range(args.num_cameras)])
    print()
    
    # Create multi-camera receiver
    receiver = MultiCameraStreamingReceiver(args.jetson_ip, args.base_port, args.num_cameras)
    
    try:
        # Start all camera threads
        receiver.start_cameras()
        
        # Wait a bit for connections to establish
        time.sleep(3)
        
        # Run display loop
        receiver.run_display()
        
    except KeyboardInterrupt:
        pass
    finally:
        receiver.stop()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())





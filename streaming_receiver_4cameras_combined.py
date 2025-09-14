#!/usr/bin/env python3
"""
PACMAN SDK - 4-Camera Combined Display

Connects to all 4 streaming cameras and displays them in a single window
in a 2x2 grid layout for easy viewing.

Based on PACMAN SDK streaming receiver examples.
"""

import argparse
import cv2
import numpy as np
import pyzed.sl as sl
import sys
import time
import threading
import queue


class ThreeCameraDisplay:
    def __init__(self, jetson_ip, base_port=30000):
        self.jetson_ip = jetson_ip
        self.base_port = base_port
        self.cameras = []
        self.threads = []
        self.image_queues = []
        self.running = True
        
        # Initialize queues for cameras 1, 2, 3 (skipping camera 0)
        for i in range(3):
            self.image_queues.append(queue.Queue(maxsize=2))

    def camera_thread(self, camera_id, port):
        """Thread function for each camera stream"""
        print(f"Starting Camera {camera_id} on port {port}")
        
        # Initialize camera for streaming
        init_params = sl.InitParameters()
        init_params.depth_mode = sl.DEPTH_MODE.NONE  # No depth for basic streaming
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
        runtime_params = sl.RuntimeParameters()
        
        frame_count = 0
        
        while self.running:
            if cam.grab(runtime_params) == sl.ERROR_CODE.SUCCESS:
                # Retrieve RGB image
                cam.retrieve_image(image_mat, sl.VIEW.LEFT)
                image_data = image_mat.get_data()
                
                if image_data is not None and image_data.size > 0:
                    # Ensure image is RGB (3 channels)
                    if len(image_data.shape) == 3 and image_data.shape[2] == 4:
                        # Convert RGBA to RGB
                        image_data = cv2.cvtColor(image_data, cv2.COLOR_RGBA2RGB)
                    elif len(image_data.shape) == 2:
                        # Convert grayscale to RGB
                        image_data = cv2.cvtColor(image_data, cv2.COLOR_GRAY2RGB)
                    
                    # Resize for display (smaller for 3-camera grid)
                    height, width = image_data.shape[:2]
                    display_width = 480  # Smaller size for 3-camera grid
                    display_height = int(height * display_width / width)
                    resized_image = cv2.resize(image_data, (display_width, display_height))
                    
                    # Ensure resized image is RGB (3 channels)
                    if len(resized_image.shape) == 3 and resized_image.shape[2] != 3:
                        resized_image = resized_image[:, :, :3]
                    
                    # Add camera label
                    label_text = f"Camera {camera_id}"
                    cv2.putText(resized_image, label_text, (10, 30), 
                               cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
                    
                    frame_data = {
                        'camera_id': camera_id,
                        'image': resized_image,
                        'frame_count': frame_count,
                        'timestamp': time.time()
                    }
                    
                    # Queue data (non-blocking) - adjust index for cameras 1,2,3
                    try:
                        queue_index = camera_id - 2  # camera 2->0, camera 3->1, camera 4->2
                        self.image_queues[queue_index].put_nowait(frame_data)
                    except queue.Full:
                        pass  # Skip frame if queue is full
                
                frame_count += 1
            else:
                time.sleep(0.01)
        
        print(f"Camera {camera_id}: Closing")
        cam.close()

    def start_cameras(self):
        """Start camera threads for cameras 2, 3, 4 (skipping camera 1)"""
        for i in range(1, 4):  # Start from camera 2 (index 1)
            camera_id = i + 1  # cameras 2, 3, 4
            port = self.base_port + (i * 2)  # 30002, 30004, 30006
            
            thread = threading.Thread(
                target=self.camera_thread,
                args=(camera_id, port),
                name=f"Camera-{camera_id}"
            )
            thread.start()
            self.threads.append(thread)
            time.sleep(1)  # Stagger connections

    def run_display(self):
        """Main display loop showing cameras 2, 3, 4 in one window"""
        print("\n=== 3-Camera Combined Display ===")
        print("Layout:")
        print("  Camera 2  |  Camera 3")
        print("     Camera 4")
        print("Note: Camera 1 runs separately")
        print("\nControls:")
        print("- 'q': Quit")
        print("- 'f': Toggle FPS display")
        print("- 'F': Toggle fullscreen (Shift+F)")
        
        cv2.namedWindow("PACMAN 3-Camera View", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("PACMAN 3-Camera View", 1000, 800)
        
        show_fps = True
        fullscreen = False
        last_fps_time = time.time()
        fps_counters = [0] * 3  # Only 3 cameras now
        
        # Create placeholder images
        placeholder = np.zeros((240, 480, 3), dtype=np.uint8)
        cv2.putText(placeholder, "Connecting...", (150, 120), 
                   cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2)
        
        images = [placeholder.copy() for _ in range(3)]  # Only 3 cameras
        
        while self.running:
            current_time = time.time()
            
            # Get latest frames from each camera
            for i in range(3):
                try:
                    frame_data = self.image_queues[i].get_nowait()
                    images[i] = frame_data['image']
                    fps_counters[i] += 1
                except queue.Empty:
                    pass  # Keep previous image
            
            # Create layout: Camera 2 | Camera 3 on top, Camera 4 centered below
            top_row = np.hstack([images[0], images[1]])      # Camera 2 | Camera 3
            # Center Camera 4 by creating padding that matches the top row width
            top_width = top_row.shape[1]
            cam4_width = images[2].shape[1]
            padding_width = (top_width - cam4_width) // 2
            
            if padding_width > 0:
                # Ensure padding has same number of channels as the image
                num_channels = images[2].shape[2] if len(images[2].shape) == 3 else 3
                left_padding = np.zeros((images[2].shape[0], padding_width, num_channels), dtype=np.uint8)
                right_padding = np.zeros((images[2].shape[0], padding_width, num_channels), dtype=np.uint8)
                bottom_row = np.hstack([left_padding, images[2], right_padding])
            else:
                bottom_row = images[2]
            
            # Ensure both rows have the same width
            if bottom_row.shape[1] != top_row.shape[1]:
                # Adjust bottom row to match top row width
                diff = top_row.shape[1] - bottom_row.shape[1]
                if diff > 0:
                    num_channels = bottom_row.shape[2] if len(bottom_row.shape) == 3 else 3
                    extra_padding = np.zeros((bottom_row.shape[0], diff, num_channels), dtype=np.uint8)
                    bottom_row = np.hstack([bottom_row, extra_padding])
                else:
                    bottom_row = bottom_row[:, :top_row.shape[1]]
            
            combined_image = np.vstack([top_row, bottom_row])
            
            # Add overall info
            if show_fps and current_time - last_fps_time >= 1.0:
                total_fps = sum(fps_counters)
                fps_text = f"Total FPS: {total_fps} | Individual: {fps_counters}"
                cv2.putText(combined_image, fps_text, (10, combined_image.shape[0] - 20), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
                print(f"FPS: {fps_counters} (Total: {total_fps})")
                fps_counters = [0] * 3
                last_fps_time = current_time
            
            # Display combined image
            cv2.imshow("PACMAN 3-Camera View", combined_image)
            
            # Handle keyboard input
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break
            elif key == ord('f'):
                show_fps = not show_fps
                print(f"FPS display: {'ON' if show_fps else 'OFF'}")
            elif key == ord('F'):  # Use 'F' key instead of F11 for fullscreen
                fullscreen = not fullscreen
                if fullscreen:
                    cv2.setWindowProperty("PACMAN 3-Camera View", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)
                    print("Fullscreen: ON")
                else:
                    cv2.setWindowProperty("PACMAN 3-Camera View", cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_NORMAL)
                    print("Fullscreen: OFF")
        
        cv2.destroyAllWindows()

    def stop(self):
        """Stop all camera threads"""
        print("Stopping all cameras...")
        self.running = False
        
        for thread in self.threads:
            thread.join(timeout=3)
        
        print("3-camera display stopped.")


def main():
    parser = argparse.ArgumentParser(description="PACMAN 3-camera combined display")
    parser.add_argument(
        "--jetson_ip",
        type=str,
        default="10.0.0.31",
        help="Jetson IP address (default: 10.0.0.31)"
    )
    
    args = parser.parse_args()
    
    print("=== PACMAN 3-Camera Combined Display ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print("Connecting to cameras 2, 3, 4...")
    print("Ports: 30002, 30004, 30006")
    print("Note: Camera 1 (port 30000) runs separately")
    print()
    
    display = ThreeCameraDisplay(args.jetson_ip)
    
    try:
        display.start_cameras()
        print("Waiting for camera connections...")
        time.sleep(5)
        display.run_display()
    except KeyboardInterrupt:
        pass
    finally:
        display.stop()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

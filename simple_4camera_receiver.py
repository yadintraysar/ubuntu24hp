#!/usr/bin/env python3
"""
Simple 4-Camera Receiver - Minimal Code
Displays 4 cameras in 2x2 grid with timeout between each connection
"""

import cv2
import numpy as np
import pyzed.sl as sl
import time
import argparse

def main():
    parser = argparse.ArgumentParser(description="Simple 4-Camera Receiver")
    parser.add_argument('--ip', type=str, default='10.0.0.31', help='Jetson IP')
    args = parser.parse_args()
    
    # Camera ports (standard ZED ports)
    ports = [30000, 30002, 30004, 30006]
    cameras = []
    image_mats = []
    
    # Standard display size for each camera
    display_width = 640
    display_height = 480
    
    # Create placeholder
    placeholder = np.zeros((display_height, display_width, 3), dtype=np.uint8)
    cv2.putText(placeholder, "No Signal", (200, 240), 
               cv2.FONT_HERSHEY_SIMPLEX, 1.0, (100, 100, 100), 2)
    
    print("=== Simple 4-Camera Receiver ===")
    print(f"Connecting to {args.ip}...")
    print("Cameras: 0, 1, 2, 3")
    print(f"Ports: {ports}")
    print()
    
    # Open cameras one by one with delays
    for i, port in enumerate(ports):
        print(f"[Camera {i}] Connecting to port {port}...")
        
        init_params = sl.InitParameters()
        init_params.depth_mode = sl.DEPTH_MODE.NONE
        init_params.sdk_verbose = 0  # Less verbose
        init_params.set_from_stream(args.ip, port)
        init_params.open_timeout_sec = 5.0  # 5 second timeout
        
        cam = sl.Camera()
        status = cam.open(init_params)
        
        if status == sl.ERROR_CODE.SUCCESS:
            cam_info = cam.get_camera_information()
            print(f"[Camera {i}] ✓ Connected - S/N:{cam_info.serial_number}")
            cameras.append(cam)
            image_mats.append(sl.Mat())
        else:
            print(f"[Camera {i}] ✗ Failed - {status}")
            cameras.append(None)
            image_mats.append(None)
        
        # Wait before next camera (important!)
        if i < len(ports) - 1:
            time.sleep(2)
    
    print()
    print(f"Connected cameras: {sum(1 for c in cameras if c is not None)}/4")
    print("Press 'q' to quit")
    print()
    
    # Create window
    cv2.namedWindow("4-Camera View", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("4-Camera View", 1280, 960)
    
    # Runtime params
    runtime_params = sl.RuntimeParameters()
    
    # Main loop
    images = [placeholder.copy() for _ in range(4)]
    
    while True:
        # Grab from each camera
        for i in range(4):
            if cameras[i] is not None:
                if cameras[i].grab(runtime_params) == sl.ERROR_CODE.SUCCESS:
                    cameras[i].retrieve_image(image_mats[i], sl.VIEW.LEFT)
                    img_data = image_mats[i].get_data()
                    
                    # Convert to RGB if needed (ensure 3 channels)
                    if img_data.shape[2] == 4:
                        img_data = cv2.cvtColor(img_data, cv2.COLOR_BGRA2BGR)
                    
                    # Resize to standard size
                    img_resized = cv2.resize(img_data, (display_width, display_height))
                    
                    # Add label
                    cv2.putText(img_resized, f"Camera {i}", (10, 30), 
                               cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                    
                    images[i] = img_resized
                else:
                    # Keep placeholder if grab fails
                    images[i] = placeholder.copy()
            else:
                # Keep placeholder if camera is None
                images[i] = placeholder.copy()
        
        # Create 2x2 grid (all images now guaranteed to be same size/channels)
        top_row = np.hstack([images[0], images[1]])
        bottom_row = np.hstack([images[2], images[3]])
        combined = np.vstack([top_row, bottom_row])
        
        # Display
        cv2.imshow("4-Camera View", combined)
        
        # Check for quit
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    # Cleanup
    print("Closing cameras...")
    for i, cam in enumerate(cameras):
        if cam is not None:
            cam.close()
            print(f"Camera {i}: Closed")
    
    cv2.destroyAllWindows()
    print("Done!")

if __name__ == "__main__":
    main()




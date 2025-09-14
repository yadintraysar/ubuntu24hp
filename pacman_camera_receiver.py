#!/usr/bin/env python3
"""
Simple camera feed receiver for Pacman Live Global Localization
Connects to ZED SDK stream and displays only the camera feed
"""

import pyzed.sl as sl
import cv2
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description='Pacman Camera Feed Receiver')
    parser.add_argument('--ip', type=str, default='localhost', 
                       help='IP address of the streaming sender (default: localhost)')
    parser.add_argument('--port', type=int, default=30000,
                       help='Port of the streaming sender (default: 30000)')
    args = parser.parse_args()

    print(f"[Pacman Camera Receiver] Connecting to {args.ip}:{args.port}")

    # Initialize ZED camera for streaming reception
    init_parameters = sl.InitParameters()
    init_parameters.depth_mode = sl.DEPTH_MODE.NONE  # We only want camera feed
    init_parameters.sdk_verbose = 1
    
    # Set up streaming input
    init_parameters.set_from_stream(args.ip, args.port)
    
    # Create camera object
    camera = sl.Camera()
    
    # Open the camera
    status = camera.open(init_parameters)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f"[ERROR] Failed to open camera stream: {status}")
        print("Make sure the sender is running with --stream-camera flag")
        return -1

    # Print camera information
    camera_info = camera.get_camera_information()
    print(f"[INFO] Connected to Pacman Camera:")
    print(f"  Model: {camera_info.camera_model}")
    print(f"  Serial: {camera_info.serial_number}")
    print(f"  Resolution: {camera_info.camera_configuration.resolution.width}x{camera_info.camera_configuration.resolution.height}")
    print(f"  FPS: {camera_info.camera_configuration.fps}")

    # Create OpenCV window
    window_name = "Pacman Camera Feed"
    cv2.namedWindow(window_name, cv2.WINDOW_AUTOSIZE)
    
    # Create Mat object to store images
    image = sl.Mat()
    runtime_parameters = sl.RuntimeParameters()
    
    print("[INFO] Press 'q' to quit, 's' to save screenshot")
    screenshot_count = 0
    
    try:
        while True:
            # Grab a new frame
            if camera.grab(runtime_parameters) == sl.ERROR_CODE.SUCCESS:
                # Retrieve left image
                camera.retrieve_image(image, sl.VIEW.LEFT)
                
                # Convert to OpenCV format
                cv_image = image.get_data()
                
                # Display the image
                cv2.imshow(window_name, cv_image)
                
                # Handle key presses
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    print("[INFO] Quit requested")
                    break
                elif key == ord('s'):
                    screenshot_count += 1
                    filename = f"pacman_camera_screenshot_{screenshot_count:03d}.jpg"
                    cv2.imwrite(filename, cv_image)
                    print(f"[INFO] Screenshot saved: {filename}")
                    
            else:
                print("[WARNING] Failed to grab frame from stream")
                
    except KeyboardInterrupt:
        print("\n[INFO] Interrupted by user")
    
    # Cleanup
    cv2.destroyAllWindows()
    camera.close()
    print("[INFO] Camera receiver closed")
    return 0

if __name__ == "__main__":
    sys.exit(main())

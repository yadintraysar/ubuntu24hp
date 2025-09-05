#!/usr/bin/env python3
"""
PACMAN SDK - Multi-Camera Streaming Depth Sensing

Modified version of the official ZED SDK multi-camera depth sensing sample
to work with streaming from Jetson. Connects to 4 camera streams simultaneously
and displays synchronized depth sensing from all cameras.

Based on: https://github.com/stereolabs/zed-sdk/tree/master/depth%20sensing/multi%20camera
"""

import pyzed.sl as sl
import cv2
import numpy as np
import threading
import time
import signal
import argparse

# Global variables for multi-camera management
zed_list = []
left_list = []
depth_list = []
timestamp_list = []
thread_list = []
stop_signal = False

def signal_handler(signal, frame):
    global stop_signal
    stop_signal = True
    time.sleep(0.5)
    exit()

def grab_run(index):
    """Grab thread for each camera stream"""
    global stop_signal, zed_list, timestamp_list, left_list, depth_list

    runtime = sl.RuntimeParameters()
    runtime.confidence_threshold = 50
    
    while not stop_signal:
        err = zed_list[index].grab(runtime)
        if err <= sl.ERROR_CODE.SUCCESS:
            # Retrieve image and depth for this camera
            zed_list[index].retrieve_image(left_list[index], sl.VIEW.LEFT)
            zed_list[index].retrieve_measure(depth_list[index], sl.MEASURE.DEPTH)
            timestamp_list[index] = zed_list[index].get_timestamp(sl.TIME_REFERENCE.CURRENT).data_ns
        else:
            time.sleep(0.01)  # Brief pause on grab error
    
    print(f"Camera {index + 1}: Closing stream")
    zed_list[index].close()

def main():
    global stop_signal, zed_list, left_list, depth_list, timestamp_list, thread_list
    
    parser = argparse.ArgumentParser(description="PACMAN multi-camera streaming depth sensing")
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
    parser.add_argument(
        "--depth_mode",
        type=str,
        default="NEURAL",
        choices=["NEURAL_LIGHT", "NEURAL", "NEURAL_PLUS"],
        help="Depth mode (default: NEURAL)"
    )
    
    args = parser.parse_args()
    
    signal.signal(signal.SIGINT, signal_handler)

    print("=== PACMAN Multi-Camera Streaming Depth Sensing ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print(f"Connecting to {args.num_cameras} cameras starting from port {args.base_port}")
    print(f"Depth mode: {args.depth_mode}")
    print()

    # Map depth modes
    depth_modes = {
        "NEURAL_LIGHT": sl.DEPTH_MODE.NEURAL_LIGHT,
        "NEURAL": sl.DEPTH_MODE.NEURAL,
        "NEURAL_PLUS": sl.DEPTH_MODE.NEURAL_PLUS
    }
    selected_depth_mode = depth_modes[args.depth_mode]

    # Initialize cameras for streaming
    name_list = []
    last_ts_list = []
    
    for i in range(args.num_cameras):
        camera_id = i + 1
        port = args.base_port + (i * 2)  # 30000, 30002, 30004, 30006
        
        print(f"Opening Camera {camera_id} on port {port}...")
        
        # Initialize streaming parameters
        init_params = sl.InitParameters()
        init_params.camera_resolution = sl.RESOLUTION.HD720  # Lower res for multi-camera
        init_params.camera_fps = 30
        init_params.depth_mode = selected_depth_mode
        init_params.coordinate_units = sl.UNIT.MILLIMETER
        init_params.set_from_stream(args.jetson_ip, port)
        
        name_list.append(f"Camera {camera_id} (Port {port})")
        zed_list.append(sl.Camera())
        left_list.append(sl.Mat())
        depth_list.append(sl.Mat())
        timestamp_list.append(0)
        last_ts_list.append(0)
        
        status = zed_list[i].open(init_params)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Camera {camera_id}: Failed to open - {status}")
            zed_list[i].close()
        else:
            # Get camera info
            cam_info = zed_list[i].get_camera_information()
            print(f"Camera {camera_id}: Connected to {cam_info.camera_model} S/N:{cam_info.serial_number}")
        
        time.sleep(1)  # Stagger connections

    # Start camera threads
    print(f"\nStarting {len(zed_list)} camera threads...")
    for index in range(len(zed_list)):
        if zed_list[index].is_opened():
            thread_list.append(threading.Thread(target=grab_run, args=(index,)))
            thread_list[index].start()
            print(f"Thread started for Camera {index + 1}")

    # Display camera images and depth
    print("\nControls:")
    print("- 'q': Quit")
    print("- 'd': Toggle depth/image view")
    print("- 'f': Show FPS")
    
    show_depth = False
    show_fps = True
    fps_start = time.time()
    fps_counts = [0] * len(zed_list)
    
    key = ''
    while key != 113:  # for 'q' key
        current_time = time.time()
        
        for index in range(len(zed_list)):
            if zed_list[index].is_opened():
                if timestamp_list[index] > last_ts_list[index]:
                    # Choose what to display
                    if show_depth:
                        # Show depth map
                        depth_data = depth_list[index].get_data()
                        if depth_data is not None and depth_data.size > 0:
                            # Normalize depth for visualization
                            depth_norm = cv2.normalize(depth_data, None, 0, 255, cv2.NORM_MINMAX, dtype=cv2.CV_8U)
                            depth_colored = cv2.applyColorMap(depth_norm, cv2.COLORMAP_JET)
                            
                            # Add camera info overlay
                            camera_info = f"Cam {index + 1} - DEPTH ({args.depth_mode})"
                            cv2.putText(depth_colored, camera_info, (10, 30), 
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
                            
                            cv2.imshow(name_list[index], depth_colored)
                    else:
                        # Show RGB image
                        image_data = left_list[index].get_data()
                        if image_data is not None and image_data.size > 0:
                            # Add camera info overlay
                            camera_info = f"Cam {index + 1} - RGB"
                            cv2.putText(image_data, camera_info, (10, 30), 
                                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                            
                            cv2.imshow(name_list[index], image_data)
                    
                    # Print depth at center of image
                    x = round(depth_list[index].get_width() / 2)
                    y = round(depth_list[index].get_height() / 2)
                    err, depth_value = depth_list[index].get_value(x, y)
                    if np.isfinite(depth_value):
                        if show_fps and current_time - fps_start >= 3.0:  # Every 3 seconds
                            print(f"Camera {index + 1} depth at center: {round(depth_value)}mm")
                    
                    fps_counts[index] += 1
                    last_ts_list[index] = timestamp_list[index]
        
        # Show FPS info every 3 seconds
        if show_fps and current_time - fps_start >= 3.0:
            total_fps = sum(fps_counts)
            print(f"Total FPS: {total_fps} | Individual: {fps_counts}")
            fps_counts = [0] * len(zed_list)
            fps_start = current_time
        
        key = cv2.waitKey(10)
        
        # Handle key presses
        if key == ord('d'):
            show_depth = not show_depth
            print(f"Switched to {'DEPTH' if show_depth else 'RGB'} view")
        elif key == ord('f'):
            show_fps = not show_fps
            print(f"FPS display: {'ON' if show_fps else 'OFF'}")
    
    cv2.destroyAllWindows()

    # Stop the threads
    print("\nStopping all camera threads...")
    stop_signal = True
    for index in range(len(thread_list)):
        if thread_list[index].is_alive():
            thread_list[index].join(timeout=3)

    print("Multi-camera depth sensing finished!")

if __name__ == "__main__":
    main()

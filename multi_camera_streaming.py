########################################################################
#
# Modified from official Stereolabs zed-multi-camera sample
# Adapted for network streaming from Jetson
#
########################################################################

"""
    Multi cameras streaming sample - connects to 4 ZED cameras via network streaming
    Based on official Stereolabs zed-multi-camera architecture
"""

import pyzed.sl as sl
import cv2
import numpy as np
import threading
import time
import signal
import argparse

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
    global stop_signal
    global zed_list
    global timestamp_list
    global left_list
    global depth_list

    runtime = sl.RuntimeParameters()
    while not stop_signal:
        err = zed_list[index].grab(runtime)
        if err == sl.ERROR_CODE.SUCCESS:
            zed_list[index].retrieve_image(left_list[index], sl.VIEW.LEFT)
            zed_list[index].retrieve_measure(depth_list[index], sl.MEASURE.DEPTH)
            timestamp_list[index] = zed_list[index].get_timestamp(sl.TIME_REFERENCE.CURRENT).data_ns
        time.sleep(0.001)  # 1ms
    zed_list[index].close()

def main():
    global stop_signal
    global zed_list
    global left_list
    global depth_list
    global timestamp_list
    global thread_list
    
    parser = argparse.ArgumentParser(description="Multi-camera streaming receiver")
    parser.add_argument("--jetson_ip", type=str, default="10.0.0.31", help="Jetson IP address")
    parser.add_argument("--base_port", type=int, default=30000, help="Base port for streams")
    parser.add_argument("--num_cameras", type=int, default=4, help="Number of cameras")
    args = parser.parse_args()
    
    signal.signal(signal.SIGINT, signal_handler)

    print("=== Official ZED Multi-Camera Streaming ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print(f"Connecting to {args.num_cameras} cameras...")

    init = sl.InitParameters()
    init.camera_resolution = sl.RESOLUTION.HD720
    init.camera_fps = 30
    init.depth_mode = sl.DEPTH_MODE.NONE  # No depth for basic streaming

    # Connect to streaming cameras instead of local detection
    name_list = []
    last_ts_list = []
    
    for i in range(args.num_cameras):
        camera_id = i + 1
        port = args.base_port + (i * 2)  # 30000, 30002, 30004, 30006
        
        # Set up streaming connection
        init.set_from_stream(args.jetson_ip, port)
        
        name_list.append(f"Camera {camera_id} (Port {port})")
        print(f"Opening Camera {camera_id} on port {port}...")
        
        zed_list.append(sl.Camera())
        left_list.append(sl.Mat())
        depth_list.append(sl.Mat())
        timestamp_list.append(0)
        last_ts_list.append(0)
        
        status = zed_list[i].open(init)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Camera {camera_id}: Failed to open - {status}")
            zed_list[i].close()
        else:
            cam_info = zed_list[i].get_camera_information()
            print(f"Camera {camera_id}: Connected to {cam_info.camera_model} S/N:{cam_info.serial_number}")
        
        time.sleep(1)  # Stagger connections

    # Start camera threads (official architecture)
    for index in range(len(zed_list)):
        if zed_list[index].is_opened():
            thread_list.append(threading.Thread(target=grab_run, args=(index,)))
            thread_list[index].start()
            print(f"Started thread for Camera {index + 1}")

    print(f"\nDisplaying {len([z for z in zed_list if z.is_opened()])} cameras...")
    print("Press 'q' to quit")

    # Display camera images (official architecture)
    key = ''
    while key != 113:  # for 'q' key
        for index in range(len(zed_list)):
            if zed_list[index].is_opened():
                if timestamp_list[index] > last_ts_list[index]:
                    image_data = left_list[index].get_data()
                    if image_data is not None and image_data.size > 0:
                        # Add camera label
                        cv2.putText(image_data, f"Camera {index + 1}", (10, 30), 
                                   cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)
                        cv2.imshow(name_list[index], image_data)
                    
                    # Print depth at center (optional)
                    x = round(depth_list[index].get_width() / 2)
                    y = round(depth_list[index].get_height() / 2)
                    err, depth_value = depth_list[index].get_value(x, y)
                    if np.isfinite(depth_value):
                        print(f"Camera {index + 1} depth at center: {round(depth_value)}mm")
                    
                    last_ts_list[index] = timestamp_list[index]
        key = cv2.waitKey(10)
    
    cv2.destroyAllWindows()

    # Stop the threads (official cleanup)
    stop_signal = True
    for index in range(len(thread_list)):
        if thread_list[index].is_alive():
            thread_list[index].join()

    print("\nMulti-camera streaming finished!")

if __name__ == "__main__":
    main()

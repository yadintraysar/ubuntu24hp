#!/usr/bin/env python3
"""
PACMAN SDK - Streaming Receiver with Depth Visualization

Connects to a PACMAN sender over the network and computes depth locally,
displaying a colorized depth map (and optional left image).

Based on PACMAN SDK streaming receiver + rdepth sensing examples.
"""

import argparse
import socket
import sys
import time

import cv2
import numpy as np
import pyzed.sl as sl


def parse_ip_port(value: str) -> tuple[str, int]:
    try:
        host, port_str = value.split(":")
        socket.inet_aton(host)
        port = int(port_str)
        if not (1 <= port <= 65535):
            raise ValueError
        return host, port
    except Exception:
        raise argparse.ArgumentTypeError(
            "Invalid --ip_address. Use a.b.c.d:port (e.g., 192.168.1.254:30000)"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="PACMAN depth receiver")
    parser.add_argument(
        "--ip_address",
        required=True,
        type=parse_ip_port,
        help="Sender IP:PORT, e.g. 192.168.1.254:30000",
    )
    parser.add_argument(
        "--max_range_m",
        type=float,
        default=5.0,
        help="Depth display range upper bound in meters (default: 5.0)",
    )
    parser.add_argument(
        "--show_left",
        action="store_true",
        help="Also show the left image window",
    )
    args = parser.parse_args()

    host, port = args.ip_address

    # Initialize PACMAN camera in streaming mode with depth enabled (NEURAL)
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.NEURAL
    init_params.sdk_verbose = 1
    init_params.coordinate_units = sl.UNIT.METER
    init_params.set_from_stream(host, port)

    cam = sl.Camera()
    status = cam.open(init_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print("Camera Open:", status, "- Exit")
        return 1

    # Runtime parameters (tune as needed)
    runtime = sl.RuntimeParameters()
    # Optional: confidence threshold to reduce noisy depth
    try:
        runtime.confidence_threshold = 50
    except Exception:
        pass

    depth_mat = sl.Mat()
    left_mat = sl.Mat()

    win_depth = "PACMAN Depth"
    cv2.namedWindow(win_depth, cv2.WINDOW_AUTOSIZE)
    if args.show_left:
        cv2.namedWindow("PACMAN Left", cv2.WINDOW_AUTOSIZE)

    print("Connected to sender:", f"{host}:{port}")
    print("Press 'q' to quit")

    last_info = time.time()
    while True:
        err = cam.grab(runtime)
        if err == sl.ERROR_CODE.SUCCESS:
            # Retrieve depth in meters
            cam.retrieve_measure(depth_mat, sl.MEASURE.DEPTH)
            depth = depth_mat.get_data()  # float32 meters, shape (H, W)

            # Visualize: clamp and normalize to [0, 255]
            # Invalids are NaN or <= 0; mask them to 0
            depth_disp = depth.copy()
            # Replace NaNs/negatives
            np.nan_to_num(depth_disp, copy=False, nan=0.0, posinf=0.0, neginf=0.0)
            depth_disp[depth_disp <= 0] = 0.0

            # Clamp to max range for better contrast
            max_range = max(0.1, float(args.max_range_m))
            depth_disp[depth_disp > max_range] = max_range

            # Normalize to 8-bit and apply colormap
            depth_norm = (depth_disp / max_range * 255.0).astype(np.uint8)
            depth_color = cv2.applyColorMap(255 - depth_norm, cv2.COLORMAP_JET)

            cv2.imshow(win_depth, depth_color)

            if args.show_left:
                cam.retrieve_image(left_mat, sl.VIEW.LEFT)
                left_img = left_mat.get_data()
                cv2.imshow("PACMAN Left", left_img)

            # Periodic info
            if time.time() - last_info > 2.0:
                cam_info = cam.get_camera_information()
                print(
                    f"Depth: {cam_info.camera_model} S/N {cam_info.serial_number} | "
                    f"Res: {cam_info.camera_configuration.resolution.width}x{cam_info.camera_configuration.resolution.height}"
                )
                last_info = time.time()

            key = cv2.waitKey(1)
            if key == ord("q"):
                break
        else:
            # If stream is initializing or intermittent, avoid spamming
            time.sleep(0.01)

    cv2.destroyAllWindows()
    cam.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())




cd "/usr/local/zed/samples/camera streaming/single_sender/python"
python3 streaming_sender.py
python3 streaming_sender.py
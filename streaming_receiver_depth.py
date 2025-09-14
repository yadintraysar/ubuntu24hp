
#!/usr/bin/env python3
"""
PACMAN SDK - Streaming Receiver with RGB-Textured 3D Point Cloud

Connects to a PACMAN sender over the network and displays RGB-textured 3D point cloud
in an OpenGL viewer, just like the original depth_sensing.py sample.

Based on PACMAN SDK streaming receiver + depth sensing examples.
"""

import argparse
import socket
import sys
import time

import cv2
import numpy as np
import pyzed.sl as sl

# Import OpenGL viewer
sys.path.append('/usr/local/zed/samples/depth sensing/depth sensing/python')
import ogl_viewer.viewer as gl


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
    init_params = sl.InitParameters(depth_mode=sl.DEPTH_MODE.NEURAL,
                                   coordinate_units=sl.UNIT.METER,
                                   coordinate_system=sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP)
    init_params.sdk_verbose = 1
    init_params.set_from_stream(host, port)

    cam = sl.Camera()
    status = cam.open(init_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print("Camera Open:", status, "- Exit")
        return 1

    # Set up resolution for point cloud
    res = sl.Resolution()
    res.width = 720
    res.height = 404

    # Create OpenGL viewer
    viewer = gl.GLViewer()
    viewer.init(1, sys.argv, res)

    # Create point cloud matrix for RGB-textured 3D data
    point_cloud = sl.Mat(res.width, res.height, sl.MAT_TYPE.F32_C4, sl.MEM.CPU)

    print("Connected to sender:", f"{host}:{port}")
    print("Press 'Esc' to quit, 's' to save point cloud")

    # Main loop - RGB-textured 3D point cloud visualization
    while viewer.is_available():
        if cam.grab() <= sl.ERROR_CODE.SUCCESS:
            # Retrieve RGB-textured point cloud (XYZRGBA)
            cam.retrieve_measure(point_cloud, sl.MEASURE.XYZRGBA, sl.MEM.CPU, res)
            viewer.updateData(point_cloud)
            
            # Handle point cloud saving
            if viewer.save_data:
                point_cloud_to_save = sl.Mat()
                cam.retrieve_measure(point_cloud_to_save, sl.MEASURE.XYZRGBA, sl.MEM.CPU)
                err = point_cloud_to_save.write('PACMAN_Pointcloud.ply')
                if err == sl.ERROR_CODE.SUCCESS:
                    print("Point cloud saved as PACMAN_Pointcloud.ply")
                else:
                    print("Failed to save point cloud")
                viewer.save_data = False

    viewer.exit()
    cam.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

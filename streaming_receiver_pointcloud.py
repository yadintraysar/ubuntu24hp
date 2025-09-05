#!/usr/bin/env python3
"""
PACMAN SDK - Streaming Point Cloud Viewer (Open3D)

Connects to a PACMAN sender via set_from_stream and visualizes a live 3D
point cloud with Open3D. Uses QUALITY depth (no TensorRT required).

Controls (Open3D):
- Mouse drag: rotate
- Shift + drag: pan
- Scroll: zoom
- q or Ctrl+C in terminal: quit
"""

import argparse
import socket
import sys
import time

import numpy as np
import open3d as o3d
import pyzed.sl as sl
import cv2


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
    parser = argparse.ArgumentParser(description="PACMAN streaming point cloud viewer")
    parser.add_argument(
        "--ip_address",
        required=True,
        type=parse_ip_port,
        help="Sender IP:PORT, e.g. 192.168.1.254:30000",
    )
    parser.add_argument(
        "--max_range_m",
        type=float,
        default=8.0,
        help="Clamp points beyond this distance (m) [default: 8.0]",
    )
    parser.add_argument(
        "--stride",
        type=int,
        default=2,
        help="Spatial downsample stride (>=1). Use 1 for full res (heavy).",
    )
    args = parser.parse_args()

    host, port = args.ip_address
    stride = max(1, int(args.stride))
    max_range = max(0.1, float(args.max_range_m))

    # Set up streaming with depth enabled (QUALITY to avoid TensorRT)
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.NEURAL_PLUS
    init_params.coordinate_units = sl.UNIT.METER
    init_params.sdk_verbose = 1
    init_params.set_from_stream(host, port)

    cam = sl.Camera()
    status = cam.open(init_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print("Camera Open:", status, "- Exit")
        return 1

    runtime = sl.RuntimeParameters()
    try:
        runtime.confidence_threshold = 50
    except Exception:
        pass

    # Allocate Mats
    pc_mat = sl.Mat()
    color_mat = sl.Mat()

    # Open3D visualizer setup
    vis = o3d.visualization.Visualizer()
    vis.create_window(window_name="PACMAN Point Cloud", width=1280, height=720)
    geom_added = False
    pcd = o3d.geometry.PointCloud()

    print(f"Connecting to sender: {host}:{port}")
    print("Press Ctrl+C in terminal or close the window to quit.")

    try:
        last_info = time.time()
        while True:
            if cam.grab(runtime) != sl.ERROR_CODE.SUCCESS:
                time.sleep(0.005)
                continue

            # Retrieve XYZRGBA point cloud with embedded RGB colors (official SDK way)
            cam.retrieve_measure(pc_mat, sl.MEASURE.XYZRGBA)
            xyzrgba = pc_mat.get_data()  # shape (H, W, 4), float32 - XYZ + packed RGBA

            # Downsample XYZRGBA data
            xyzrgba_ds = xyzrgba[::stride, ::stride, :]
            pts = xyzrgba_ds.reshape(-1, 4)  # Flatten to Nx4 array

            # Extract XYZ and RGBA channels
            xs, ys, zs, rgba_packed = pts.T

            # Build mask for valid points
            finite = np.isfinite(xs) & np.isfinite(ys) & np.isfinite(zs)
            positive = zs > 0.0
            near = zs < max_range
            mask = finite & positive & near

            pts3d = np.stack([xs[mask], ys[mask], zs[mask]], axis=1)

            # Extract real RGB colors from the RGBA channel (official SDK way)
            rgba_valid = rgba_packed[mask]
            colors = np.zeros((len(rgba_valid), 3), dtype=np.float32)
            
            for i, rgba in enumerate(rgba_valid):
                if np.isfinite(rgba) and rgba != 0:
                    # Unpack RGBA from float32 (SDK packs RGBA into single float)
                    rgba_int = int(rgba) if np.isfinite(rgba) else 0
                    b = (rgba_int >> 24) & 0xFF
                    g = (rgba_int >> 16) & 0xFF  
                    r = (rgba_int >> 8) & 0xFF
                    # Convert to RGB [0,1] range
                    colors[i] = [r/255.0, g/255.0, b/255.0]

            # Update Open3D geometry with real RGB colors
            pcd.points = o3d.utility.Vector3dVector(pts3d)
            pcd.colors = o3d.utility.Vector3dVector(colors)
            
            # Apply noise filtering for cleaner visualization
            if len(pcd.points) > 100:
                # Remove statistical outliers
                pcd, _ = pcd.remove_statistical_outlier(nb_neighbors=20, std_ratio=2.0)
                # Remove radius outliers  
                pcd, _ = pcd.remove_radius_outlier(nb_points=16, radius=0.1)

            if not geom_added:
                vis.add_geometry(pcd)
                geom_added = True
            else:
                vis.update_geometry(pcd)

            vis.poll_events()
            vis.update_renderer()

            if time.time() - last_info > 2.0:
                info = cam.get_camera_information()
                print(
                    f"PCD: {info.camera_model} S/N {info.serial_number} | "
                    f"Pts: {len(pcd.points)} | Res: {info.camera_configuration.resolution.width}x{info.camera_configuration.resolution.height}"
                )
                last_info = time.time()

    except KeyboardInterrupt:
        pass
    finally:
        vis.destroy_window()
        cam.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())



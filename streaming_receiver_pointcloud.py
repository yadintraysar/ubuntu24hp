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

            # Retrieve XYZRGBA point cloud in meters
            cam.retrieve_measure(pc_mat, sl.MEASURE.XYZRGBA)
            xyzrgba = pc_mat.get_data()  # shape (H, W, 4), float32

            # Retrieve color from LEFT image for better visualization
            cam.retrieve_image(color_mat, sl.VIEW.LEFT)
            color_img = color_mat.get_data()  # HxWx3 uint8 BGR

            # Downsample spatially by stride to keep FPS reasonable
            # Align color resolution to point cloud resolution before any stride
            # Align color to point cloud resolution
            Hpc, Wpc, _ = xyzrgba.shape
            if color_img is not None and color_img.size != 0:
                color_match = cv2.resize(color_img, (Wpc, Hpc), interpolation=cv2.INTER_AREA)
            else:
                color_match = None

            # Downsample
            xyzrgba_ds = xyzrgba[::stride, ::stride, :]
            Hs, Ws, _ = xyzrgba_ds.shape
            pts = xyzrgba_ds.reshape(-1, 4)

            # Build mask: finite, positive range, within max_range
            xs, ys, zs, _a = pts.T
            finite = np.isfinite(xs) & np.isfinite(ys) & np.isfinite(zs)
            positive = zs > 0.0
            near = zs < max_range
            mask = finite & positive & near

            pts3d = np.stack([xs[mask], ys[mask], zs[mask]], axis=1)

            # Get colors for valid points
            if color_match is not None and color_match.size != 0:
                # Downsample color to match point cloud stride
                color_ds = color_match[::stride, ::stride, :]
                color_bgr = color_ds.reshape(-1, 3)
                # Convert BGR->RGB and to [0,1] 
                colors_full = color_bgr[:, ::-1].astype(np.float32) / 255.0
                # Only keep colors for valid points
                if colors_full.shape[0] == mask.shape[0]:
                    colors = colors_full[mask]
                else:
                    colors = None
            else:
                colors = None

            # Update Open3D geometry with filtering
            pcd.points = o3d.utility.Vector3dVector(pts3d)
            
            if colors is not None and colors.shape[0] == pts3d.shape[0]:
                pcd.colors = o3d.utility.Vector3dVector(colors)
            else:
                # fallback: depth-based color
                if pts3d.shape[0] > 0:
                    z_norm = (pts3d[:, 2] / max_range).clip(0.0, 1.0)
                    # Use a better color scheme - blue to red based on distance
                    colors_fallback = np.zeros((pts3d.shape[0], 3))
                    colors_fallback[:, 0] = z_norm  # Red increases with distance
                    colors_fallback[:, 2] = 1.0 - z_norm  # Blue decreases with distance
                    pcd.colors = o3d.utility.Vector3dVector(colors_fallback)
            
            # Apply noise filtering
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



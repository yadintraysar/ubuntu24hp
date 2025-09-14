#!/usr/bin/env python3
"""
PACMAN SDK - Multi-Camera Fusion 3D Point Cloud

Combines point clouds from 4 streaming cameras into a single unified 3D view.
You can navigate around the combined point cloud with mouse controls.

Based on PACMAN SDK multi-camera fusion concepts.
"""

import argparse
import cv2
import numpy as np
import open3d as o3d
import pyzed.sl as sl
import sys
import time
import threading
import queue


class FusedPointCloudViewer:
    def __init__(self, jetson_ip, base_port=30000, num_cameras=4, depth_mode="NEURAL"):
        self.jetson_ip = jetson_ip
        self.base_port = base_port
        self.num_cameras = num_cameras
        self.cameras = []
        self.threads = []
        self.pointcloud_queues = []
        self.running = True
        
        # Map depth modes
        depth_modes = {
            "NEURAL_LIGHT": sl.DEPTH_MODE.NEURAL_LIGHT,
            "NEURAL": sl.DEPTH_MODE.NEURAL,
            "NEURAL_PLUS": sl.DEPTH_MODE.NEURAL_PLUS
        }
        self.depth_mode = depth_modes.get(depth_mode, sl.DEPTH_MODE.NEURAL)
        
        # Initialize queues for each camera's point cloud data
        for i in range(num_cameras):
            self.pointcloud_queues.append(queue.Queue(maxsize=2))
        
        # Camera colors for visualization (different color per camera)
        self.camera_colors = [
            [1.0, 0.0, 0.0],  # Red - Camera 1
            [0.0, 1.0, 0.0],  # Green - Camera 2  
            [0.0, 0.0, 1.0],  # Blue - Camera 3
            [1.0, 1.0, 0.0],  # Yellow - Camera 4
        ]

    def camera_thread(self, camera_id, port):
        """Thread function for each camera stream"""
        print(f"Starting Camera {camera_id} thread on port {port}")
        
        # Initialize camera for streaming
        init_params = sl.InitParameters()
        init_params.depth_mode = self.depth_mode
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
        pc_mat = sl.Mat()
        color_mat = sl.Mat()
        runtime_params = sl.RuntimeParameters()
        runtime_params.confidence_threshold = 50
        
        frame_count = 0
        
        while self.running:
            if cam.grab(runtime_params) == sl.ERROR_CODE.SUCCESS:
                # Retrieve point cloud and color
                cam.retrieve_measure(pc_mat, sl.MEASURE.XYZRGBA)
                cam.retrieve_image(color_mat, sl.VIEW.LEFT)
                
                xyzrgba = pc_mat.get_data()  # Shape (H, W, 4)
                color_img = color_mat.get_data()  # Shape (H, W, 3)
                
                # Downsample for performance (every 4th pixel)
                stride = 4
                xyzrgba_ds = xyzrgba[::stride, ::stride, :]
                color_ds = color_img[::stride, ::stride, :]
                
                # Reshape to point arrays
                H, W, _ = xyzrgba_ds.shape
                points = xyzrgba_ds.reshape(-1, 4)
                colors = color_ds.reshape(-1, 3)
                
                # Filter valid points
                xs, ys, zs, _ = points.T
                valid_mask = (
                    np.isfinite(xs) & np.isfinite(ys) & np.isfinite(zs) &
                    (zs > 0.1) & (zs < 8.0)  # 0.1m to 8m range
                )
                
                if np.any(valid_mask):
                    valid_points = np.stack([xs[valid_mask], ys[valid_mask], zs[valid_mask]], axis=1)
                    valid_colors = colors[valid_mask][:, ::-1].astype(np.float32) / 255.0  # BGR->RGB
                    
                    # Add camera offset for spatial separation (optional)
                    # This spreads cameras out so you can see them separately
                    offset_x = (camera_id - 2.5) * 2.0  # Spread cameras along X axis
                    valid_points[:, 0] += offset_x
                    
                    pointcloud_data = {
                        'camera_id': camera_id,
                        'points': valid_points,
                        'colors': valid_colors,
                        'frame_count': frame_count,
                        'timestamp': time.time()
                    }
                    
                    # Queue data (non-blocking)
                    try:
                        self.pointcloud_queues[camera_id - 1].put_nowait(pointcloud_data)
                    except queue.Full:
                        pass  # Skip if queue is full
                
                frame_count += 1
            else:
                time.sleep(0.01)
        
        print(f"Camera {camera_id}: Closing (processed {frame_count} frames)")
        cam.close()

    def run_viewer(self):
        """Run the unified 3D point cloud viewer"""
        # Create Open3D visualizer
        vis = o3d.visualization.Visualizer()
        vis.create_window(window_name="PACMAN Multi-Camera Fusion", width=1400, height=900)
        
        # Set up nice viewing angle
        ctr = vis.get_view_control()
        ctr.set_front([0.0, 0.0, -1.0])
        ctr.set_up([0.0, -1.0, 0.0])
        
        # Create point cloud objects for each camera
        pcds = []
        geom_added = [False] * self.num_cameras
        
        for i in range(self.num_cameras):
            pcd = o3d.geometry.PointCloud()
            pcds.append(pcd)
        
        print("\n=== Unified 3D Point Cloud Fusion ===")
        print("Controls:")
        print("- Mouse drag: rotate view")
        print("- Shift + drag: pan")
        print("- Scroll: zoom")
        print("- Close window to exit")
        print("\nCamera Colors:")
        for i in range(self.num_cameras):
            color_name = ["Red", "Green", "Blue", "Yellow"][i]
            print(f"  Camera {i+1}: {color_name}")
        
        last_update = time.time()
        
        try:
            while self.running:
                updated = False
                
                # Update each camera's point cloud
                for i in range(self.num_cameras):
                    try:
                        data = self.pointcloud_queues[i].get_nowait()
                        
                        # Update point cloud
                        pcds[i].points = o3d.utility.Vector3dVector(data['points'])
                        pcds[i].colors = o3d.utility.Vector3dVector(data['colors'])
                        
                        # Add to visualizer if not already added
                        if not geom_added[i]:
                            vis.add_geometry(pcds[i])
                            geom_added[i] = True
                        else:
                            vis.update_geometry(pcds[i])
                        
                        updated = True
                        
                    except queue.Empty:
                        pass
                
                # Update visualization
                vis.poll_events()
                vis.update_renderer()
                
                # Print status every 5 seconds
                current_time = time.time()
                if current_time - last_update > 5.0:
                    total_points = sum(len(pcd.points) for pcd in pcds)
                    active_cameras = sum(1 for pcd in pcds if len(pcd.points) > 0)
                    print(f"Active cameras: {active_cameras}/{self.num_cameras} | Total points: {total_points}")
                    last_update = current_time
                
                # Check if window is still open
                if not vis.poll_events():
                    break
                
                time.sleep(0.016)  # ~60 FPS viewer
                
        except KeyboardInterrupt:
            pass
        finally:
            vis.destroy_window()
            self.running = False

    def start_cameras(self):
        """Start all camera threads"""
        for i in range(self.num_cameras):
            camera_id = i + 1
            port = self.base_port + (i * 2)
            
            thread = threading.Thread(
                target=self.camera_thread,
                args=(camera_id, port),
                name=f"Camera-{camera_id}"
            )
            thread.start()
            self.threads.append(thread)
            time.sleep(1)  # Stagger connections

    def stop(self):
        """Stop all camera threads"""
        print("Stopping fusion viewer...")
        self.running = False
        
        for thread in self.threads:
            thread.join(timeout=3)


def main():
    parser = argparse.ArgumentParser(description="PACMAN multi-camera fusion 3D viewer")
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
        help="Number of cameras to fuse (default: 4)"
    )
    parser.add_argument(
        "--depth_mode",
        type=str,
        default="NEURAL",
        choices=["NEURAL_LIGHT", "NEURAL", "NEURAL_PLUS"],
        help="Depth mode (default: NEURAL)"
    )
    
    args = parser.parse_args()
    
    print("=== PACMAN Multi-Camera 3D Fusion ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print(f"Fusing {args.num_cameras} cameras into unified 3D view")
    print(f"Depth mode: {args.depth_mode}")
    print("Camera ports:", [args.base_port + i*2 for i in range(args.num_cameras)])
    print()
    
    # Create fusion viewer
    viewer = FusedPointCloudViewer(args.jetson_ip, args.base_port, args.num_cameras, args.depth_mode)
    
    try:
        # Start all camera threads
        viewer.start_cameras()
        
        # Wait for connections
        print("Waiting for camera connections...")
        time.sleep(5)
        
        # Run unified 3D viewer
        viewer.run_viewer()
        
    except KeyboardInterrupt:
        pass
    finally:
        viewer.stop()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())





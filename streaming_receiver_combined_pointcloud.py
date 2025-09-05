#!/usr/bin/env python3
"""
PACMAN SDK - Combined Multi-Camera Point Cloud Viewer

Connects to 4 streaming cameras and displays their point clouds in a single
unified 3D view with different colors per camera. Simple fusion without 
complex calibration - just visual combination.
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


class CombinedPointCloudViewer:
    def __init__(self, jetson_ip, base_port=30000, num_cameras=4):
        self.jetson_ip = jetson_ip
        self.base_port = base_port
        self.num_cameras = num_cameras
        self.threads = []
        self.pointcloud_queues = []
        self.running = True
        
        # Initialize queues for each camera
        for i in range(num_cameras):
            self.pointcloud_queues.append(queue.Queue(maxsize=2))
        
        # Different colors for each camera
        self.camera_colors = [
            [1.0, 0.2, 0.2],  # Red - Camera 1
            [0.2, 1.0, 0.2],  # Green - Camera 2
            [0.2, 0.2, 1.0],  # Blue - Camera 3
            [1.0, 1.0, 0.2],  # Yellow - Camera 4
        ]

    def camera_thread(self, camera_id, port, color):
        """Thread for each camera stream"""
        print(f"Starting Camera {camera_id} on port {port}")
        
        # Initialize camera
        init_params = sl.InitParameters()
        init_params.depth_mode = sl.DEPTH_MODE.NEURAL_PLUS
        init_params.coordinate_units = sl.UNIT.METER
        init_params.sdk_verbose = 0  # Reduce log spam
        init_params.set_from_stream(self.jetson_ip, port)
        
        cam = sl.Camera()
        status = cam.open(init_params)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Camera {camera_id}: Failed to connect - {status}")
            return
        
        cam_info = cam.get_camera_information()
        print(f"Camera {camera_id}: {cam_info.camera_model} S/N:{cam_info.serial_number}")
        
        # Data containers
        pc_mat = sl.Mat()
        runtime_params = sl.RuntimeParameters()
        runtime_params.confidence_threshold = 60  # Higher confidence for cleaner points
        
        frame_count = 0
        
        while self.running:
            if cam.grab(runtime_params) == sl.ERROR_CODE.SUCCESS:
                # Get point cloud
                cam.retrieve_measure(pc_mat, sl.MEASURE.XYZRGBA)
                xyzrgba = pc_mat.get_data()
                
                # Downsample for performance
                stride = 3
                xyzrgba_ds = xyzrgba[::stride, ::stride, :]
                points = xyzrgba_ds.reshape(-1, 4)
                
                # Filter valid points
                xs, ys, zs, _ = points.T
                valid_mask = (
                    np.isfinite(xs) & np.isfinite(ys) & np.isfinite(zs) &
                    (zs > 0.2) & (zs < 6.0)  # 0.2m to 6m range
                )
                
                if np.any(valid_mask):
                    valid_points = np.stack([xs[valid_mask], ys[valid_mask], zs[valid_mask]], axis=1)
                    
                    # Apply spatial offset so cameras don't overlap
                    offset_x = (camera_id - 2.5) * 3.0  # 3m spacing between cameras
                    valid_points[:, 0] += offset_x
                    
                    # Use camera-specific color
                    num_points = valid_points.shape[0]
                    colors = np.tile(color, (num_points, 1))
                    
                    pointcloud_data = {
                        'camera_id': camera_id,
                        'points': valid_points,
                        'colors': colors,
                        'frame_count': frame_count
                    }
                    
                    # Queue data
                    try:
                        self.pointcloud_queues[camera_id - 1].put_nowait(pointcloud_data)
                    except queue.Full:
                        pass
                
                frame_count += 1
            else:
                time.sleep(0.01)
        
        print(f"Camera {camera_id}: Closing")
        cam.close()

    def run_viewer(self):
        """Run combined 3D viewer"""
        vis = o3d.visualization.Visualizer()
        vis.create_window(window_name="PACMAN 4-Camera Combined View", width=1600, height=1000)
        
        # Set nice viewing angle
        ctr = vis.get_view_control()
        ctr.set_front([0.0, 0.0, -1.0])
        ctr.set_up([0.0, -1.0, 0.0])
        
        # Point clouds for each camera
        pcds = []
        geom_added = [False] * self.num_cameras
        
        for i in range(self.num_cameras):
            pcd = o3d.geometry.PointCloud()
            pcds.append(pcd)
        
        print("\n=== Combined 4-Camera Point Cloud View ===")
        print("Camera Layout (spatially separated):")
        print("  Camera 1 (Red)    Camera 2 (Green)")
        print("        |                  |")
        print("  Camera 4 (Yellow) Camera 3 (Blue)")
        print()
        print("Controls:")
        print("- Mouse drag: rotate")
        print("- Shift + drag: pan") 
        print("- Scroll: zoom")
        print("- Close window to exit")
        
        last_status = time.time()
        
        try:
            while self.running:
                # Update each camera's point cloud
                for i in range(self.num_cameras):
                    try:
                        data = self.pointcloud_queues[i].get_nowait()
                        
                        pcds[i].points = o3d.utility.Vector3dVector(data['points'])
                        pcds[i].colors = o3d.utility.Vector3dVector(data['colors'])
                        
                        if not geom_added[i]:
                            vis.add_geometry(pcds[i])
                            geom_added[i] = True
                        else:
                            vis.update_geometry(pcds[i])
                            
                    except queue.Empty:
                        pass
                
                vis.poll_events()
                vis.update_renderer()
                
                # Status every 5 seconds
                if time.time() - last_status > 5.0:
                    total_points = sum(len(pcd.points) for pcd in pcds)
                    active_cameras = sum(1 for pcd in pcds if len(pcd.points) > 0)
                    print(f"Active: {active_cameras}/{self.num_cameras} cameras | Total points: {total_points}")
                    last_status = time.time()
                
                if not vis.poll_events():
                    break
                    
                time.sleep(0.016)  # 60 FPS
                
        except KeyboardInterrupt:
            pass
        finally:
            vis.destroy_window()
            self.running = False

    def start(self):
        """Start all camera threads"""
        for i in range(self.num_cameras):
            camera_id = i + 1
            port = self.base_port + (i * 2)
            color = self.camera_colors[i]
            
            thread = threading.Thread(
                target=self.camera_thread,
                args=(camera_id, port, color),
                name=f"Camera-{camera_id}"
            )
            thread.start()
            self.threads.append(thread)
            time.sleep(1.5)  # Stagger connections

    def stop(self):
        """Stop all threads"""
        self.running = False
        for thread in self.threads:
            thread.join(timeout=3)


def main():
    parser = argparse.ArgumentParser(description="PACMAN combined 4-camera point cloud viewer")
    parser.add_argument(
        "--jetson_ip",
        type=str,
        default="192.168.1.254",
        help="Jetson IP address"
    )
    
    args = parser.parse_args()
    
    print("=== PACMAN 4-Camera Combined Point Cloud ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print("Connecting to 4 cameras with NEURAL_PLUS depth...")
    print("Ports: 30000, 30002, 30004, 30006")
    print()
    
    viewer = CombinedPointCloudViewer(args.jetson_ip)
    
    try:
        viewer.start()
        print("Waiting for camera connections...")
        time.sleep(6)
        viewer.run_viewer()
    except KeyboardInterrupt:
        pass
    finally:
        viewer.stop()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

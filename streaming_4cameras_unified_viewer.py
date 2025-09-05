#!/usr/bin/env python3
"""
PACMAN SDK - 4-Camera Unified RGB-Textured Viewer

Connects to 4 streaming cameras and displays all their RGB-textured point clouds
in a single OpenGL window with proper orientations (0°, 90°, 180°, -90°).

Based on official ZED SDK depth sensing sample with multi-camera modifications.
"""

import sys
import pyzed.sl as sl
import numpy as np
import threading
import time
import math
import argparse

# Copy the ogl_viewer directory to our project
import os
import shutil

def setup_viewer():
    """Copy OpenGL viewer to our project directory"""
    src_viewer = "/usr/local/zed/samples/depth sensing/depth sensing/python/ogl_viewer"
    dst_viewer = "/home/yadinlinux/Documents/SDKstream/ogl_viewer"
    
    if not os.path.exists(dst_viewer):
        shutil.copytree(src_viewer, dst_viewer)
        print("✓ Copied OpenGL viewer to project")

# Import after copying
setup_viewer()
sys.path.append('/home/yadinlinux/Documents/SDKstream')
import ogl_viewer.viewer as gl


class MultiCameraUnifiedViewer:
    def __init__(self, jetson_ip, base_port=30000):
        self.jetson_ip = jetson_ip
        self.base_port = base_port
        self.cameras = []
        self.point_clouds = []
        self.threads = []
        self.running = True
        
        # Camera configurations with orientations
        self.camera_configs = [
            {"port": 30000, "pos": [0, 0, 0], "rot_y": 0},      # Camera 1: Forward (0°)
            {"port": 30002, "pos": [3, 0, 0], "rot_y": 90},     # Camera 2: Right (90°)
            {"port": 30004, "pos": [0, 0, 3], "rot_y": 180},    # Camera 3: Backward (180°)
            {"port": 30006, "pos": [-3, 0, 0], "rot_y": -90},   # Camera 4: Left (-90°)
        ]

    def setup_cameras(self):
        """Initialize all 4 camera streams"""
        print("Setting up 4-camera unified viewer...")
        
        for i, config in enumerate(self.camera_configs):
            camera_id = i + 1
            port = config["port"]
            
            print(f"Camera {camera_id}: Port {port}, Rotation: {config['rot_y']}°")
            
            # Initialize camera
            init_params = sl.InitParameters()
            init_params.depth_mode = sl.DEPTH_MODE.NEURAL
            init_params.coordinate_units = sl.UNIT.METER
            init_params.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
            init_params.set_from_stream(self.jetson_ip, port)
            
            cam = sl.Camera()
            status = cam.open(init_params)
            if status != sl.ERROR_CODE.SUCCESS:
                print(f"Camera {camera_id}: Failed to open - {status}")
                continue
            
            cam_info = cam.get_camera_information()
            print(f"Camera {camera_id}: Connected to {cam_info.camera_model} S/N:{cam_info.serial_number}")
            
            # Create point cloud matrix for this camera
            pc_mat = sl.Mat()
            
            self.cameras.append({
                'camera': cam,
                'camera_id': camera_id,
                'config': config,
                'pc_mat': pc_mat,
                'info': cam_info
            })
        
        return len(self.cameras) > 0

    def run_unified_viewer(self):
        """Run unified OpenGL viewer with all 4 cameras"""
        if not self.cameras:
            print("No cameras available!")
            return
        
        # Use resolution for viewer
        res = sl.Resolution()
        res.width = 1280
        res.height = 720
        
        # Create OpenGL viewer
        viewer = gl.GLViewer()
        viewer.init(1, sys.argv, res)
        
        print(f"\n=== Unified 4-Camera RGB-Textured Viewer ===")
        print("Camera Layout in 3D space:")
        print("  Camera 4 (-90°) ← Camera 1 (0°) → Camera 2 (90°)")
        print("                      ↑")
        print("                 Camera 3 (180°)")
        print("\nControls:")
        print("- Mouse: Navigate 3D view")
        print("- 's': Save combined point cloud")
        print("- ESC: Quit")
        
        frame_count = 0
        combined_pc = sl.Mat()
        
        while viewer.is_available():
            active_cameras = 0
            all_points = []
            
            # Process all cameras and combine their point clouds
            for cam_data in self.cameras:
                cam = cam_data['camera']
                config = cam_data['config']
                pc_mat = cam_data['pc_mat']
                
                if cam.grab() <= sl.ERROR_CODE.SUCCESS:
                    # Get RGB-textured point cloud
                    cam.retrieve_measure(pc_mat, sl.MEASURE.XYZRGBA, sl.MEM.CPU, res)
                    pc_data = pc_mat.get_data()
                    
                    if pc_data is not None and pc_data.size > 0:
                        # Apply camera transformation (rotation + position)
                        points = pc_data.reshape(-1, 4)
                        xs, ys, zs, rgba = points.T
                        
                        # Filter valid points
                        valid_mask = np.isfinite(xs) & np.isfinite(ys) & np.isfinite(zs) & (zs > 0.1) & (zs < 8.0)
                        if np.any(valid_mask):
                            # Apply Y-axis rotation
                            rot_y_rad = math.radians(config['rot_y'])
                            cos_y = math.cos(rot_y_rad)
                            sin_y = math.sin(rot_y_rad)
                            
                            xs_valid = xs[valid_mask]
                            ys_valid = ys[valid_mask]
                            zs_valid = zs[valid_mask]
                            rgba_valid = rgba[valid_mask]
                            
                            # Rotate around Y axis
                            xs_rot = xs_valid * cos_y - zs_valid * sin_y
                            zs_rot = xs_valid * sin_y + zs_valid * cos_y
                            
                            # Apply position offset
                            xs_rot += config['pos'][0]
                            ys_final = ys_valid + config['pos'][1]
                            zs_rot += config['pos'][2]
                            
                            # Combine transformed points
                            transformed_points = np.stack([xs_rot, ys_final, zs_rot, rgba_valid], axis=1)
                            all_points.append(transformed_points)
                    
                    active_cameras += 1
            
            # Combine all camera point clouds into one
            if all_points:
                combined_points = np.vstack(all_points)
                
                # Reshape back to image format for viewer
                # Use a reasonable size for the combined view
                combined_height = res.height
                combined_width = res.width
                total_points = combined_points.shape[0]
                
                # Pad or truncate to fit viewer resolution
                target_size = combined_height * combined_width
                if total_points > target_size:
                    # Downsample
                    indices = np.linspace(0, total_points-1, target_size, dtype=int)
                    combined_points = combined_points[indices]
                elif total_points < target_size:
                    # Pad with zeros
                    padding = np.zeros((target_size - total_points, 4))
                    combined_points = np.vstack([combined_points, padding])
                
                # Reshape to image format
                combined_pc_data = combined_points.reshape(combined_height, combined_width, 4)
                
                # Update the viewer with combined data
                combined_pc.set_from(combined_pc_data.astype(np.float32), sl.MEM.CPU)
                viewer.updateData(combined_pc)
                
                if frame_count % 90 == 0:  # Every 3 seconds
                    total_points_display = len([p for p in all_points])
                    print(f"Active cameras: {active_cameras}/4 | Combined point clouds: {total_points_display}")
            
            frame_count += 1
        
        viewer.exit()

    def close_all(self):
        """Close all cameras"""
        self.running = False
        for cam_data in self.cameras:
            cam_data['camera'].close()


def main():
    parser = argparse.ArgumentParser(description="PACMAN 4-camera unified RGB viewer")
    parser.add_argument(
        "--jetson_ip",
        type=str,
        default="192.168.1.254",
        help="Jetson IP address"
    )
    
    args = parser.parse_args()
    
    print("=== PACMAN 4-Camera Unified RGB Viewer ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print("Combining all 4 cameras in one OpenGL window...")
    print()
    
    viewer = MultiCameraUnifiedViewer(args.jetson_ip)
    
    try:
        if viewer.setup_cameras():
            viewer.run_unified_viewer()
        else:
            print("Failed to setup cameras")
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        viewer.close_all()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

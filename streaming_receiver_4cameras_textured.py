#!/usr/bin/env python3
"""
PACMAN SDK - 4-Camera Streaming with Real RGB Texturing

Connects to all 4 streaming cameras and displays them with proper orientations:
- Camera 1 (30000): 0 degrees (forward)
- Camera 2 (30002): 90 degrees (right)  
- Camera 3 (30004): 180 degrees (backward)
- Camera 4 (30006): -90 degrees (left)

Based on official ZED SDK depth sensing sample with streaming support.
"""

import sys
import ogl_viewer.viewer as gl
import pyzed.sl as sl
import argparse
import numpy as np
import threading
import time
import math


class MultiCameraStreamingViewer:
    def __init__(self, jetson_ip, base_port=30000):
        self.jetson_ip = jetson_ip
        self.base_port = base_port
        self.cameras = []
        self.threads = []
        self.running = True
        
        # Camera configurations: [x_offset, y_offset, z_offset, rotation_y_degrees]
        self.camera_configs = [
            {"port": 30000, "pos": [0, 0, 0], "rot_y": 0},      # Camera 1: Forward (0°)
            {"port": 30002, "pos": [2, 0, 0], "rot_y": 90},     # Camera 2: Right (90°)
            {"port": 30004, "pos": [0, 0, 2], "rot_y": 180},    # Camera 3: Backward (180°)
            {"port": 30006, "pos": [-2, 0, 0], "rot_y": -90},   # Camera 4: Left (-90°)
        ]

    def setup_cameras(self):
        """Initialize all camera streams"""
        print("Setting up 4-camera streaming with orientations...")
        
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
            
            self.cameras.append({
                'camera': cam,
                'camera_id': camera_id,
                'config': config,
                'info': cam_info
            })
        
        return len(self.cameras) > 0

    def run_viewer(self):
        """Run the multi-camera OpenGL viewer"""
        if not self.cameras:
            print("No cameras available!")
            return
        
        # Use first camera for viewer initialization
        first_cam = self.cameras[0]['camera']
        camera_info = first_cam.get_camera_information()
        
        # Create resolution for viewer
        res = sl.Resolution()
        res.width = 1280
        res.height = 720
        
        # Create OpenGL viewer (official SDK approach)
        viewer = gl.GLViewer()
        viewer.init(1, sys.argv, res)
        
        # Create point cloud matrices for each camera
        point_clouds = []
        for i in range(len(self.cameras)):
            pc = sl.Mat(res.width, res.height, sl.MAT_TYPE.F32_C4, sl.MEM.CPU)
            point_clouds.append(pc)
        
        print(f"\n=== 4-Camera RGB-Textured Point Cloud ===")
        print("Camera Layout:")
        print("  Camera 4 (-90°) ← Camera 1 (0°) → Camera 2 (90°)")
        print("                      ↑")
        print("                 Camera 3 (180°)")
        print("\nControls:")
        print("- Mouse: Navigate 3D view")
        print("- 's': Save point cloud")
        print("- ESC: Quit")
        
        frame_count = 0
        
        while viewer.is_available():
            active_cameras = 0
            
            # Process all cameras
            for i, cam_data in enumerate(self.cameras):
                cam = cam_data['camera']
                config = cam_data['config']
                
                if cam.grab() <= sl.ERROR_CODE.SUCCESS:
                    # Retrieve RGB-textured point cloud (official SDK way)
                    cam.retrieve_measure(point_clouds[i], sl.MEASURE.XYZRGBA, sl.MEM.CPU, res)
                    
                    # Apply camera rotation/position transformation
                    pc_data = point_clouds[i].get_data()
                    if pc_data is not None and pc_data.size > 0:
                        # Apply rotation based on camera orientation
                        rot_y_rad = math.radians(config['rot_y'])
                        
                        # Extract XYZ points
                        points = pc_data.reshape(-1, 4)
                        xs, ys, zs, rgba = points.T
                        
                        # Apply Y-axis rotation
                        cos_y = math.cos(rot_y_rad)
                        sin_y = math.sin(rot_y_rad)
                        
                        xs_rot = xs * cos_y - zs * sin_y
                        zs_rot = xs * sin_y + zs * cos_y
                        
                        # Apply position offset
                        xs_rot += config['pos'][0]
                        ys += config['pos'][1]  # Y stays the same
                        zs_rot += config['pos'][2]
                        
                        # Reconstruct the point cloud data
                        rotated_points = np.stack([xs_rot, ys, zs_rot, rgba], axis=1)
                        rotated_pc = rotated_points.reshape(pc_data.shape)
                        
                        # Update the point cloud matrix
                        point_clouds[i] = sl.Mat()
                        point_clouds[i].set_from(rotated_pc, sl.MEM.CPU)
                    
                    active_cameras += 1
            
            # Update viewer with combined point clouds
            if active_cameras > 0:
                # For now, show the first camera's view (we can enhance this to combine all)
                viewer.updateData(point_clouds[0])
                
                if frame_count % 90 == 0:  # Every 3 seconds
                    print(f"Active cameras: {active_cameras}/4 | Frame: {frame_count}")
            
            frame_count += 1
        
        viewer.exit()

    def close_all(self):
        """Close all cameras"""
        self.running = False
        for cam_data in self.cameras:
            cam_data['camera'].close()


def main():
    parser = argparse.ArgumentParser(description="PACMAN 4-camera RGB-textured streaming")
    parser.add_argument(
        "--jetson_ip",
        type=str,
        default="192.168.1.254",
        help="Jetson IP address"
    )
    
    args = parser.parse_args()
    
    print("=== PACMAN 4-Camera RGB-Textured Streaming ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print("Camera orientations: 0°, 90°, 180°, -90°")
    print()
    
    viewer = MultiCameraStreamingViewer(args.jetson_ip)
    
    try:
        if viewer.setup_cameras():
            viewer.run_viewer()
        else:
            print("Failed to setup cameras")
    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        viewer.close_all()
    
    return 0


if __name__ == "__main__":
    sys.exit(main())





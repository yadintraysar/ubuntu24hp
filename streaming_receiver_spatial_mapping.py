#!/usr/bin/env python3
"""
PACMAN SDK - Real-time Spatial Mapping Viewer

Connects to a PACMAN sender and builds a live 3D mesh/point cloud that you can
navigate around with mouse controls while streaming continues.

Based on PACMAN SDK spatial mapping examples with Open3D visualization.
"""

import argparse
import numpy as np
import open3d as o3d
import pyzed.sl as sl
import sys
import time
import threading
import queue


def parse_ip_port(value: str) -> tuple[str, int]:
    try:
        host, port_str = value.split(":")
        import socket
        socket.inet_aton(host)
        port = int(port_str)
        if not (1 <= port <= 65535):
            raise ValueError
        return host, port
    except Exception:
        raise argparse.ArgumentTypeError(
            "Invalid --ip_address. Use a.b.c.d:port (e.g., 192.168.1.254:30000)"
        )


class SpatialMappingViewer:
    def __init__(self, host, port, depth_mode="NEURAL", mapping_resolution="MEDIUM"):
        self.host = host
        self.port = port
        self.mesh_queue = queue.Queue(maxsize=5)
        self.running = True
        
        # Map depth modes
        depth_modes = {
            "NEURAL_LIGHT": sl.DEPTH_MODE.NEURAL_LIGHT,
            "NEURAL": sl.DEPTH_MODE.NEURAL,
            "NEURAL_PLUS": sl.DEPTH_MODE.NEURAL_PLUS
        }
        self.depth_mode = depth_modes.get(depth_mode, sl.DEPTH_MODE.NEURAL)
        
        # Map resolutions
        resolutions = {
            "LOW": sl.MAPPING_RESOLUTION.LOW,
            "MEDIUM": sl.MAPPING_RESOLUTION.MEDIUM,
            "HIGH": sl.MAPPING_RESOLUTION.HIGH
        }
        self.mapping_resolution = resolutions.get(mapping_resolution, sl.MAPPING_RESOLUTION.MEDIUM)
        
        self.cam = None
        self.mesh = sl.Mesh()
        
    def initialize_camera(self):
        """Initialize PACMAN camera with streaming and spatial mapping"""
        # Initialize camera
        init_params = sl.InitParameters()
        init_params.depth_mode = self.depth_mode
        init_params.coordinate_units = sl.UNIT.METER
        init_params.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
        init_params.depth_maximum_distance = 10.0  # 10m max range
        init_params.set_from_stream(self.host, self.port)
        
        self.cam = sl.Camera()
        status = self.cam.open(init_params)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Camera Open: {status} - Exit")
            return False
        
        # Enable positional tracking (required for spatial mapping)
        tracking_params = sl.PositionalTrackingParameters()
        tracking_params.set_floor_as_origin = True
        print("Enabling positional tracking...")
        status = self.cam.enable_positional_tracking(tracking_params)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Enable Positional Tracking: {status} - Exit")
            self.cam.close()
            return False
        
        print("Positional tracking enabled successfully")
        
        # Enable spatial mapping
        mapping_params = sl.SpatialMappingParameters()
        mapping_params.resolution_meter = sl.SpatialMappingParameters().get_resolution_preset(self.mapping_resolution)
        mapping_params.max_memory_usage = 2048  # 2GB max
        mapping_params.save_texture = False
        mapping_params.use_chunk_only = True
        mapping_params.reverse_vertex_order = False
        mapping_params.map_type = sl.SPATIAL_MAP_TYPE.MESH
        
        status = self.cam.enable_spatial_mapping(mapping_params)
        if status != sl.ERROR_CODE.SUCCESS:
            print(f"Enable Spatial Mapping: {status} - Exit")
            self.cam.disable_positional_tracking()
            self.cam.close()
            return False
        
        cam_info = self.cam.get_camera_information()
        print(f"Connected: {cam_info.camera_model} S/N {cam_info.serial_number}")
        print(f"Resolution: {cam_info.camera_configuration.resolution.width}x{cam_info.camera_configuration.resolution.height}")
        print(f"Depth mode: {init_params.depth_mode}")
        print(f"Mapping resolution: {self.mapping_resolution}")
        
        return True
    
    def capture_thread(self):
        """Background thread to capture frames and update spatial map"""
        runtime_params = sl.RuntimeParameters()
        runtime_params.confidence_threshold = 50
        
        frame_count = 0
        last_mesh_update = time.time()
        
        while self.running:
            if self.cam.grab(runtime_params) == sl.ERROR_CODE.SUCCESS:
                frame_count += 1
                
                # Request mesh update every 500ms
                current_time = time.time()
                if current_time - last_mesh_update > 0.5:
                    self.cam.request_spatial_map_async()
                    last_mesh_update = current_time
                
                # Check if mesh is ready
                if self.cam.get_spatial_map_request_status_async() == sl.ERROR_CODE.SUCCESS:
                    # Get updated mesh
                    temp_mesh = sl.Mesh()
                    self.cam.retrieve_spatial_map_async(temp_mesh)
                    
                    # Convert to Open3D format and queue for display
                    try:
                        vertices = temp_mesh.vertices
                        triangles = temp_mesh.triangles
                        
                        if len(vertices) > 0 and len(triangles) > 0:
                            # Create Open3D mesh
                            o3d_mesh = o3d.geometry.TriangleMesh()
                            o3d_mesh.vertices = o3d.utility.Vector3dVector(vertices)
                            o3d_mesh.triangles = o3d.utility.Vector3iVector(triangles)
                            o3d_mesh.compute_vertex_normals()
                            
                            # Queue for display (non-blocking)
                            try:
                                self.mesh_queue.put_nowait(o3d_mesh)
                            except queue.Full:
                                pass  # Skip if queue is full
                    except Exception as e:
                        print(f"Mesh conversion error: {e}")
                
                # Print progress every 5 seconds
                if frame_count % 150 == 0:  # ~5 seconds at 30fps
                    mapping_state = self.cam.get_spatial_mapping_state()
                    print(f"Frames: {frame_count} | Mapping: {mapping_state} | Vertices: {len(vertices) if 'vertices' in locals() else 0}")
            else:
                time.sleep(0.01)
    
    def run_viewer(self):
        """Run the interactive 3D viewer"""
        # Create Open3D visualizer
        vis = o3d.visualization.Visualizer()
        vis.create_window(window_name="PACMAN Spatial Mapping", width=1280, height=720)
        
        # Set up view controls
        ctr = vis.get_view_control()
        ctr.set_front([0.0, 0.0, -1.0])
        ctr.set_up([0.0, -1.0, 0.0])
        
        current_mesh = o3d.geometry.TriangleMesh()
        geom_added = False
        
        print("3D Viewer Controls:")
        print("- Mouse drag: rotate view")
        print("- Shift + drag: pan")
        print("- Scroll: zoom")
        print("- Close window to exit")
        
        try:
            while self.running:
                # Check for new mesh updates
                try:
                    new_mesh = self.mesh_queue.get_nowait()
                    current_mesh = new_mesh
                    
                    if not geom_added:
                        vis.add_geometry(current_mesh)
                        geom_added = True
                    else:
                        vis.update_geometry(current_mesh)
                        
                except queue.Empty:
                    pass
                
                # Update visualization
                vis.poll_events()
                vis.update_renderer()
                
                # Check if window is still open
                if not vis.poll_events():
                    break
                    
                time.sleep(0.016)  # ~60 FPS viewer
                
        except KeyboardInterrupt:
            pass
        finally:
            vis.destroy_window()
            self.running = False


def main() -> int:
    parser = argparse.ArgumentParser(description="PACMAN streaming spatial mapping viewer")
    parser.add_argument(
        "--ip_address",
        required=True,
        type=parse_ip_port,
        help="Sender IP:PORT, e.g. 192.168.1.254:30000",
    )
    parser.add_argument(
        "--depth_mode",
        type=str,
        default="NEURAL",
        choices=["NEURAL_LIGHT", "NEURAL", "NEURAL_PLUS"],
        help="Depth mode (default: NEURAL). LIGHT=fastest, PLUS=highest accuracy",
    )
    parser.add_argument(
        "--mapping_resolution",
        type=str,
        default="MEDIUM",
        choices=["LOW", "MEDIUM", "HIGH"],
        help="Mapping resolution (default: MEDIUM). Higher=more detail but slower",
    )
    args = parser.parse_args()

    host, port = args.ip_address

    print("=== PACMAN Real-time Spatial Mapping ===")
    print(f"Connecting to: {host}:{port}")
    print(f"Depth mode: {args.depth_mode}")
    print(f"Mapping resolution: {args.mapping_resolution}")
    print()

    # Create spatial mapping viewer
    viewer = SpatialMappingViewer(host, port, args.depth_mode, args.mapping_resolution)
    
    # Initialize camera and mapping
    if not viewer.initialize_camera():
        return 1
    
    print("Starting spatial mapping...")
    print("Move around in front of the camera to build the 3D map!")
    
    # Start capture thread
    capture_thread = threading.Thread(target=viewer.capture_thread, daemon=True)
    capture_thread.start()
    
    # Run interactive viewer (blocks until window closed)
    viewer.run_viewer()
    
    # Cleanup
    print("Stopping spatial mapping...")
    viewer.running = False
    capture_thread.join(timeout=2)
    
    if viewer.cam:
        viewer.cam.disable_spatial_mapping()
        viewer.cam.disable_positional_tracking()
        viewer.cam.close()
    
    print("Spatial mapping session ended.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

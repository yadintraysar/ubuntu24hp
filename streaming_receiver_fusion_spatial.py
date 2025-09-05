#!/usr/bin/env python3
"""
PACMAN SDK - Multi-Camera Fusion Spatial Mapping

Uses the PACMAN Fusion API to combine spatial mapping from 4 streaming cameras
into a unified 3D reconstruction. Assumes rectangular camera arrangement.

Based on PACMAN SDK Fusion API documentation.
"""

import argparse
import json
import numpy as np
import pyzed.sl as sl
import sys
import time
import math


def create_fusion_config(jetson_ip, base_port=30000, num_cameras=4):
    """Create fusion configuration for rectangular camera arrangement"""
    
    # Assume cameras are arranged in a rectangle, each pointing outward
    # Camera positions (in meters) and rotations (in radians)
    camera_configs = {
        1: {"pos": [0, 0, 0], "rot": [0, 0, 0]},           # Front center
        2: {"pos": [2, 0, 0], "rot": [0, math.pi/2, 0]},   # Right side  
        3: {"pos": [2, 0, 2], "rot": [0, math.pi, 0]},     # Back
        4: {"pos": [0, 0, 2], "rot": [0, -math.pi/2, 0]},  # Left side
    }
    
    config = {}
    
    for i in range(num_cameras):
        camera_id = i + 1
        port = base_port + (i * 2)
        serial_number = f"5794213{camera_id}"  # Simplified serial for config
        
        pos = camera_configs[camera_id]["pos"]
        rot = camera_configs[camera_id]["rot"]
        
        config[serial_number] = {
            "input": {
                "zed": {
                    "type": "STREAM",
                    "configuration": f"{jetson_ip}:{port}"
                },
                "fusion": {
                    "type": "LOCAL_NETWORK",
                    "configuration": {
                        "ip": jetson_ip,
                        "port": port
                    }
                }
            },
            "world": {
                "translation": pos,
                "rotation": rot
            }
        }
    
    return config


def main():
    parser = argparse.ArgumentParser(description="PACMAN multi-camera fusion spatial mapping")
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
    
    args = parser.parse_args()
    
    print("=== PACMAN Multi-Camera Fusion Spatial Mapping ===")
    print(f"Jetson IP: {args.jetson_ip}")
    print(f"Cameras: {args.num_cameras}")
    print("Assuming rectangular arrangement with cameras pointing outward")
    print()
    
    # Create fusion configuration
    fusion_config = create_fusion_config(args.jetson_ip, args.base_port, args.num_cameras)
    
    # Save config to file
    config_file = "fusion_config.json"
    with open(config_file, 'w') as f:
        json.dump(fusion_config, f, indent=2)
    print(f"Created fusion config: {config_file}")
    
    # Initialize Fusion
    init_fusion_param = sl.InitFusionParameters()
    init_fusion_param.coordinate_units = sl.UNIT.METER
    init_fusion_param.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
    
    fusion = sl.Fusion()
    
    print("Initializing Fusion...")
    fusion_status = fusion.init(init_fusion_param)
    if fusion_status != sl.FUSION_ERROR_CODE.SUCCESS:
        print(f"Fusion initialization failed: {fusion_status}")
        return 1
    
    print("Fusion initialized successfully!")
    
    # Subscribe to camera streams using config
    print("Subscribing to camera streams...")
    
    camera_identifiers = []
    for i in range(args.num_cameras):
        camera_id = i + 1
        port = args.base_port + (i * 2)
        serial_number = f"5794213{camera_id}"
        
        # Create communication parameters for this camera
        comm_param = sl.CommunicationParameters()
        comm_param.set_for_local_network(args.jetson_ip, int(port))
        
        # Subscribe to this camera
        status = fusion.subscribe(sl.CameraIdentifier(camera_id), comm_param, sl.Transform())
        if status != sl.FUSION_ERROR_CODE.SUCCESS:
            print(f"Failed to subscribe to Camera {camera_id}: {status}")
        else:
            print(f"✓ Subscribed to Camera {camera_id} on port {port}")
            camera_identifiers.append(sl.CameraIdentifier(camera_id))
    
    if len(camera_identifiers) == 0:
        print("No cameras subscribed successfully!")
        fusion.close()
        return 1
    
    # Enable spatial mapping
    spatial_mapping_param = sl.SpatialMappingParameters()
    spatial_mapping_param.resolution_meter = 0.05  # 5cm resolution
    spatial_mapping_param.max_memory_usage = 4096  # 4GB
    spatial_mapping_param.save_texture = False
    
    print("Enabling fusion spatial mapping...")
    status = fusion.enable_spatial_mapping(spatial_mapping_param)
    if status != sl.FUSION_ERROR_CODE.SUCCESS:
        print(f"Failed to enable spatial mapping: {status}")
        fusion.close()
        return 1
    
    print("✓ Fusion spatial mapping enabled!")
    
    # Main fusion loop
    print("\nStarting multi-camera spatial mapping fusion...")
    print("Building unified 3D map from all cameras...")
    print("Press Ctrl+C to stop and save mesh")
    
    mesh = sl.Mesh()
    frame_count = 0
    start_time = time.time()
    
    try:
        while True:
            # Process fusion data
            fusion_status = fusion.process()
            if fusion_status == sl.FUSION_ERROR_CODE.SUCCESS:
                frame_count += 1
                
                # Print progress every 5 seconds
                if frame_count % 150 == 0:  # ~5 seconds at 30fps
                    elapsed = time.time() - start_time
                    mapping_state = fusion.get_spatial_mapping_state()
                    print(f"Frames: {frame_count} | Time: {elapsed:.1f}s | Mapping: {mapping_state}")
                
                # Request mesh update every second
                if frame_count % 30 == 0:
                    fusion.request_spatial_map_async()
                
                # Check if mesh is ready
                if fusion.get_spatial_map_request_status_async() == sl.FUSION_ERROR_CODE.SUCCESS:
                    fusion.retrieve_spatial_map_async(mesh)
                    vertices_count = len(mesh.vertices) if hasattr(mesh, 'vertices') else 0
                    if vertices_count > 0:
                        print(f"Mesh updated: {vertices_count} vertices")
            
            time.sleep(0.033)  # ~30 FPS
            
    except KeyboardInterrupt:
        print("\nStopping fusion and saving mesh...")
        
        # Extract final mesh
        print("Extracting final fused mesh...")
        status = fusion.extract_whole_spatial_map(mesh)
        if status == sl.FUSION_ERROR_CODE.SUCCESS:
            # Filter and save mesh
            filter_params = sl.MeshFilterParameters()
            mesh.filter(filter_params)
            
            mesh_file = "fusion_spatial_map.obj"
            if mesh.save(mesh_file):
                print(f"✓ Fused mesh saved: {mesh_file}")
                print(f"  Vertices: {len(mesh.vertices) if hasattr(mesh, 'vertices') else 0}")
                print(f"  Triangles: {len(mesh.triangles) if hasattr(mesh, 'triangles') else 0}")
            else:
                print(f"✗ Failed to save mesh: {mesh_file}")
        else:
            print(f"Failed to extract mesh: {status}")
    
    # Cleanup
    fusion.disable_spatial_mapping()
    fusion.close()
    
    print("Multi-camera fusion spatial mapping complete!")
    return 0


if __name__ == "__main__":
    sys.exit(main())

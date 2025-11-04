#!/usr/bin/env python3
"""
PACMAN Simple Spatial Mapping - No 3D Viewer
Robust spatial mapping without OpenGL viewer to avoid crashes.
Just camera feed + automatic mesh saving.
"""
import sys
import time
import pyzed.sl as sl
import argparse
import cv2
import signal
import traceback
from datetime import datetime

# Global flag for graceful shutdown
shutdown_requested = False
mapping_toggle = False

def signal_handler(sig, frame):
    global shutdown_requested
    print("\n[INFO] Shutdown signal received...")
    shutdown_requested = True

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def parse_ip_port(value: str):
    try:
        host, port_str = value.split(":")
        port = int(port_str)
        return host, port
    except:
        raise argparse.ArgumentTypeError("Invalid IP format. Use a.b.c.d:port")

def main():
    global shutdown_requested, mapping_toggle
    
    parser = argparse.ArgumentParser(description="PACMAN Simple Spatial Mapping")
    parser.add_argument('--ip_address', required=True, type=parse_ip_port,
                       help='IP:PORT, e.g. 10.0.0.31:30002')
    parser.add_argument('--resolution', type=str, default='HD720',
                       help='Resolution: HD2K, HD1200, HD1080, HD720, VGA')
    parser.add_argument('--auto_save_interval', type=int, default=300,
                       help='Auto-save mesh every N seconds (default: 300 = 5min)')
    args = parser.parse_args()
    
    host, port = args.ip_address
    
    print("=" * 50)
    print("PACMAN Simple Spatial Mapping")
    print("=" * 50)
    print(f"Connecting to: {host}:{port}")
    print("Controls:")
    print("  - Press 's' to save mesh manually")
    print("  - Press 'm' to toggle mapping on/off")
    print("  - Press 'q' to quit")
    print("=" * 50)
    
    # Initialize camera
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.NEURAL
    init_params.coordinate_units = sl.UNIT.METER
    init_params.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
    init_params.depth_maximum_distance = 10.0
    init_params.set_from_stream(host, port)
    
    # Set resolution
    if args.resolution == 'HD720':
        init_params.camera_resolution = sl.RESOLUTION.HD720
    elif args.resolution == 'VGA':
        init_params.camera_resolution = sl.RESOLUTION.VGA
    
    cam = sl.Camera()
    status = cam.open(init_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f"[ERROR] Camera Open: {status}")
        return 1
    
    print("[INFO] Camera opened successfully")
    
    # Enable positional tracking
    tracking_params = sl.PositionalTrackingParameters()
    tracking_params.set_floor_as_origin = True
    status = cam.enable_positional_tracking(tracking_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f"[WARNING] Positional tracking failed: {status}")
    else:
        print("[INFO] Positional tracking enabled")
    
    # Wait for tracking to stabilize
    print("[INFO] Waiting for tracking to stabilize...")
    runtime_params_init = sl.RuntimeParameters()
    for i in range(20):  # Grab a few frames to let tracking initialize
        if cam.grab(runtime_params_init) == sl.ERROR_CODE.SUCCESS:
            time.sleep(0.05)
    print("[INFO] Tracking stabilized")
    
    # Configure spatial mapping (but don't start yet)
    mapping_params = sl.SpatialMappingParameters()
    mapping_params.resolution_meter = sl.SpatialMappingParameters().get_resolution_preset(sl.MAPPING_RESOLUTION.MEDIUM)
    mapping_params.max_memory_usage = 2048
    mapping_params.save_texture = False
    mapping_params.use_chunk_only = True
    mapping_params.reverse_vertex_order = False
    mapping_params.map_type = sl.SPATIAL_MAP_TYPE.MESH
    
    print("[INFO] Spatial mapping configured (press 'm' to start)")
    mapping_active = False
    
    # Create mesh object
    mesh = sl.Mesh()
    
    # Runtime parameters
    runtime_params = sl.RuntimeParameters()
    runtime_params.confidence_threshold = 50
    
    # Data containers
    image = sl.Mat()
    
    # Stats
    total_frames = 0
    successful_frames = 0
    corrupted_frames = 0
    last_save_time = time.time()
    last_status_time = time.time()
    start_time = time.time()
    last_request_time = time.time()
    
    # Create window
    cv2.namedWindow("PACMAN Camera", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("PACMAN Camera", 1280, 720)
    
    print("[INFO] Starting main loop...")
    
    while not shutdown_requested:
        total_frames += 1
        
        # Periodic status
        if time.time() - last_status_time > 60:
            uptime = time.time() - start_time
            success_rate = (successful_frames / total_frames * 100) if total_frames > 0 else 0
            print(f"\n[STATUS] Uptime: {uptime/60:.1f}min | "
                  f"Frames: {successful_frames}/{total_frames} ({success_rate:.1f}%) | "
                  f"Corrupted: {corrupted_frames}")
            last_status_time = time.time()
        
        # Grab frame
        grab_status = cam.grab(runtime_params)
        
        if grab_status == sl.ERROR_CODE.SUCCESS:
            successful_frames += 1
            
            # Retrieve image
            cam.retrieve_image(image, sl.VIEW.LEFT)
            
            # Update spatial map periodically
            if mapping_active and (time.time() - last_request_time > 0.5):
                cam.request_spatial_map_async()
                last_request_time = time.time()
                
                # Try to retrieve if ready
                if cam.get_spatial_map_request_status_async() == sl.ERROR_CODE.SUCCESS:
                    cam.retrieve_spatial_map_async(mesh)
            
            # Display image
            try:
                image_cv = image.get_data()
                
                # Add status overlay
                overlay_text = f"Mapping: {'ON' if mapping_active else 'OFF'} | Frames: {successful_frames}"
                cv2.putText(image_cv, overlay_text, (10, 30), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                
                cv2.imshow("PACMAN Camera", image_cv)
                
                # Handle keys
                key = cv2.waitKey(1) & 0xFF
                
                if key == ord('q'):
                    print("[INFO] Quit requested")
                    break
                elif key == ord('s'):
                    # Manual save
                    if mapping_active:
                        print("[INFO] Manually saving mesh...")
                        cam.extract_whole_spatial_map(mesh)
                        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                        filepath = f"pacman_mesh_{timestamp}.obj"
                        if mesh.save(filepath):
                            print(f"[SUCCESS] Mesh saved: {filepath}")
                        else:
                            print(f"[ERROR] Failed to save: {filepath}")
                        last_save_time = time.time()
                    else:
                        print("[WARNING] Mapping not active. Press 'm' to start mapping first.")
                elif key == ord('m'):
                    # Toggle mapping
                    if mapping_active:
                        print("[INFO] Stopping spatial mapping")
                        cam.disable_spatial_mapping()
                        mapping_active = False
                    else:
                        print("[INFO] Starting spatial mapping...")
                        # Reset tracking and enable mapping
                        init_pose = sl.Transform()
                        cam.reset_positional_tracking(init_pose)
                        status = cam.enable_spatial_mapping(mapping_params)
                        if status == sl.ERROR_CODE.SUCCESS:
                            print("[INFO] Spatial mapping STARTED successfully!")
                            mapping_active = True
                            mesh.clear()
                            last_request_time = time.time()
                        else:
                            print(f"[ERROR] Failed to start spatial mapping: {status}")
                            mapping_active = False
                        
            except Exception as e:
                print(f"[WARNING] Display error: {e}")
            
            # Auto-save (only if mapping is active)
            if mapping_active and args.auto_save_interval > 0 and (time.time() - last_save_time > args.auto_save_interval):
                print(f"[INFO] Auto-saving mesh (every {args.auto_save_interval}s)...")
                try:
                    cam.extract_whole_spatial_map(mesh)
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    filepath = f"pacman_mesh_auto_{timestamp}.obj"
                    if mesh.save(filepath):
                        print(f"[SUCCESS] Auto-saved: {filepath}")
                    else:
                        print(f"[ERROR] Auto-save failed: {filepath}")
                except Exception as e:
                    print(f"[ERROR] Auto-save exception: {e}")
                last_save_time = time.time()
        
        elif grab_status == sl.ERROR_CODE.CORRUPTED_FRAME:
            corrupted_frames += 1
            if corrupted_frames % 50 == 0:
                print(f"[DEBUG] Corrupted frames: {corrupted_frames}")
        else:
            print(f"[WARNING] Grab failed: {grab_status}")
            time.sleep(0.01)
    
    # Final save (only if mapping was active)
    if mapping_active:
        print("\n[INFO] Saving final mesh...")
        try:
            cam.extract_whole_spatial_map(mesh)
            
            # Apply filter
            filter_params = sl.MeshFilterParameters()
            filter_params.set(sl.MESH_FILTER.MEDIUM)
            mesh.filter(filter_params, True)
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filepath = f"pacman_mesh_final_{timestamp}.obj"
            if mesh.save(filepath):
                print(f"[SUCCESS] Final mesh saved: {filepath}")
            else:
                print(f"[ERROR] Failed to save final mesh")
        except Exception as e:
            print(f"[ERROR] Final save error: {e}")
            traceback.print_exc()
    else:
        print("\n[INFO] No mapping was active, skipping final save")
    
    # Cleanup
    print("[INFO] Cleaning up...")
    cv2.destroyAllWindows()
    mesh.clear()
    if mapping_active:
        cam.disable_spatial_mapping()
    cam.disable_positional_tracking()
    cam.close()
    
    # Final stats
    uptime = time.time() - start_time
    success_rate = (successful_frames / total_frames * 100) if total_frames > 0 else 0
    print("\n" + "=" * 50)
    print("Final Statistics:")
    print(f"  Total runtime: {uptime/60:.1f} minutes")
    print(f"  Total frames: {total_frames}")
    print(f"  Successful: {successful_frames} ({success_rate:.1f}%)")
    print(f"  Corrupted: {corrupted_frames}")
    print("=" * 50)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())


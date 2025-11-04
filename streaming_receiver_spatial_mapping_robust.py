#!/usr/bin/env python3
########################################################################
# PACMAN Robust Spatial Mapping - Long Duration Vehicle Operation
#
# Enhanced version with comprehensive error handling for corrupted frames
# and network issues. Designed for hours-long operation on moving vehicles.
########################################################################

"""
    Robust spatial mapping that handles corrupted frames gracefully.
    Will keep running even with network issues or frame corruption.
"""
import sys
import time
import pyzed.sl as sl
import ogl_viewer.viewer_spatial_mapping as gl
import argparse
import cv2
import signal
import traceback
from datetime import datetime

# Global flag for graceful shutdown
shutdown_requested = False

def signal_handler(sig, frame):
    global shutdown_requested
    print("\n[INFO] Shutdown signal received. Cleaning up...")
    shutdown_requested = True

# Register signal handlers
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

class RobustSpatialMapper:
    def __init__(self, opt):
        self.opt = opt
        self.zed = None
        self.viewer = None
        self.pymesh = None
        
        # Error tracking
        self.consecutive_errors = 0
        self.total_frames = 0
        self.corrupted_frames = 0
        self.successful_frames = 0
        self.last_successful_grab = time.time()
        
        # Recovery parameters
        self.max_consecutive_errors = 50
        self.reconnect_timeout = 5.0
        self.max_frame_gap = 10.0  # seconds
        
        # Status reporting
        self.last_status_report = time.time()
        self.status_report_interval = 60.0  # Report every 60 seconds
        
    def log(self, message, level="INFO"):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
    
    def print_status(self):
        """Print periodic status report"""
        uptime = time.time() - self.start_time
        success_rate = (self.successful_frames / self.total_frames * 100) if self.total_frames > 0 else 0
        
        self.log(f"Status Report:")
        self.log(f"  Uptime: {uptime:.1f}s ({uptime/60:.1f} min)")
        self.log(f"  Total frames: {self.total_frames}")
        self.log(f"  Successful: {self.successful_frames} ({success_rate:.1f}%)")
        self.log(f"  Corrupted: {self.corrupted_frames}")
        self.log(f"  Consecutive errors: {self.consecutive_errors}")
    
    def initialize_camera(self):
        """Initialize camera with error handling"""
        try:
            init = sl.InitParameters()
            init.depth_mode = sl.DEPTH_MODE.NEURAL
            init.coordinate_units = sl.UNIT.METER
            init.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
            init.depth_maximum_distance = 8.
            
            # Parse input arguments
            self.parse_args(init)
            
            # Set timeout for streaming
            init.open_timeout_sec = 10.0
            
            self.zed = sl.Camera()
            status = self.zed.open(init)
            
            if status != sl.ERROR_CODE.SUCCESS:
                self.log(f"Camera Open failed: {repr(status)}", "ERROR")
                return False
            
            self.log("Camera opened successfully")
            return True
            
        except Exception as e:
            self.log(f"Exception during camera initialization: {e}", "ERROR")
            traceback.print_exc()
            return False
    
    def initialize_tracking(self):
        """Initialize positional tracking with error handling"""
        try:
            positional_tracking_parameters = sl.PositionalTrackingParameters()
            positional_tracking_parameters.set_floor_as_origin = True
            
            returned_state = self.zed.enable_positional_tracking(positional_tracking_parameters)
            
            if returned_state != sl.ERROR_CODE.SUCCESS:
                self.log(f"Enable Positional Tracking failed: {repr(returned_state)}", "WARNING")
                # Continue anyway - not critical for basic operation
            else:
                self.log("Positional tracking enabled")
            
            return True
            
        except Exception as e:
            self.log(f"Exception during tracking initialization: {e}", "WARNING")
            return True  # Non-critical, continue
    
    def initialize_mapping(self):
        """Initialize spatial mapping"""
        try:
            if self.opt.build_mesh:
                spatial_mapping_parameters = sl.SpatialMappingParameters(
                    resolution=sl.MAPPING_RESOLUTION.MEDIUM,
                    mapping_range=sl.MAPPING_RANGE.MEDIUM,
                    max_memory_usage=2048,
                    save_texture=False,
                    use_chunk_only=True,
                    reverse_vertex_order=False,
                    map_type=sl.SPATIAL_MAP_TYPE.MESH
                )
                self.pymesh = sl.Mesh()
            else:
                spatial_mapping_parameters = sl.SpatialMappingParameters(
                    resolution=sl.MAPPING_RESOLUTION.MEDIUM,
                    mapping_range=sl.MAPPING_RANGE.MEDIUM,
                    max_memory_usage=2048,
                    save_texture=False,
                    use_chunk_only=True,
                    reverse_vertex_order=False,
                    map_type=sl.SPATIAL_MAP_TYPE.FUSED_POINT_CLOUD
                )
                self.pymesh = sl.FusedPointCloud()
            
            self.spatial_mapping_parameters = spatial_mapping_parameters
            self.log("Spatial mapping initialized")
            return True
            
        except Exception as e:
            self.log(f"Exception during mapping initialization: {e}", "ERROR")
            traceback.print_exc()
            return False
    
    def initialize_viewer(self):
        """Initialize OpenGL viewer with error handling"""
        try:
            camera_infos = self.zed.get_camera_information()
            self.viewer = gl.GLViewer()
            self.viewer.init(
                camera_infos.camera_configuration.calibration_parameters.left_cam,
                self.pymesh,
                int(self.opt.build_mesh)
            )
            self.log("OpenGL viewer initialized")
            return True
            
        except Exception as e:
            self.log(f"Exception during viewer initialization: {e}", "WARNING")
            self.log("Will continue without 3D viewer")
            self.viewer = None
            return True  # Non-critical for data collection
    
    def initialize_cv_window(self):
        """Initialize OpenCV window with error handling"""
        try:
            cv2.namedWindow("Camera View", cv2.WINDOW_NORMAL)
            cv2.resizeWindow("Camera View", 1280, 720)
            self.log("Camera view window created")
            return True
        except Exception as e:
            self.log(f"Exception creating CV window: {e}", "WARNING")
            return True  # Non-critical
    
    def check_connection_health(self):
        """Check if connection is still healthy"""
        time_since_success = time.time() - self.last_successful_grab
        
        if time_since_success > self.max_frame_gap:
            self.log(f"No successful frames for {time_since_success:.1f}s", "WARNING")
            return False
        
        if self.consecutive_errors > self.max_consecutive_errors:
            self.log(f"Too many consecutive errors: {self.consecutive_errors}", "WARNING")
            return False
        
        return True
    
    def attempt_reconnection(self):
        """Attempt to reconnect the camera"""
        self.log("Attempting reconnection...", "WARNING")
        
        try:
            if self.zed is not None:
                self.zed.close()
            
            time.sleep(self.reconnect_timeout)
            
            if self.initialize_camera():
                self.initialize_tracking()
                self.consecutive_errors = 0
                self.last_successful_grab = time.time()
                self.log("Reconnection successful!")
                return True
            else:
                self.log("Reconnection failed", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"Exception during reconnection: {e}", "ERROR")
            return False
    
    def parse_args(self, init):
        """Parse command line arguments"""
        opt = self.opt
        
        if len(opt.input_svo_file) > 0 and opt.input_svo_file.endswith((".svo", ".svo2")):
            init.set_from_svo_file(opt.input_svo_file)
            self.log(f"Using SVO File input: {opt.input_svo_file}")
        elif len(opt.ip_address) > 0:
            ip_str = opt.ip_address
            if ip_str.replace(':', '').replace('.', '').isdigit() and len(ip_str.split('.')) == 4 and len(ip_str.split(':')) == 2:
                init.set_from_stream(ip_str.split(':')[0], int(ip_str.split(':')[1]))
                self.log(f"Using Stream input, IP: {ip_str}")
            elif ip_str.replace(':', '').replace('.', '').isdigit() and len(ip_str.split('.')) == 4:
                init.set_from_stream(ip_str)
                self.log(f"Using Stream input, IP: {ip_str}")
            else:
                self.log("Invalid IP format. Using live stream", "WARNING")
        
        # Resolution settings
        if "HD2K" in opt.resolution:
            init.camera_resolution = sl.RESOLUTION.HD2K
        elif "HD1200" in opt.resolution:
            init.camera_resolution = sl.RESOLUTION.HD1200
        elif "HD1080" in opt.resolution:
            init.camera_resolution = sl.RESOLUTION.HD1080
        elif "HD720" in opt.resolution:
            init.camera_resolution = sl.RESOLUTION.HD720
        elif "SVGA" in opt.resolution:
            init.camera_resolution = sl.RESOLUTION.SVGA
        elif "VGA" in opt.resolution:
            init.camera_resolution = sl.RESOLUTION.VGA
        else:
            self.log("Using default resolution")
    
    def run(self):
        """Main run loop with comprehensive error handling"""
        global shutdown_requested
        
        self.start_time = time.time()
        
        # Initialize all components
        self.log("=== PACMAN Robust Spatial Mapping Started ===")
        
        if not self.initialize_camera():
            return 1
        
        if not self.initialize_tracking():
            self.log("Warning: Tracking initialization had issues", "WARNING")
        
        if not self.initialize_mapping():
            return 1
        
        if not self.initialize_viewer():
            self.log("Warning: Running without 3D viewer", "WARNING")
        
        self.initialize_cv_window()
        
        # Runtime parameters with lower confidence for more data
        runtime_parameters = sl.RuntimeParameters()
        runtime_parameters.confidence_threshold = 50
        
        # Mapping state
        mapping_activated = False
        mapping_state = sl.SPATIAL_MAPPING_STATE.NOT_ENABLED
        tracking_state = sl.POSITIONAL_TRACKING_STATE.OFF
        
        # Data containers
        image = sl.Mat()
        pose = sl.Pose()
        
        last_call = time.time()
        
        self.log("Press 'Space' to enable/disable spatial mapping")
        self.log("Press 'q' to quit gracefully")
        self.log("Disable mapping to save .obj mesh file")
        self.log("===========================================")
        
        # Main loop
        while not shutdown_requested:
            self.total_frames += 1
            
            # Check if viewer is still available (if it exists)
            if self.viewer is not None and not self.viewer.is_available():
                self.log("Viewer window closed")
                break
            
            # Periodic status report
            if time.time() - self.last_status_report > self.status_report_interval:
                self.print_status()
                self.last_status_report = time.time()
            
            # Check connection health
            if not self.check_connection_health():
                if not self.attempt_reconnection():
                    self.log("Failed to recover connection. Continuing to retry...", "ERROR")
                    time.sleep(5)
                    continue
            
            try:
                # Attempt to grab frame
                grab_status = self.zed.grab(runtime_parameters)
                
                if grab_status == sl.ERROR_CODE.SUCCESS:
                    # Successful frame grab
                    self.consecutive_errors = 0
                    self.successful_frames += 1
                    self.last_successful_grab = time.time()
                    
                    # Retrieve image
                    try:
                        self.zed.retrieve_image(image, sl.VIEW.LEFT)
                        tracking_state = self.zed.get_position(pose)
                        
                        # Handle spatial mapping
                        if mapping_activated:
                            try:
                                mapping_state = self.zed.get_spatial_mapping_state()
                                duration = time.time() - last_call
                                
                                # Request map updates periodically
                                if duration > 0.5:
                                    self.zed.request_spatial_map_async()
                                    last_call = time.time()
                                
                                # Retrieve map if ready
                                if self.zed.get_spatial_map_request_status_async() == sl.ERROR_CODE.SUCCESS:
                                    self.zed.retrieve_spatial_map_async(self.pymesh)
                            except Exception as e:
                                self.log(f"Mapping update error (non-critical): {e}", "DEBUG")
                                traceback.print_exc()
                        
                        # Update viewer if available
                        if self.viewer:
                            try:
                                change_state = self.viewer.update_view(image, pose.pose_data(), tracking_state, mapping_state)
                                
                                if change_state:
                                    if not mapping_activated:
                                        # Start mapping
                                        self.log("Activating spatial mapping")
                                        try:
                                            init_pose = sl.Transform()
                                            self.zed.reset_positional_tracking(init_pose)
                                            self.zed.enable_spatial_mapping(self.spatial_mapping_parameters)
                                            self.pymesh.clear()
                                            last_call = time.time()
                                            mapping_activated = True
                                            self.log("Spatial mapping activated successfully")
                                        except Exception as e:
                                            self.log(f"Failed to activate mapping: {e}", "ERROR")
                                            traceback.print_exc()
                                            mapping_activated = False
                                    else:
                                        # Stop mapping and save
                                        self.log("Extracting and saving mesh...")
                                        try:
                                            self.zed.extract_whole_spatial_map(self.pymesh)
                                            
                                            if self.opt.build_mesh:
                                                filter_params = sl.MeshFilterParameters()
                                                filter_params.set(sl.MESH_FILTER.MEDIUM)
                                                self.pymesh.filter(filter_params, True)
                                            
                                            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                                            filepath = f"pacman_mesh_{timestamp}.obj"
                                            status = self.pymesh.save(filepath)
                                            
                                            if status:
                                                self.log(f"Mesh saved: {filepath}")
                                            else:
                                                self.log(f"Failed to save mesh: {filepath}", "ERROR")
                                            
                                            mapping_activated = False
                                            mapping_state = sl.SPATIAL_MAPPING_STATE.NOT_ENABLED
                                        except Exception as e:
                                            self.log(f"Failed to save mesh: {e}", "ERROR")
                                            traceback.print_exc()
                            except Exception as e:
                                self.log(f"Viewer update error: {e}", "WARNING")
                                traceback.print_exc()
                        
                        # Display camera image
                        try:
                            image_ocv = image.get_data()
                            cv2.imshow("Camera View", image_ocv)
                            key = cv2.waitKey(1) & 0xFF
                            
                            if key == ord('q'):
                                self.log("Quit key pressed")
                                break
                            elif key == ord(' '):
                                # Manual toggle mapping
                                if not mapping_activated:
                                    self.log("Manually activating spatial mapping")
                                    init_pose = sl.Transform()
                                    self.zed.reset_positional_tracking(init_pose)
                                    self.zed.enable_spatial_mapping(self.spatial_mapping_parameters)
                                    self.pymesh.clear()
                                    if self.viewer:
                                        self.viewer.clear_current_mesh()
                                    last_call = time.time()
                                    mapping_activated = True
                                else:
                                    self.log("Manually stopping mapping and saving...")
                                    self.zed.extract_whole_spatial_map(self.pymesh)
                                    
                                    if self.opt.build_mesh:
                                        filter_params = sl.MeshFilterParameters()
                                        filter_params.set(sl.MESH_FILTER.MEDIUM)
                                        self.pymesh.filter(filter_params, True)
                                        if self.viewer:
                                            self.viewer.clear_current_mesh()
                                    
                                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                                    filepath = f"pacman_mesh_{timestamp}.obj"
                                    status = self.pymesh.save(filepath)
                                    
                                    if status:
                                        self.log(f"Mesh saved: {filepath}")
                                    else:
                                        self.log(f"Failed to save mesh: {filepath}", "ERROR")
                                    
                                    mapping_activated = False
                                    mapping_state = sl.SPATIAL_MAPPING_STATE.NOT_ENABLED
                                    
                        except Exception as e:
                            self.log(f"Display error (continuing): {e}", "DEBUG")
                    
                    except Exception as e:
                        self.log(f"Frame processing error: {e}", "WARNING")
                        self.consecutive_errors += 1
                        self.corrupted_frames += 1
                
                else:
                    # Frame grab failed
                    self.consecutive_errors += 1
                    self.corrupted_frames += 1
                    
                    if grab_status == sl.ERROR_CODE.CORRUPTED_FRAME:
                        # Corrupted frame - just skip it
                        if self.corrupted_frames % 10 == 0:  # Log every 10th
                            self.log(f"Corrupted frame (total: {self.corrupted_frames})", "DEBUG")
                    else:
                        self.log(f"Grab failed: {repr(grab_status)}", "WARNING")
                    
                    # Small delay before retry
                    time.sleep(0.001)
            
            except Exception as e:
                self.log(f"Unexpected error in main loop: {e}", "ERROR")
                traceback.print_exc()
                self.consecutive_errors += 1
                time.sleep(0.1)
        
        # Cleanup
        self.log("=== Shutting down gracefully ===")
        self.print_status()
        
        try:
            cv2.destroyAllWindows()
        except:
            pass
        
        try:
            if self.viewer:
                self.viewer.exit()
        except:
            pass
        
        try:
            if self.pymesh:
                self.pymesh.clear()
        except:
            pass
        
        try:
            if self.zed:
                self.zed.disable_spatial_mapping()
                self.zed.disable_positional_tracking()
                self.zed.close()
        except:
            pass
        
        self.log("=== Shutdown complete ===")
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Robust PACMAN Spatial Mapping for Long Duration Operation")
    parser.add_argument('--input_svo_file', type=str, help='Path to an .svo file', default='')
    parser.add_argument('--ip_address', type=str, help='IP Address, format a.b.c.d:port or a.b.c.d', default='')
    parser.add_argument('--resolution', type=str, help='Resolution: HD2K, HD1200, HD1080, HD720, SVGA or VGA', default='')
    parser.add_argument('--build_mesh', help='Build mesh (vs point cloud)', action='store_true')
    opt = parser.parse_args()
    
    if len(opt.input_svo_file) > 0 and len(opt.ip_address) > 0:
        print("Specify only input_svo_file OR ip_address, not both. Exit.")
        sys.exit(1)
    
    mapper = RobustSpatialMapper(opt)
    sys.exit(mapper.run())


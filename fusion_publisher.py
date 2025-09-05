#!/usr/bin/env python3
import pyzed.sl as sl
import threading
import signal
import time
import sys

exit_app = False

def signal_handler(signal, frame):
    global exit_app
    exit_app = True
    print('\nCtrl+C pressed. Exiting...')

def camera_publisher(camera_id, serial_number, port):
    print(f'Starting Camera {camera_id} publisher S/N:{serial_number} on port {port}')
    
    # Initialize camera
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.NEURAL
    init_params.coordinate_units = sl.UNIT.METER
    init_params.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
    init_params.set_from_serial_number(serial_number)
    
    cam = sl.Camera()
    status = cam.open(init_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f'Camera {camera_id}: Failed to open - {status}')
        return
    
    # Enable positional tracking (required for spatial mapping fusion)
    tracking_params = sl.PositionalTrackingParameters()
    tracking_params.set_as_static = True
    status = cam.enable_positional_tracking(tracking_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f'Camera {camera_id}: Failed to enable tracking - {status}')
        cam.close()
        return
    
    # Enable spatial mapping (instead of body tracking)
    spatial_mapping_params = sl.SpatialMappingParameters()
    spatial_mapping_params.resolution_meter = 0.05  # 5cm resolution
    spatial_mapping_params.max_memory_usage = 1024  # 1GB per camera
    spatial_mapping_params.save_texture = True  # Enable texture for RGB
    spatial_mapping_params.map_type = sl.SPATIAL_MAP_TYPE.MESH
    
    status = cam.enable_spatial_mapping(spatial_mapping_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f'Camera {camera_id}: Failed to enable spatial mapping - {status}')
        cam.disable_positional_tracking()
        cam.close()
        return
    
    # Start publishing for Fusion (network mode to match config)
    comm_params = sl.CommunicationParameters()
    comm_params.set_for_local_network(port)  # Publish on specific port for network access
    status = cam.start_publishing(comm_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print(f'Camera {camera_id}: Failed to start publishing - {status}')
        cam.disable_positional_tracking()
        cam.close()
        return
    
    print(f'Camera {camera_id}: Publishing on port {port}')
    
    # Keep grabbing frames for fusion
    frame_count = 0
    while not exit_app:
        if cam.grab() == sl.ERROR_CODE.SUCCESS:
            frame_count += 1
            if frame_count % 300 == 0:  # Every 10 seconds
                print(f'Camera {camera_id}: {frame_count} frames published')
        else:
            time.sleep(0.01)
    
    print(f'Camera {camera_id}: Stopping publisher')
    cam.disable_spatial_mapping()
    cam.disable_positional_tracking()
    cam.close()

def main():
    global exit_app
    
    print('=== PACMAN Fusion Publishers ===')
    
    # Get available cameras
    cameras = sl.Camera.get_device_list()
    print(f'Found {len(cameras)} cameras:')
    
    for i, cam in enumerate(cameras):
        print(f'  Camera {i+1}: {cam.camera_model} S/N:{cam.serial_number}')
    
    if len(cameras) == 0:
        print('No cameras detected!')
        return 1
    
    # Use up to 4 cameras with specific ports
    ports = [30000, 30002, 30004, 30006]
    threads = []
    
    signal.signal(signal.SIGINT, signal_handler)
    
    for i in range(min(len(cameras), 4)):
        camera_id = i + 1
        serial_number = cameras[i].serial_number
        port = ports[i]
        
        thread = threading.Thread(
            target=camera_publisher,
            args=(camera_id, serial_number, port),
            name=f'Publisher-{camera_id}'
        )
        thread.start()
        threads.append(thread)
        time.sleep(2)  # Stagger startup
    
    print(f'\nPublishing from {len(threads)} cameras for Fusion...')
    print('Fusion subscriber can now connect!')
    
    # Main loop
    while not exit_app:
        time.sleep(0.1)
    
    # Wait for threads
    print('Stopping all publishers...')
    for thread in threads:
        thread.join(timeout=5)
    
    print('Fusion publishers stopped.')
    return 0

if __name__ == '__main__':
    sys.exit(main())

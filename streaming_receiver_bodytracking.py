#!/usr/bin/env python3
"""
PACMAN SDK - Streaming Body Tracking Receiver

Connects to a PACMAN sender over the network and performs real-time body tracking
with 2D skeleton overlay and 3D visualization.

Based on PACMAN SDK body tracking examples.
"""

import argparse
import cv2
import numpy as np
import pyzed.sl as sl
import sys
import time


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


def render_skeleton_2d(image, keypoints_2d, body_format):
    """Draw 2D skeleton on image"""
    if body_format == sl.BODY_FORMAT.BODY_18:
        # BODY_18 skeleton connections
        skeleton_connections = [
            (1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7),
            (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13),
            (1, 0), (0, 14), (14, 16), (0, 15), (15, 17)
        ]
    else:
        # BODY_34 or other formats - simplified
        skeleton_connections = [
            (1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7),
            (1, 8), (8, 9), (9, 10), (1, 11), (11, 12), (12, 13)
        ]

    # Draw keypoints
    for kp in keypoints_2d:
        if kp[0] > 0 and kp[1] > 0:  # Valid keypoint
            cv2.circle(image, (int(kp[0]), int(kp[1])), 4, (0, 255, 0), -1)

    # Draw skeleton connections
    for connection in skeleton_connections:
        if (connection[0] < len(keypoints_2d) and connection[1] < len(keypoints_2d)):
            pt1 = keypoints_2d[connection[0]]
            pt2 = keypoints_2d[connection[1]]
            if (pt1[0] > 0 and pt1[1] > 0 and pt2[0] > 0 and pt2[1] > 0):
                cv2.line(image, (int(pt1[0]), int(pt1[1])), 
                        (int(pt2[0]), int(pt2[1])), (255, 0, 0), 2)


def main() -> int:
    parser = argparse.ArgumentParser(description="PACMAN body tracking receiver")
    parser.add_argument(
        "--ip_address",
        required=True,
        type=parse_ip_port,
        help="Sender IP:PORT, e.g. 192.168.1.254:30000",
    )
    parser.add_argument(
        "--confidence",
        type=int,
        default=40,
        help="Detection confidence threshold (0-100, default: 40)",
    )
    args = parser.parse_args()

    host, port = args.ip_address

    # Initialize PACMAN camera in streaming mode
    init_params = sl.InitParameters()
    init_params.depth_mode = sl.DEPTH_MODE.NEURAL
    init_params.sdk_verbose = 1
    init_params.coordinate_units = sl.UNIT.METER
    init_params.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
    init_params.set_from_stream(host, port)

    cam = sl.Camera()
    status = cam.open(init_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print("Camera Open:", status, "- Exit")
        return 1

    # Enable Positional tracking (required for body tracking)
    positional_tracking_params = sl.PositionalTrackingParameters()
    positional_tracking_params.set_floor_as_origin = True
    status = cam.enable_positional_tracking(positional_tracking_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print("Enable Positional Tracking:", status, "- Exit")
        cam.close()
        return 1

    # Configure body tracking
    body_params = sl.BodyTrackingParameters()
    body_params.enable_tracking = True
    body_params.enable_body_fitting = True
    body_params.enable_segmentation = False
    body_params.detection_model = sl.BODY_TRACKING_MODEL.HUMAN_BODY_FAST
    body_params.body_format = sl.BODY_FORMAT.BODY_18

    print("Loading Body Tracking module...")
    status = cam.enable_body_tracking(body_params)
    if status != sl.ERROR_CODE.SUCCESS:
        print("Enable Body Tracking:", status, "- Exit")
        cam.disable_positional_tracking()
        cam.close()
        return 1

    # Runtime parameters
    body_runtime_params = sl.BodyTrackingRuntimeParameters()
    body_runtime_params.detection_confidence_threshold = args.confidence

    # Prepare data containers
    bodies = sl.Bodies()
    image = sl.Mat()

    # Get camera info for display scaling
    camera_info = cam.get_camera_information()
    display_resolution = sl.Resolution(
        min(camera_info.camera_configuration.resolution.width, 1280),
        min(camera_info.camera_configuration.resolution.height, 720)
    )

    print(f"Connected to sender: {host}:{port}")
    print(f"Camera: {camera_info.camera_model} S/N {camera_info.serial_number}")
    print(f"Resolution: {camera_info.camera_configuration.resolution.width}x{camera_info.camera_configuration.resolution.height}")
    print("Press 'q' to quit, 'p' to pause/resume")

    cv2.namedWindow("PACMAN Body Tracking", cv2.WINDOW_AUTOSIZE)
    
    paused = False
    last_info = time.time()
    
    while True:
        if not paused:
            # Grab frame
            if cam.grab() == sl.ERROR_CODE.SUCCESS:
                # Retrieve left image
                cam.retrieve_image(image, sl.VIEW.LEFT, sl.MEM.CPU, display_resolution)
                image_cv = image.get_data()

                # Retrieve bodies
                cam.retrieve_bodies(bodies, body_runtime_params)

                # Process detected bodies
                if bodies.is_new and len(bodies.body_list) > 0:
                    # Calculate display scaling
                    scale_x = display_resolution.width / camera_info.camera_configuration.resolution.width
                    scale_y = display_resolution.height / camera_info.camera_configuration.resolution.height

                    for body in bodies.body_list:
                        if body.confidence > args.confidence:
                            # Scale 2D keypoints to display resolution
                            keypoints_2d_scaled = []
                            for kp in body.keypoint_2d:
                                scaled_x = kp[0] * scale_x
                                scaled_y = kp[1] * scale_y
                                keypoints_2d_scaled.append([scaled_x, scaled_y])

                            # Draw skeleton
                            render_skeleton_2d(image_cv, keypoints_2d_scaled, body_params.body_format)

                            # Draw bounding box and info
                            bbox = body.bounding_box_2d
                            if len(bbox) >= 4:
                                top_left = (int(bbox[0][0] * scale_x), int(bbox[0][1] * scale_y))
                                bottom_right = (int(bbox[2][0] * scale_x), int(bbox[2][1] * scale_y))
                                cv2.rectangle(image_cv, top_left, bottom_right, (0, 255, 255), 2)

                                # Add text info
                                info_text = f"ID:{int(body.id)} Conf:{int(body.confidence)}%"
                                cv2.putText(image_cv, info_text, 
                                          (top_left[0], top_left[1] - 10),
                                          cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

                # Display frame
                cv2.imshow("PACMAN Body Tracking", image_cv)

                # Periodic info
                if time.time() - last_info > 3.0:
                    print(f"Bodies detected: {len(bodies.body_list)} | Camera: {camera_info.camera_model}")
                    last_info = time.time()

        # Handle keyboard input
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        elif key == ord('p'):
            paused = not paused
            print("Paused" if paused else "Resumed")

    # Cleanup
    cv2.destroyAllWindows()
    cam.disable_body_tracking()
    cam.disable_positional_tracking()
    cam.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())


#!/usr/bin/env python3
"""
Simple stream connectivity test - connects to Jetson streams without PACMAN API
"""

import socket
import time
import threading

def test_stream_connection(camera_id, host, port):
    """Test connection to a single camera stream"""
    print(f"Camera {camera_id}: Testing connection to {host}:{port}")
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((host, port))
        
        if result == 0:
            print(f"Camera {camera_id}: ✓ CONNECTED to {host}:{port}")
            
            # Try to receive some data
            try:
                data = sock.recv(1024)
                if data:
                    print(f"Camera {camera_id}: ✓ Receiving data ({len(data)} bytes)")
                else:
                    print(f"Camera {camera_id}: ⚠ Connected but no data")
            except socket.timeout:
                print(f"Camera {camera_id}: ⚠ Connected but timeout receiving data")
            except Exception as e:
                print(f"Camera {camera_id}: ⚠ Connected but error: {e}")
        else:
            print(f"Camera {camera_id}: ✗ FAILED to connect to {host}:{port}")
        
        sock.close()
        
    except Exception as e:
        print(f"Camera {camera_id}: ✗ Connection error: {e}")

def main():
    jetson_ip = "192.168.1.254"
    base_port = 30000
    
    print("=== PACMAN Stream Connectivity Test ===")
    print(f"Testing connections to Jetson: {jetson_ip}")
    print("Make sure streaming is active on Jetson!")
    print()
    
    # Test all 4 camera ports
    threads = []
    for i in range(4):
        camera_id = i + 1
        port = base_port + (i * 2)  # 30000, 30002, 30004, 30006
        
        thread = threading.Thread(
            target=test_stream_connection,
            args=(camera_id, jetson_ip, port)
        )
        threads.append(thread)
        thread.start()
    
    # Wait for all tests to complete
    for thread in threads:
        thread.join()
    
    print()
    print("=== Test Complete ===")
    print("If connections succeeded, the Jetson is streaming!")
    print("If connections failed, start streaming on Jetson first:")
    print("  ssh nvidia@192.168.1.254")
    print("  cd /usr/local/zed/samples/camera\\ streaming/multi_sender/python")
    print("  python3 streaming_senders.py")

if __name__ == "__main__":
    main()



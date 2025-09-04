#!/usr/bin/env python3
"""
Test script to verify PACMAN SDK setup and network connectivity
"""

import sys
import socket
import subprocess
import os

def test_pacman_sdk():
    """Test if PACMAN SDK is properly installed"""
    print("=== Testing PACMAN SDK Installation ===")
    
    # Check if SDK directory exists
    sdk_path = "/usr/local/zed"
    if os.path.exists(sdk_path):
        print(f"✓ PACMAN SDK directory found: {sdk_path}")
        
        # Check for key files
        key_files = [
            "lib/libsl_zed.so",
            "include/sl/Camera.hpp", 
            "get_python_api.py"
        ]
        
        for file in key_files:
            full_path = os.path.join(sdk_path, file)
            if os.path.exists(full_path):
                print(f"✓ Found: {file}")
            else:
                print(f"✗ Missing: {file}")
    else:
        print(f"✗ PACMAN SDK directory not found: {sdk_path}")
        return False
    
    # Test Python API
    try:
        import pyzed.sl as sl
        print("✓ PACMAN Python API imported successfully")
        return True
    except ImportError as e:
        print(f"✗ PACMAN Python API not available: {e}")
        print("  Install with: python3 /usr/local/zed/get_python_api.py")
        return False

def test_network_connectivity(jetson_ip, base_port=30000, num_cameras=4):
    """Test network connectivity to Jetson cameras"""
    print(f"\n=== Testing Network Connectivity to {jetson_ip} ===")
    
    # Test basic connectivity
    try:
        socket.inet_aton(jetson_ip)
        print(f"✓ Valid IP address: {jetson_ip}")
    except socket.error:
        print(f"✗ Invalid IP address: {jetson_ip}")
        return False
    
    # Test ping
    try:
        result = subprocess.run(['ping', '-c', '3', jetson_ip], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"✓ Ping successful to {jetson_ip}")
        else:
            print(f"✗ Ping failed to {jetson_ip}")
            return False
    except subprocess.TimeoutExpired:
        print(f"✗ Ping timeout to {jetson_ip}")
        return False
    except FileNotFoundError:
        print("⚠ Ping command not available, skipping ping test")
    
    # Test camera ports
    print(f"\nTesting camera streaming ports:")
    for cam_id in range(num_cameras):
        port = base_port + (cam_id * 2)
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        
        try:
            result = sock.connect_ex((jetson_ip, port))
            if result == 0:
                print(f"✓ Camera {cam_id + 1}: Port {port} is open")
            else:
                print(f"✗ Camera {cam_id + 1}: Port {port} is closed or not accessible")
        except socket.error as e:
            print(f"✗ Camera {cam_id + 1}: Port {port} error - {e}")
        finally:
            sock.close()
    
    return True

def test_system_resources():
    """Test system resources for streaming"""
    print("\n=== Testing System Resources ===")
    
    # Check GPU
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=name,memory.total', 
                               '--format=csv,noheader,nounits'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            gpu_info = result.stdout.strip()
            print(f"✓ NVIDIA GPU detected: {gpu_info}")
        else:
            print("✗ NVIDIA GPU not detected or nvidia-smi not available")
    except FileNotFoundError:
        print("⚠ nvidia-smi not found, GPU status unknown")
    
    # Check available memory
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('MemAvailable:'):
                    mem_kb = int(line.split()[1])
                    mem_gb = mem_kb / 1024 / 1024
                    print(f"✓ Available RAM: {mem_gb:.1f} GB")
                    if mem_gb < 4:
                        print("⚠ Warning: Less than 4GB RAM available")
                    break
    except Exception as e:
        print(f"✗ Could not check memory: {e}")
    
    return True

def main():
    print("PACMAN SDK Setup Test")
    print("=" * 50)
    
    # Test SDK installation
    sdk_ok = test_pacman_sdk()
    
    # Get Jetson IP from user
    jetson_ip = input("\nEnter NVIDIA Jetson IP address (or press Enter to skip network test): ").strip()
    
    if jetson_ip:
        network_ok = test_network_connectivity(jetson_ip)
    else:
        print("Skipping network connectivity test")
        network_ok = True
    
    # Test system resources
    system_ok = test_system_resources()
    
    print("\n" + "=" * 50)
    print("TEST SUMMARY:")
    print(f"PACMAN SDK: {'✓ OK' if sdk_ok else '✗ ISSUES'}")
    print(f"Network: {'✓ OK' if network_ok else '✗ ISSUES'}")
    print(f"System: {'✓ OK' if system_ok else '✗ ISSUES'}")
    
    if sdk_ok and network_ok and system_ok:
        print("\n🎉 All tests passed! Ready for depth streaming.")
        if jetson_ip:
            print(f"\nTo start receiving depth streams, run:")
            print(f"python3 pacman_depth_receiver.py --jetson-ip {jetson_ip}")
    else:
        print("\n⚠ Some issues detected. Please resolve them before streaming.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())



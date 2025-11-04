#!/usr/bin/env python3
"""
TCP Bridge/Forwarder
Accepts connection from edge device and forwards to local PUSR device
"""

import socket
import selectors
import sys
import signal
import logging
import threading

# Configuration
LISTEN_HOST = "0.0.0.0"        # Listen on all interfaces
LISTEN_PORT = 5000             # Port where edge device connects
PUSR_HOST = "10.0.0.51"        # Local PUSR device IP
PUSR_PORT = 4000               # Local PUSR device port

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger('TCPForwarder')


def forward_data(source, destination, direction):
    """Forward data from source to destination"""
    try:
        while True:
            data = source.recv(8192)
            if not data:
                logger.info(f"{direction}: Connection closed")
                break
            destination.sendall(data)
            logger.debug(f"{direction}: Forwarded {len(data)} bytes")
    except Exception as e:
        logger.error(f"{direction}: Error - {e}")
    finally:
        try:
            source.shutdown(socket.SHUT_RD)
        except:
            pass
        try:
            destination.shutdown(socket.SHUT_WR)
        except:
            pass


def handle_client(client_socket, client_addr):
    """Handle connection from edge device"""
    pusr_socket = None
    try:
        logger.info(f"Connection from edge device: {client_addr}")
        
        # Connect to local PUSR device
        pusr_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        pusr_socket.connect((PUSR_HOST, PUSR_PORT))
        logger.info(f"Connected to PUSR device: {PUSR_HOST}:{PUSR_PORT}")
        
        # Start bidirectional forwarding threads
        thread1 = threading.Thread(
            target=forward_data,
            args=(client_socket, pusr_socket, "Edge→PUSR"),
            daemon=True
        )
        thread2 = threading.Thread(
            target=forward_data,
            args=(pusr_socket, client_socket, "PUSR→Edge"),
            daemon=True
        )
        
        thread1.start()
        thread2.start()
        
        # Wait for both threads to finish
        thread1.join()
        thread2.join()
        
        logger.info(f"Session ended for {client_addr}")
        
    except Exception as e:
        logger.error(f"Error handling client {client_addr}: {e}")
    finally:
        if pusr_socket:
            try:
                pusr_socket.close()
            except:
                pass
        try:
            client_socket.close()
        except:
            pass


def main():
    """Main server loop"""
    logger.info("TCP Forwarder starting...")
    logger.info(f"Listening on {LISTEN_HOST}:{LISTEN_PORT}")
    logger.info(f"Forwarding to PUSR device at {PUSR_HOST}:{PUSR_PORT}")
    logger.info("Waiting for connection from edge device (10.0.0.31)...")
    
    # Create server socket
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((LISTEN_HOST, LISTEN_PORT))
        server.listen(5)
        
        # Handle Ctrl+C gracefully
        def signal_handler(signum, frame):
            logger.info("Shutting down...")
            server.close()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        while True:
            client_socket, client_addr = server.accept()
            
            # Handle each client in a separate thread
            client_thread = threading.Thread(
                target=handle_client,
                args=(client_socket, client_addr),
                daemon=True
            )
            client_thread.start()
            
    except Exception as e:
        logger.error(f"Server error: {e}")
    finally:
        server.close()
        logger.info("Server stopped")


if __name__ == '__main__':
    main()
e
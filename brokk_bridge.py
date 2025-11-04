#!/usr/bin/env python3
"""
Configurable TCP-to-RS485 Bridge for Brokk Machine Control
Connects to PUSR USR-TCP232-410s device server and forwards data to/from RS485
"""

import argparse
import json
import logging
import signal
import socket
import sys
import time
import selectors
from pathlib import Path

try:
    import serial
except ImportError:
    print("Error: pyserial not installed. Run: sudo apt-get install python3-serial")
    sys.exit(1)

try:
    import yaml
    YAML_AVAILABLE = True
except ImportError:
    YAML_AVAILABLE = False


class BrokkBridge:
    """Bidirectional TCP-to-RS485 bridge with automatic reconnection"""
    
    def __init__(self, config):
        self.config = config
        self.logger = self._setup_logging()
        self.selector = selectors.DefaultSelector()
        self.sock = None
        self.ser = None
        self.running = False
        self.reconnect_delay = 5
        
    def _setup_logging(self):
        """Configure logging with appropriate level and format"""
        log_level = getattr(logging, self.config['log_level'].upper(), logging.INFO)
        logging.basicConfig(
            level=log_level,
            format='[%(asctime)s] %(levelname)s: %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        return logging.getLogger('BrokkBridge')
    
    def _hex_preview(self, data, limit=64):
        """Format bytes as hex string for logging"""
        preview = data[:limit]
        hex_str = ' '.join(f'{b:02X}' for b in preview)
        if len(data) > limit:
            hex_str += f'... ({len(data)} bytes total)'
        return hex_str
    
    def _setup_tcp_socket(self):
        """Create and configure TCP socket with optimizations"""
        try:
            self.logger.info(f"Connecting to PUSR device at {self.config['host']}:{self.config['port']}...")
            
            sock = socket.create_connection(
                (self.config['host'], self.config['port']),
                timeout=10.0
            )
            
            # Set socket options for performance and reliability
            try:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65536)
                sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
                
                # Linux-specific TCP keepalive tuning
                if sys.platform.startswith('linux'):
                    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 5)
                    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 3)
                    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 3)
                    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_USER_TIMEOUT, 10000)
            except OSError as e:
                self.logger.warning(f"Could not set all socket options: {e}")
            
            sock.setblocking(False)
            self.logger.info("TCP connection established")
            return sock
            
        except Exception as e:
            self.logger.error(f"TCP connection failed: {e}")
            return None
    
    def _setup_serial_port(self):
        """Open and configure RS485 serial port"""
        try:
            # Map parity string to pyserial constant
            parity_map = {
                'none': serial.PARITY_NONE,
                'even': serial.PARITY_EVEN,
                'odd': serial.PARITY_ODD,
                'mark': serial.PARITY_MARK,
                'space': serial.PARITY_SPACE,
            }
            parity = parity_map.get(self.config['parity'].lower(), serial.PARITY_NONE)
            
            # Map stop bits
            stopbits_map = {
                1: serial.STOPBITS_ONE,
                1.5: serial.STOPBITS_ONE_POINT_FIVE,
                2: serial.STOPBITS_TWO,
            }
            stopbits = stopbits_map.get(self.config['stop_bits'], serial.STOPBITS_ONE)
            
            self.logger.info(f"Opening serial port {self.config['serial_device']}...")
            
            ser = serial.Serial(
                port=self.config['serial_device'],
                baudrate=self.config['baud'],
                bytesize=self.config['data_bits'],
                parity=parity,
                stopbits=stopbits,
                timeout=0,  # Non-blocking reads
                write_timeout=None,  # Blocking writes (OS-buffered)
            )
            
            self.logger.info(
                f"Serial port opened: {self.config['baud']} baud, "
                f"{self.config['data_bits']}{self.config['parity'][0].upper()}{self.config['stop_bits']}"
            )
            return ser
            
        except Exception as e:
            self.logger.error(f"Failed to open serial port: {e}")
            return None
    
    def _cleanup(self):
        """Clean up resources"""
        if self.sock:
            try:
                self.selector.unregister(self.sock)
            except Exception:
                pass
            try:
                self.sock.close()
            except Exception:
                pass
            self.sock = None
            
        if self.ser:
            try:
                self.selector.unregister(self.ser)
            except Exception:
                pass
            try:
                if self.ser.is_open:
                    self.ser.close()
            except Exception:
                pass
            self.ser = None
    
    def _handle_tcp_data(self):
        """Handle incoming TCP data and forward to serial"""
        sock_buf = bytearray(65536)
        sock_view = memoryview(sock_buf)
        
        try:
            n = self.sock.recv_into(sock_view, len(sock_buf))
        except (BlockingIOError, InterruptedError):
            return True
        except (ConnectionResetError, BrokenPipeError, OSError) as e:
            self.logger.error(f"TCP recv error: {e}")
            return False
        
        if n == 0:
            self.logger.warning("TCP connection closed by remote")
            return False
        
        data = sock_view[:n].tobytes()
        
        if self.config['log_hex']:
            self.logger.debug(f"TCP → RS485 ({n} bytes): {self._hex_preview(data)}")
        else:
            self.logger.debug(f"TCP → RS485 ({n} bytes)")
        
        try:
            self.ser.write(data)
        except Exception as e:
            self.logger.error(f"Serial write error: {e}")
            return False
        
        return True
    
    def _handle_serial_data(self):
        """Handle incoming serial data and forward to TCP"""
        try:
            n_avail = self.ser.in_waiting or 0
            data = self.ser.read(n_avail if n_avail > 0 else 4096)
            
            if not data:
                return True
            
            if self.config['log_hex']:
                self.logger.debug(f"RS485 → TCP ({len(data)} bytes): {self._hex_preview(data)}")
            else:
                self.logger.debug(f"RS485 → TCP ({len(data)} bytes)")
            
            self.sock.sendall(data)
            return True
            
        except (BlockingIOError, InterruptedError):
            self.logger.warning("TCP send would block")
            return False
        except (ConnectionResetError, BrokenPipeError, OSError) as e:
            self.logger.error(f"TCP send error: {e}")
            return False
        except Exception as e:
            self.logger.error(f"Serial read error: {e}")
            return False
    
    def run_bridge_loop(self):
        """Main bridge loop - forwards data bidirectionally"""
        self.logger.info("Starting bridge loop...")
        
        self.selector.register(self.sock, selectors.EVENT_READ, data='tcp')
        self.selector.register(self.ser, selectors.EVENT_READ, data='serial')
        
        try:
            while self.running:
                events = self.selector.select(timeout=1.0)
                
                for key, _ in events:
                    if key.data == 'tcp':
                        if not self._handle_tcp_data():
                            return False
                    elif key.data == 'serial':
                        if not self._handle_serial_data():
                            return False
                            
            return True
            
        except Exception as e:
            self.logger.error(f"Bridge loop error: {e}")
            return False
    
    def run(self):
        """Main run loop with automatic reconnection"""
        self.running = True
        self.logger.info("Brokk Bridge starting...")
        self.logger.info(f"Configuration: {self.config['host']}:{self.config['port']} <-> {self.config['serial_device']}")
        
        while self.running:
            try:
                # Setup connections
                self.sock = self._setup_tcp_socket()
                if not self.sock:
                    self.logger.warning(f"Retrying TCP connection in {self.reconnect_delay} seconds...")
                    time.sleep(self.reconnect_delay)
                    continue
                
                self.ser = self._setup_serial_port()
                if not self.ser:
                    self.logger.error("Cannot open serial port. Exiting.")
                    return 1
                
                # Run bridge
                self.logger.info("Bridge active - forwarding data...")
                success = self.run_bridge_loop()
                
                # Cleanup
                self._cleanup()
                
                if not self.running:
                    break
                
                if not success:
                    self.logger.warning(f"Connection lost. Reconnecting in {self.reconnect_delay} seconds...")
                    time.sleep(self.reconnect_delay)
                    
            except KeyboardInterrupt:
                self.logger.info("Interrupted by user")
                break
            except Exception as e:
                self.logger.error(f"Unexpected error: {e}", exc_info=True)
                self._cleanup()
                time.sleep(self.reconnect_delay)
        
        self._cleanup()
        self.logger.info("Bridge stopped")
        return 0
    
    def stop(self):
        """Stop the bridge gracefully"""
        self.running = False


def load_config_file(config_path):
    """Load configuration from YAML or JSON file"""
    path = Path(config_path)
    
    if not path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    with open(path, 'r') as f:
        if path.suffix in ['.yaml', '.yml']:
            if not YAML_AVAILABLE:
                raise ImportError("PyYAML not installed. Run: pip3 install pyyaml")
            return yaml.safe_load(f)
        elif path.suffix == '.json':
            return json.load(f)
        else:
            raise ValueError(f"Unsupported config file format: {path.suffix}")


def parse_arguments():
    """Parse command-line arguments"""
    parser = argparse.ArgumentParser(
        description='TCP-to-RS485 Bridge for Brokk Machine Control via PUSR Device Server',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    # Configuration file
    parser.add_argument(
        '--config', '-c',
        help='Path to configuration file (YAML or JSON)'
    )
    
    # Network settings
    parser.add_argument(
        '--host',
        help='PUSR device IP address or hostname'
    )
    parser.add_argument(
        '--port', type=int,
        help='PUSR device TCP port (default: 4000 for PUSR config)'
    )
    
    # Serial settings
    parser.add_argument(
        '--serial-device',
        help='RS485 serial device path (e.g., /dev/ttyTHS3, /dev/ttyUSB0)'
    )
    parser.add_argument(
        '--baud', type=int,
        help='Serial baud rate (default: 19200 from PUSR config)'
    )
    parser.add_argument(
        '--data-bits', type=int, choices=[5, 6, 7, 8],
        help='Serial data bits'
    )
    parser.add_argument(
        '--parity', choices=['none', 'even', 'odd', 'mark', 'space'],
        help='Serial parity'
    )
    parser.add_argument(
        '--stop-bits', type=float, choices=[1, 1.5, 2],
        help='Serial stop bits'
    )
    
    # Logging
    parser.add_argument(
        '--log-level',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='Logging level'
    )
    parser.add_argument(
        '--log-hex', action='store_true',
        help='Enable hex dump logging for debugging'
    )
    
    return parser.parse_args()


def main():
    """Main entry point"""
    args = parse_arguments()
    
    # Default configuration matching PUSR device settings
    config = {
        'host': '192.168.1.100',
        'port': 4000,
        'serial_device': '/dev/ttyTHS3',
        'baud': 19200,
        'data_bits': 8,
        'parity': 'none',
        'stop_bits': 1,
        'log_level': 'INFO',
        'log_hex': False,
    }
    
    # Load config file if specified
    if args.config:
        try:
            file_config = load_config_file(args.config)
            config.update(file_config)
        except Exception as e:
            print(f"Error loading config file: {e}")
            return 1
    
    # Command-line arguments override config file
    if args.host:
        config['host'] = args.host
    if args.port:
        config['port'] = args.port
    if args.serial_device:
        config['serial_device'] = args.serial_device
    if args.baud:
        config['baud'] = args.baud
    if args.data_bits:
        config['data_bits'] = args.data_bits
    if args.parity:
        config['parity'] = args.parity
    if args.stop_bits:
        config['stop_bits'] = args.stop_bits
    if args.log_level:
        config['log_level'] = args.log_level
    if args.log_hex:
        config['log_hex'] = True
    
    # Validate required settings
    if not config['host']:
        print("Error: --host is required (or specify in config file)")
        return 1
    if not config['serial_device']:
        print("Error: --serial-device is required (or specify in config file)")
        return 1
    
    # Create and run bridge
    bridge = BrokkBridge(config)
    
    # Setup signal handlers for graceful shutdown
    def signal_handler(signum, frame):
        bridge.logger.info(f"Received signal {signum}, shutting down...")
        bridge.stop()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    return bridge.run()


if __name__ == '__main__':
    sys.exit(main())


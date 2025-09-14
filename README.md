# ZED Camera Viewer

A Swift macOS application that displays multiple ZED camera streams from a Jetson device in a unified interface.

## Features

- Display up to 4 camera streams in a grid layout
- Individual stream controls (start/stop each camera independently)
- Global controls (start/stop all streams at once)
- Native macOS interface with modern design
- Real-time status monitoring
- Keyboard shortcuts for quick access

## Prerequisites

### GStreamer Installation

The app requires GStreamer to be installed on your Mac:

```bash
brew install gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
```

### Network Configuration

- Ensure your Mac can reach the Jetson device at `192.168.1.254`
- Verify the following ports are accessible:
  - Port 5001: Camera 0 (S/N 51370096)
  - Port 5002: Camera 1 (S/N 59919470)  
  - Port 5004: Camera 2 (S/N 51553791)
  - Port 5003: Camera 3 (S/N 57942132) - Currently disabled

## Building and Running

### Using Swift Package Manager

```bash
cd /Users/yadinsoffer/Twelve
swift build
swift run
```

### Creating a macOS App Bundle

```bash
swift build -c release
# The executable will be at .build/release/ZEDCameraViewer
```

## Usage

1. **Start the application**
   - Launch the app
   - The main window will show a 2x2 grid for camera streams

2. **Start all streams**
   - Click "Start All Streams" button
   - Or use menu: Camera → Start All Streams (⌘S)

3. **Individual camera control**
   - Each camera panel has its own Start/Stop button
   - Or use keyboard shortcuts:
     - ⌘1: Toggle Camera 0
     - ⌘2: Toggle Camera 1  
     - ⌘3: Toggle Camera 2

4. **Stop all streams**
   - Click "Stop All Streams" button
   - Or use menu: Camera → Stop All Streams (⌘X)

## Camera Configuration

The app is configured for the following ZED cameras:

- **Camera 0**: S/N 51370096, Port 5001 (may have corrupted frames)
- **Camera 1**: S/N 59919470, Port 5002 (working with warnings)
- **Camera 2**: S/N 51553791, Port 5004 (working cleanly)
- **Camera 3**: S/N 57942132, Port 5003 (disabled - best performance)

To modify camera configurations, edit the `cameraConfigs` array in `CameraViewController.swift`.

## Troubleshooting

### No video appears
- Check that the Jetson streams are running first
- Verify network connectivity: `ping 192.168.1.254`
- Check firewall settings if streams don't connect

### GStreamer errors
- Ensure GStreamer is properly installed
- Check that all required plugins are available
- Verify the GStreamer pipeline syntax

### Performance issues
- Close unused camera streams to reduce CPU usage
- Check network bandwidth availability
- Monitor system resources

## Architecture

The app consists of several key components:

- **AppDelegate**: Main application lifecycle and menu management
- **CameraViewController**: Main view controller managing the camera grid
- **CameraStreamView**: Individual camera stream display and controls
- **CameraConfig**: Configuration structure for camera parameters

Each camera stream runs as a separate GStreamer process, allowing independent control and better fault isolation.

## Extending the App

### Adding Camera 3
To enable the currently disabled Camera 3:

1. Uncomment Camera 3 configuration in `CameraViewController.swift`
2. Update the grid layout to accommodate 4 cameras
3. Add the corresponding menu item and keyboard shortcut

### Custom Stream Sources
To add different stream sources:

1. Create new `CameraConfig` entries with appropriate parameters
2. Modify the GStreamer pipeline in `CameraConfig.swift` as needed
3. Update the UI layout for additional cameras

## License

This project is for internal use with ZED camera systems.

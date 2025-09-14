#!/bin/bash

# ZED Camera Viewer Build Script

echo "Building ZED Camera Viewer..."

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "ERROR: Swift not found. Please install Xcode Command Line Tools."
    exit 1
fi

# Check if GStreamer is available
if ! command -v gst-launch-1.0 &> /dev/null; then
    echo "WARNING: GStreamer not found. Install with:"
    echo "brew install gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav"
    echo ""
fi

# Build the project
echo "Compiling Swift project..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo ""
    echo "To run the app:"
    echo "  swift run"
    echo ""
    echo "Or run the executable directly:"
    echo "  .build/release/ZEDCameraViewer"
    echo ""
    echo "Make sure your Jetson device is streaming on 192.168.1.254"
else
    echo "Build failed!"
    exit 1
fi

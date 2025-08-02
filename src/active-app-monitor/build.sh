#!/bin/bash

# Simple build script for ActiveAppMonitor

echo "Building ActiveAppMonitor.app..."

# Create dist directory if it doesn't exist
mkdir -p dist

# Clean previous build
rm -rf dist/ActiveAppMonitor.app

# Create app bundle structure
mkdir -p dist/ActiveAppMonitor.app/Contents/MacOS

# Copy Info.plist
cp ActiveAppMonitor/Info.plist dist/ActiveAppMonitor.app/Contents/

# Compile the Swift code
swiftc ActiveAppMonitor/main.swift -o dist/ActiveAppMonitor.app/Contents/MacOS/ActiveAppMonitor

if [ $? -eq 0 ]; then
    # Code sign the app (ad-hoc signing for local use)
    codesign --force --sign - dist/ActiveAppMonitor.app

    echo "✅ Build successful!"
    echo "📍 App location: $(pwd)/dist/ActiveAppMonitor.app"
    echo
    echo "To run the app:"
    echo "  open dist/ActiveAppMonitor.app"
    echo
    echo "To view logs:"
    echo "  tail -f ~/Library/Logs/ActiveAppMonitor.log"
    echo
    echo "To stop the app:"
    echo "  pkill ActiveAppMonitor"
    echo
else
    echo "❌ Build failed!"
    exit 1
fi

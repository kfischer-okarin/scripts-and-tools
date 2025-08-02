#!/bin/bash

# Uninstall script for ActiveAppMonitor LaunchAgent

echo "Uninstalling ActiveAppMonitor autostart..."

# Extract bundle ID from Info.plist
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw ActiveAppMonitor/Info.plist)
PLIST_NAME="$BUNDLE_ID.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Check if the plist exists
if [ -f "$PLIST_PATH" ]; then
    # Unload the agent
    launchctl unload "$PLIST_PATH" 2>/dev/null

    # Remove the plist file
    rm "$PLIST_PATH"

    echo "✅ ActiveAppMonitor autostart removed!"
else
    echo "⚠️  LaunchAgent not found. It may not be installed."
fi

# Stop any running instance
pkill ActiveAppMonitor 2>/dev/null

echo
echo "The app has been stopped and will no longer start at login."
echo

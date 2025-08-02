#!/bin/bash

# Install script for ActiveAppMonitor LaunchAgent

echo "Installing ActiveAppMonitor to start at login..."

# Build the app first
./build.sh
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Please fix build errors first."
    exit 1
fi

# Get absolute paths
APP_PATH="$(pwd)/dist/ActiveAppMonitor.app/Contents/MacOS/ActiveAppMonitor"
# Extract bundle ID from Info.plist
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw ActiveAppMonitor/Info.plist)
PLIST_NAME="$BUNDLE_ID.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# Generate the plist file directly in LaunchAgents directory
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/ActiveAppMonitor-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/ActiveAppMonitor-stderr.log</string>
</dict>
</plist>
EOF

# Unload the agent if it's already loaded (ignore errors)
launchctl unload "$PLIST_PATH" 2>/dev/null

# Load the agent
launchctl load "$PLIST_PATH"

echo "✅ ActiveAppMonitor installed and started!"
echo
echo "The app will now:"
echo "  • Start automatically when you log in"
echo "  • Restart if it crashes"
echo "  • Log to ~/Library/Logs/ActiveAppMonitor.log"
echo
echo "Installed at: $APP_PATH"
echo
echo "To check if it's running:"
echo "  launchctl list | grep ActiveAppMonitor"
echo
echo "To uninstall, run:"
echo "  ./uninstall-autostart.sh"
echo

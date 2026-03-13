#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
APP_DIR="$SCRIPT_DIR/../CodingAgentHub/CodingAgentHub"

if [ -z "${KITTY_SOCKET_PREFIX:-}" ]; then
    echo "Error: KITTY_SOCKET_PREFIX environment variable is required" >&2
    exit 1
fi

SHELL_LOGS="${SHELL_LOGS:-false}"

cat > "$APP_DIR/GeneratedConfig.swift" <<EOF
enum GeneratedConfig {
    static let kittySocketPrefix = "$KITTY_SOCKET_PREFIX"
    static let shellLogs = $SHELL_LOGS
}
EOF

cd "$SCRIPT_DIR/../CodingAgentHub"
xcodebuild -scheme CodingAgentHub -configuration Release build

APP_PATH=$(xcodebuild -scheme CodingAgentHub -configuration Release -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | sed 's/.*= //')
DEST="/Applications/CodingAgentHub.app"

if [ -d "$DEST" ]; then
    echo "Removing existing $DEST"
    rm -rf "$DEST"
fi

cp -R "$APP_PATH/CodingAgentHub.app" "$DEST"
echo ""
echo "Installed to $DEST"

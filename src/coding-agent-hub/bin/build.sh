#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
APP_DIR="$SCRIPT_DIR/../CodingAgentHub/CodingAgentHub"

if [ -z "${KITTY_PASSWORD:-}" ]; then
    echo "Error: KITTY_PASSWORD environment variable is required" >&2
    exit 1
fi

cat > "$APP_DIR/GeneratedConfig.swift" <<EOF
enum GeneratedConfig {
    static let kittyPassword = "$KITTY_PASSWORD"
}
EOF

cd "$SCRIPT_DIR/../CodingAgentHub"
xcodebuild -scheme CodingAgentHub -configuration Debug build

APP_PATH=$(xcodebuild -scheme CodingAgentHub -configuration Debug -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | sed 's/.*= //')
echo ""
echo "Run: open \"$APP_PATH/CodingAgentHub.app\""

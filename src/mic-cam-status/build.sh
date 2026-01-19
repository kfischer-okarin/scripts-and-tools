#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"

mkdir -p "$OUTPUT_DIR"

echo "Building is-camera-on..."
swiftc -O -o "$OUTPUT_DIR/is-camera-on" "$SCRIPT_DIR/is-camera-on.swift"

echo "Building is-mic-on..."
swiftc -O -o "$OUTPUT_DIR/is-mic-on" "$SCRIPT_DIR/is-mic-on.swift"

echo "Build complete. Binaries in $OUTPUT_DIR"

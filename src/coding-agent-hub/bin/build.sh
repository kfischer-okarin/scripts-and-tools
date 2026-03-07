#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../CodingAgentHub"
xcodebuild -scheme CodingAgentHub -configuration Debug build

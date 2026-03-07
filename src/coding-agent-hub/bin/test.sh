#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../AgentHubCore"
swift test

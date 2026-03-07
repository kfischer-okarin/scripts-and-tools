#!/bin/bash
set -euo pipefail

CLAUDE_BIN=$(which -a claude | grep -v "$(realpath "$0")" | head -1)

if [ -z "$CLAUDE_BIN" ]; then
    echo "Error: could not find real claude binary" >&2
    exit 1
fi

SESSION_NAME="agent-$(uuidgen | tr '[:upper:]' '[:lower:]')"

tmux new-session -d -s "$SESSION_NAME" "$CLAUDE_BIN" "$@"
tmux attach -t "$SESSION_NAME"

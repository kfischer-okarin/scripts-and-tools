# Coding Agent Hub

macOS SwiftUI app that passively discovers and displays active Claude Code
sessions wrapped in tmux.

## Scripts

- `bin/build.sh` - Build the app
- `bin/test.sh` - Run all tests

## Architecture

Domain layer (@Observable, pure Swift) drives all state. SwiftUI views are a
thin rendering layer.

- `AgentHub` - root domain object, owns polling and session state
- `TmuxGateway` - translates domain needs into tmux commands
- `ShellExecutor` (protocol) - single external boundary, only mock point in
  tests
- `SessionParser` - pure function, raw terminal text to SessionStatus

## Project Layout

- `CodingAgentHub/CodingAgentHub/` - app source
- `CodingAgentHub/CodingAgentHubTests/` - tests
- `bin/claude-wrapper.sh` - tmux wrapper script (alias to `claude`)

# Coding Agent Hub

macOS SwiftUI app that discovers and displays active Claude Code sessions
running in kitty terminal windows via socket-based remote control.

## Scripts

- `bin/build.sh` - Build the app (use `mise x -- ./bin/build.sh`)
- `bin/test.sh` - Run domain tests via `swift test` (sub-second, no Xcode needed)

## Architecture

Domain layer (`AgentHubCore` Swift package, `@Observable`, pure Swift) drives
all state. SwiftUI views are a thin rendering layer in the Xcode project.

- `AgentHub` - root domain object, owns polling and session state
- `StatusParser` - parses terminal output into session status (idle/working/needingUserInput)
- `ContextParser` - extracts recent context lines from terminal output
- `SessionSource` (protocol, internal) - abstracts session discovery, returns `DiscoveredSession`
- `KittySessionSource` - discovers sockets via `fd`, queries each via `kitten @` over unix socket, focus via `focus-window`
- `ShellExecutor` (protocol) - single external boundary, only mock point in tests; also exposes `homeDirectory`
- `ProcessShellExecutor` - real impl using Foundation.Process, optional file logging

## Project Layout

- `AgentHubCore/` - Swift package with domain logic + tests
  - `Sources/AgentHubCore/` - public types (AgentHub, AgentSession, SessionStatus, StatusParser, ContextParser, ShellExecutor)
  - `Sources/AgentHubCore/Internal/` - internal types (SessionSource, DiscoveredSession, KittySessionSource)
  - `Tests/AgentHubCoreTests/` - tests (AgentHubTests, StatusParserTests, ContextParserTests, MockShellExecutor)
- `CodingAgentHub/` - Xcode project (thin SwiftUI shell importing AgentHubCore)
  - `CodingAgentHub/GeneratedConfig.swift` - build-time generated, gitignored

## Build Environment (mise.local.toml)

- `KITTY_PASSWORD` - kitty remote control password
- `KITTY_SOCKET_PREFIX` - socket path prefix (kitty appends `-<PID>`)
- `SHELL_LOGS` - `true`/`false`, enables file logging

## Kitty Remote Control Setup

In `kitty.conf`:
```
allow_remote_control password
remote_control_password "your-password" get-text ls focus-window
listen_on unix:/tmp/kitty-socket
```

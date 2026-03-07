# Handoff: Coding Agent Hub

## Current State

The app builds, launches, discovers kitty sessions, and displays them with
real-time status updates. Polling every 2 seconds.

## What Works

- **Socket discovery**: Uses `fd` to glob `/tmp/kitty-socket-*` sockets, queries
  each kitty instance, aggregates all claude windows across multiple kitty processes
- **Session filtering**: Only matches processes where `cmdline.first == "claude"`,
  excludes non-interactive sessions (`-p` / `--print` flags)
- **Status parsing** (`StatusParser`): Anchored on the input area (❯ below ─── line).
  Input area present → `.idle` or `.working` (if thinking indicator within 5 lines above).
  Input area absent → `.needingUserInput` (permission prompts, etc.)
- **Error handling**: Per-socket — only surfaces error when all sockets fail with
  remote control disabled; silently skips bad ones when others work
- **Window title**: Parsed from `kitten @ ls` JSON, displayed as the main row text
- **Shell logging**: Toggled via `SHELL_LOGS` build env, logs to `/tmp/coding-agent-hub.log`
- **Pipe safety**: Reads stdout/stderr before `waitUntilExit()` to avoid deadlock
  on large outputs (e.g. `--extent all` scrollback)
- **Full scrollback**: Uses `get-text --extent all` so scrolling up doesn't affect
  status detection

## Build & Test

- `bin/test.sh` — 13 tests across 2 suites, <1 second via `swift test`
- `mise x -- ./bin/build.sh` — reads env vars from `mise.local.toml`, generates
  `GeneratedConfig.swift`, builds via xcodebuild

### Build env vars (mise.local.toml)

- `KITTY_PASSWORD` — kitty remote control password
- `KITTY_SOCKET_PREFIX` — socket path prefix (kitty appends `-<PID>`)
- `SHELL_LOGS` — `true`/`false`, enables ProcessShellExecutor file logging

### Kitty config required

```
allow_remote_control password
remote_control_password "your-password" get-text ls
listen_on unix:/tmp/kitty-socket
```

## Test Suites

### StatusParserTests (5 tests)
- Working (thinking indicator above input area)
- Idle (input area present, no thinking)
- Needing user input (no input area — permission prompt)
- No false positive on "Do you want to" in output text
- Working takes priority over input prompt

### AgentHubTests (8 tests)
- Discovers session with title and status
- No sessions when no claude windows
- No sessions when no sockets found
- Aggregates across multiple kitty instances
- Ignores non-claude processes with "claude" in name
- Ignores non-interactive claude (-p/--print)
- Error when all sockets have remote control disabled
- Skips bad socket when others work

## Backlog

### Display improvements
- Show cwd (where claude process was started) below the title
- Show a few lines of current context below the title (parse smartly — show
  what claude is doing, not just the empty user prompt)

### Navigation
- Click on a session to focus that kitty window and switch to its tab
  (focus the kitty process, then use `kitten @` to activate the tab/window)

## Key Files

- `AgentHubCore/Sources/AgentHubCore/AgentHub.swift` — root domain object
- `AgentHubCore/Sources/AgentHubCore/StatusParser.swift` — terminal output → status
- `AgentHubCore/Sources/AgentHubCore/Internal/KittySessionSource.swift` — kitty integration
- `AgentHubCore/Sources/AgentHubCore/Internal/SessionSource.swift` — protocol + DiscoveredSession
- `AgentHubCore/Sources/AgentHubCore/ProcessShellExecutor.swift` — real shell + logging
- `AgentHubCore/Tests/AgentHubCoreTests/AgentHubTests.swift` — discovery tests
- `AgentHubCore/Tests/AgentHubCoreTests/StatusParserTests.swift` — parsing tests
- `AgentHubCore/Tests/AgentHubCoreTests/MockShellExecutor.swift` — mock + helpers
- `CodingAgentHub/CodingAgentHub/ContentView.swift` — SwiftUI view
- `CodingAgentHub/CodingAgentHub/CodingAgentHubApp.swift` — app entry point

import Testing
@testable import AgentHubCore

private func makeHub(shell: MockShellExecutor) -> AgentHub {
    AgentHub(shell: shell, kittyPassword: MockShellExecutor.testPassword, kittySocketPrefix: MockShellExecutor.testSocketPrefix)
}

struct AgentHubTests {

    // MARK: - First slice: discover + parse

    @Test func discoversActiveSessionWithParsedStatus() async throws {
        let shell = MockShellExecutor()
        shell.givenKittySessions([
            (id: 1, foregroundCmdline: ["claude"]),
            (id: 2, foregroundCmdline: ["vim", "foo.swift"]),
        ])
        shell.givenKittyWindowOutput(1, content: """
            Some previous output
            ✻ Thinking… (27s, 200 tokens)
            ────────────────────
            ❯
            """)

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].id == "\(MockShellExecutor.testSocket):1")
        #expect(hub.sessions[0].status == .working)
    }

    // MARK: - Backlog (BDD-style cases to implement next via TDD)

    @Test func showsNoSessionsWhenNoClaude() async throws {
        let shell = MockShellExecutor()
        shell.givenKittySessions([
            (id: 1, foregroundCmdline: ["vim"]),
            (id: 2, foregroundCmdline: ["zsh"]),
        ])

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    @Test func showsNoSessionsWhenNoSocketsFound() async throws {
        let shell = MockShellExecutor()
        shell.givenNoKittySockets()

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    @Test func aggregatesSessionsAcrossMultipleKittyInstances() async throws {
        let shell = MockShellExecutor()
        let socket1 = "/tmp/test-socket-111"
        let socket2 = "/tmp/test-socket-222"
        shell.givenKittySessions(socket: socket1, [(id: 1, foregroundCmdline: ["claude"])])
        shell.givenKittySessions(socket: socket2, [(id: 5, foregroundCmdline: ["claude"])])
        shell.givenKittyWindowOutput(socket: socket1, 1, content: """
            ✻ Thinking… (5s)
            ────────────────────
            ❯
            """)
        shell.givenKittyWindowOutput(socket: socket2, 5, content: """
            Some output here
            ────────────────────
            ❯
            """)

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 2)
        #expect(hub.sessions[0].id == "\(socket1):1")
        #expect(hub.sessions[0].status == .working)
        #expect(hub.sessions[1].id == "\(socket2):5")
        #expect(hub.sessions[1].status == .awaitingUserInput)
    }

    @Test func ignoresProcessesThatContainClaudeButAreNotClaude() async throws {
        let shell = MockShellExecutor()
        shell.givenKittySessions([
            (id: 1, foregroundCmdline: ["claude-hierarchical-agent"]),
            (id: 2, foregroundCmdline: ["/usr/local/bin/claude-helper"]),
        ])

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    // Discovery:
    // - shows no sessions when no claude windows exist ✅
    // - shows no sessions when no sockets found ✅
    // - aggregates sessions across multiple kitty instances ✅
    // - shows error message when remote control is disabled
    // - removes sessions that disappear between refreshes
    // - preserves session identity across refreshes (no flicker)

    @Test func sessionAwaitingUserInputWhenPromptVisible() async throws {
        let shell = MockShellExecutor()
        shell.givenKittySessions([(id: 1, foregroundCmdline: ["claude"])])
        shell.givenKittyWindowOutput(1, content: """
            Some output here
            ────────────────────
            ❯
            """)

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].status == .awaitingUserInput)
    }

    @Test func sessionAwaitingPermissionWhenYesNoOptionsVisible() async throws {
        let shell = MockShellExecutor()
        shell.givenKittySessions([(id: 1, foregroundCmdline: ["claude"])])
        shell.givenKittyWindowOutput(1, content: """
            ───────────────────────────────────────────────
             Edit file
             src/AgentHubCore/Sources/SessionStatus.swift
            ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
             1  public enum SessionStatus: Equatable {
             2      case thinking
             3 +    case awaitingUserInput
             4  }
            ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
             Do you want to make this edit to SessionStatus.swift?
             ❯ 1. Yes
               2. Yes, allow all edits during this session (shift+tab)
               3. No
            """)

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].status == .awaitingPermission)
    }

    @Test func showsErrorWhenAllSocketsHaveRemoteControlDisabled() async throws {
        let shell = MockShellExecutor()
        shell.givenKittyRemoteControlDisabled(socket: "/tmp/test-socket-111")
        shell.givenKittyRemoteControlDisabled(socket: "/tmp/test-socket-222")

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.isEmpty)
        #expect(hub.errorMessage == "Remote control is disabled")
    }

    @Test func skipsSocketWithRemoteControlDisabledWhenOthersWork() async throws {
        let shell = MockShellExecutor()
        let goodSocket = "/tmp/test-socket-111"
        let badSocket = "/tmp/test-socket-222"
        shell.givenKittySessions(socket: goodSocket, [(id: 1, foregroundCmdline: ["claude"])])
        shell.givenKittyRemoteControlDisabled(socket: badSocket)
        shell.givenKittyWindowOutput(socket: goodSocket, 1, content: """
            ✻ Thinking… (5s)
            ────────────────────
            ❯
            """)

        let hub = makeHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].id == "\(goodSocket):1")
        #expect(hub.errorMessage == nil)
    }

    // Status parsing:
    // - session with prompt after separator has status .awaitingUserInput ✅
    // - session with permission prompt has status .awaitingPermission ✅
    // - session with "Read(src/foo.swift)" output has status .toolUse("Read")
    // - session with "Edit(...)" output has status .toolUse("Edit")
    // - session with "Bash(...)" output has status .toolUse("Bash")
    // - session with "Error:" output has status .error
    // - most recent activity (bottom of output) wins over earlier patterns
    // - ANSI escape sequences are stripped before parsing

    // Context:
    // - session exposes last N lines of raw output for display
}

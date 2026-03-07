import Testing
@testable import AgentHubCore

struct AgentHubTests {

    // MARK: - First slice: discover + parse

    @Test func discoversActiveSessionWithParsedStatus() async throws {
        let shell = MockShellExecutor()
        shell.givenTmuxSessions(["agent-abc123", "my-other-session"])
        shell.givenTmuxSessionOutput("agent-abc123",
                                     content: "Some previous output\n✻ Thinking… (27s, 200 tokens)\n")

        let hub = AgentHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].id == "agent-abc123")
        #expect(hub.sessions[0].status == .working)
    }

    // MARK: - Backlog (BDD-style cases to implement next via TDD)

    @Test func showsNoSessionsWhenNoAgentPrefixedSessionsExist() async throws {
        let shell = MockShellExecutor()
        shell.givenTmuxSessions(["my-dev-session", "other-stuff"])

        let hub = AgentHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    // Discovery:
    // - shows no sessions when tmux has no agent-prefixed sessions ✅
    // - shows no sessions when tmux server is not running (error output)
    // - discovers multiple agent sessions simultaneously
    // - removes sessions that disappear between refreshes
    // - preserves session identity across refreshes (no flicker)

    @Test func sessionAwaitingUserInputWhenPromptVisible() async throws {
        let shell = MockShellExecutor()
        shell.givenTmuxSessions(["agent-xyz"])
        shell.givenTmuxSessionOutput("agent-xyz",
                                     content: "Some output here\n────────────────────\n❯ \n")

        let hub = AgentHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].status == .awaitingUserInput)
    }

    @Test func sessionAwaitingPermissionWhenYesNoOptionsVisible() async throws {
        let shell = MockShellExecutor()
        shell.givenTmuxSessions(["agent-perm"])
        shell.givenTmuxSessionOutput("agent-perm", content: """
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

        let hub = AgentHub(shell: shell)
        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].status == .awaitingPermission)
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

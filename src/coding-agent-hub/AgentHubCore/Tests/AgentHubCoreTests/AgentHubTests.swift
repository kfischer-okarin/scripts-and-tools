import Testing
@testable import AgentHubCore

private typealias Window = MockShellExecutor.KittyWindowStub

struct AgentHubTests {
    let shell = MockShellExecutor()
    let hub: AgentHub

    init() {
        hub = AgentHub(shell: shell, kittyPassword: MockShellExecutor.testPassword, kittySocketPrefix: MockShellExecutor.testSocketPrefix)
    }

    @Test func discoversActiveSessionWithTitleAndStatus() async throws {
        shell.givenKittySessions([
            Window(id: 1, foregroundCmdline: ["claude"], title: "✳ Doing Important Work"),
            Window(id: 2, foregroundCmdline: ["vim", "foo.swift"], title: "vim"),
        ])
        shell.givenKittyWindowOutput(1, content: """
            Some previous output
            ✻ Thinking… (27s, 200 tokens)
            ────────────────────
            ❯
            """)

        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].title == "✳ Doing Important Work")
        #expect(hub.sessions[0].status == .working)
    }

    @Test func showsNoSessionsWhenNoClaude() async throws {
        shell.givenKittySessions([
            Window(id: 1, foregroundCmdline: ["vim"]),
            Window(id: 2, foregroundCmdline: ["zsh"]),
        ])

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    @Test func showsNoSessionsWhenNoSocketsFound() async throws {
        shell.givenNoKittySockets()

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    @Test func aggregatesSessionsAcrossMultipleKittyInstances() async throws {
        let socket1 = "/tmp/test-socket-111"
        let socket2 = "/tmp/test-socket-222"
        shell.givenKittySessions(socket: socket1, [Window(id: 1, foregroundCmdline: ["claude"])])
        shell.givenKittySessions(socket: socket2, [Window(id: 5, foregroundCmdline: ["claude"])])
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

        await hub.refresh()

        #expect(hub.sessions.count == 2)
        #expect(hub.sessions[0].id == "\(socket1):1")
        #expect(hub.sessions[0].status == .working)
        #expect(hub.sessions[1].id == "\(socket2):5")
        #expect(hub.sessions[1].status == .idle)
    }

    @Test func ignoresProcessesThatContainClaudeButAreNotClaude() async throws {
        shell.givenKittySessions([
            Window(id: 1, foregroundCmdline: ["claude-hierarchical-agent"]),
            Window(id: 2, foregroundCmdline: ["/usr/local/bin/claude-helper"]),
        ])

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    @Test func ignoresNonInteractiveClaudeWithPrintFlag() async throws {
        shell.givenKittySessions([
            Window(id: 1, foregroundCmdline: ["claude", "-p", "summarize this"]),
            Window(id: 2, foregroundCmdline: ["claude", "--print", "do something"]),
            Window(id: 3, foregroundCmdline: ["claude", "some", "args", "-p"]),
        ])

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    // Discovery:
    // - shows no sessions when no claude windows exist ✅
    // - shows no sessions when no sockets found ✅
    // - aggregates sessions across multiple kitty instances ✅
    // - shows error message when remote control is disabled ✅
    // - removes sessions that disappear between refreshes
    // - preserves session identity across refreshes (no flicker)

    @Test func showsErrorWhenAllSocketsHaveRemoteControlDisabled() async throws {
        shell.givenKittyRemoteControlDisabled(socket: "/tmp/test-socket-111")
        shell.givenKittyRemoteControlDisabled(socket: "/tmp/test-socket-222")

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
        #expect(hub.errorMessage == "Remote control is disabled")
    }

    @Test func skipsSocketWithRemoteControlDisabledWhenOthersWork() async throws {
        let goodSocket = "/tmp/test-socket-111"
        let badSocket = "/tmp/test-socket-222"
        shell.givenKittySessions(socket: goodSocket, [Window(id: 1, foregroundCmdline: ["claude"])])
        shell.givenKittyRemoteControlDisabled(socket: badSocket)
        shell.givenKittyWindowOutput(socket: goodSocket, 1, content: """
            ✻ Thinking… (5s)
            ────────────────────
            ❯
            """)

        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].id == "\(goodSocket):1")
        #expect(hub.errorMessage == nil)
    }
}

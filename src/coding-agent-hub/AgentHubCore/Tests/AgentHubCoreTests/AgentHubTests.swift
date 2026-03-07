import Testing
@testable import AgentHubCore

private typealias Window = MockShellExecutor.KittyWindowStub

struct AgentHubTests {
    let shell = MockShellExecutor()
    let hub: AgentHub

    init() {
        hub = AgentHub(shell: shell, kittyPassword: MockShellExecutor.testPassword, kittySocketPrefix: MockShellExecutor.testSocketPrefix)
    }

    @Test func discoversSessionWithCwd() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["claude"], cwd: "/tmp/some-project"),
        ])

        await hub.refresh()

        #expect(hub.sessions[0].cwd == "/tmp/some-project")
    }

    @Test func replacesHomeDirectoryWithTildeInCwd() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["claude"], cwd: "\(shell.homeDirectory)/projects/my-app"),
        ])

        await hub.refresh()

        #expect(hub.sessions[0].cwd == "~/projects/my-app")
    }

    @Test func discoversActiveSessionWithTitleAndStatus() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["claude"], title: "✳ Doing Important Work", output: """
                Some previous output
                ✻ Thinking… (27s, 200 tokens)

                ────────────────────
                ❯
                ────────────────────
                """),
            Window(foregroundCmdline: ["vim", "foo.swift"], title: "vim"),
        ])

        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].title == "✳ Doing Important Work")
        #expect(hub.sessions[0].status == .working)
    }

    @Test func showsNoSessionsWhenNoClaude() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["vim"]),
            Window(foregroundCmdline: ["zsh"]),
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
        shell.givenKittySessions(socket: socket1, [Window(id: 1, foregroundCmdline: ["claude"], output: """
            ✻ Thinking… (5s)

            ────────────────────
            ❯
            ────────────────────
            """)])
        shell.givenKittySessions(socket: socket2, [Window(id: 5, foregroundCmdline: ["claude"])])

        await hub.refresh()

        #expect(hub.sessions.count == 2)
        #expect(hub.sessions[0].id == "\(socket1):1")
        #expect(hub.sessions[0].status == .working)
        #expect(hub.sessions[1].id == "\(socket2):5")
        #expect(hub.sessions[1].status == .idle)
    }

    @Test func ignoresProcessesThatContainClaudeButAreNotClaude() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["claude-hierarchical-agent"]),
            Window(foregroundCmdline: ["/usr/local/bin/claude-helper"]),
        ])

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

    @Test func ignoresNonInteractiveClaudeWithPrintFlag() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["claude", "-p", "summarize this"]),
            Window(foregroundCmdline: ["claude", "--print", "do something"]),
            Window(foregroundCmdline: ["claude", "some", "args", "-p"]),
        ])

        await hub.refresh()

        #expect(hub.sessions.isEmpty)
    }

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
        shell.givenKittySessions(socket: goodSocket, [Window(id: 1, foregroundCmdline: ["claude"], output: """
            ✻ Thinking… (5s)

            ────────────────────
            ❯
            ────────────────────
            """)])
        shell.givenKittyRemoteControlDisabled(socket: badSocket)

        await hub.refresh()

        #expect(hub.sessions.count == 1)
        #expect(hub.sessions[0].id == "\(goodSocket):1")
        #expect(hub.errorMessage == nil)
    }
}

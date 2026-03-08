import Foundation
import Testing
@testable import AgentHubCore

private typealias Window = MockShellExecutor.KittyWindowStub

final class MockClock: AppClock, @unchecked Sendable {
    var current = Date(timeIntervalSinceReferenceDate: 0)

    func now() -> Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

struct AgentHubTests {
    let shell = MockShellExecutor()
    let clock = MockClock()
    let hub: AgentHub

    init() {
        hub = AgentHub(shell: shell, kittyPassword: MockShellExecutor.testPassword, kittySocketPrefix: MockShellExecutor.testSocketPrefix, clock: clock)
    }

    @Test func discoversAndParsesSessions() async throws {
        shell.givenKittySessions([
            Window(foregroundCmdline: ["claude"], title: "✳ Doing Important Work", cwd: "\(shell.homeDirectory)/projects/my-app", output: """
                Read the file
                Edited src/main.swift
                All tests passed

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
        #expect(hub.sessions[0].cwd == "~/projects/my-app")
        #expect(hub.sessions[0].status == .working)
        #expect(hub.sessions[0].context == [
            "Read the file",
            "Edited src/main.swift",
            "All tests passed",
        ])
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

    @Test func tracksLastUpdatedTimestamp() async throws {
        shell.givenKittySessions([
            Window(id: 1, foregroundCmdline: ["claude"]),
        ])

        await hub.refresh()
        let firstSeen = hub.sessions[0].lastUpdated

        clock.advance(by: 10)
        await hub.refresh()
        #expect(hub.sessions[0].lastUpdated == firstSeen, "Timestamp unchanged when output unchanged")

        clock.advance(by: 5)
        shell.kittyWindowOutputChanged(1, content: """
            New output here

            ────────────────────
            ❯
            ────────────────────
            """)
        await hub.refresh()
        #expect(hub.sessions[0].lastUpdated == firstSeen.addingTimeInterval(15), "Timestamp updated when output changed")
    }

    @Test func focusSessionSendsFocusWindowCommand() async throws {
        shell.givenKittySessions([
            Window(id: 42, foregroundCmdline: ["claude"]),
        ])
        await hub.refresh()

        await hub.focusSession(hub.sessions[0])

        let focusCommand = shell.ranCommands.first { $0.contains("focus-window") }
        #expect(focusCommand == "kitten @ --password test-pass --to unix:/tmp/test-socket-12345 focus-window --match id:42")
    }
}

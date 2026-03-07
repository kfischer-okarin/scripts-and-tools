@testable import AgentHubCore

final class MockShellExecutor: ShellExecutor, @unchecked Sendable {
    private var stubs: [String: String] = [:]

    func stub(_ command: String, arguments: [String], output: String) {
        let key = ([command] + arguments).joined(separator: " ")
        stubs[key] = output
    }

    func givenTmuxSessions(_ names: [String]) {
        stub("tmux", arguments: ["list-sessions", "-F", "#{session_name}"],
             output: names.joined(separator: "\n") + "\n")
    }

    func givenTmuxSessionOutput(_ session: String, content: String) {
        stub("tmux", arguments: ["capture-pane", "-p", "-t", session, "-S", "-30"],
             output: content)
    }

    func run(_ command: String, arguments: [String]) async throws -> String {
        let key = ([command] + arguments).joined(separator: " ")
        return stubs[key] ?? ""
    }
}

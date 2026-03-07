@testable import AgentHubCore

final class MockShellExecutor: ShellExecutor, @unchecked Sendable {
    private var stubs: [String: String] = [:]

    func stub(_ command: String, arguments: [String], output: String) {
        let key = ([command] + arguments).joined(separator: " ")
        stubs[key] = output
    }

    func run(_ command: String, arguments: [String]) async throws -> String {
        let key = ([command] + arguments).joined(separator: " ")
        return stubs[key] ?? ""
    }
}

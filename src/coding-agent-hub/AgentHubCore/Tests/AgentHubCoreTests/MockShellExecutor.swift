@testable import AgentHubCore

final class MockShellExecutor: ShellExecutor, @unchecked Sendable {
    private var stubs: [String: String] = [:]
    private var errors: [String: ShellError] = [:]

    func stub(_ command: String, arguments: [String], output: String) {
        let key = ([command] + arguments).joined(separator: " ")
        stubs[key] = output
    }

    func stubError(_ command: String, arguments: [String], error: ShellError) {
        let key = ([command] + arguments).joined(separator: " ")
        errors[key] = error
    }

    func givenKittySessions(_ windows: [(id: Int, cmdline: [String])]) {
        let windowsJson = windows.map { window in
            """
            {"id": \(window.id), "title": "", "cwd": "/tmp", "pid": 1000, \
            "cmdline": [\(window.cmdline.map { "\"\($0)\"" }.joined(separator: ", "))]}
            """
        }.joined(separator: ", ")
        let json = """
        [{"id": 1, "tabs": [{"id": 1, "title": "", "windows": [\(windowsJson)]}]}]
        """
        stub("kitten", arguments: ["@", "ls"], output: json)
    }

    func givenKittyWindowOutput(_ windowId: Int, content: String) {
        stub("kitten", arguments: ["@", "get-text", "--match", "id:\(windowId)"],
             output: content)
    }

    func givenKittyRemoteControlDisabled() {
        stubError("kitten", arguments: ["@", "ls"],
                  error: ShellError(message: "Remote control is disabled"))
    }

    func run(_ command: String, arguments: [String]) async throws -> String {
        let key = ([command] + arguments).joined(separator: " ")
        if let error = errors[key] {
            throw error
        }
        return stubs[key] ?? ""
    }
}

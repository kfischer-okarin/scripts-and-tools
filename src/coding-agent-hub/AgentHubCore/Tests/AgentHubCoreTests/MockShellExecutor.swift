@testable import AgentHubCore

final class MockShellExecutor: ShellExecutor, @unchecked Sendable {
    private var stubs: [String: String] = [:]
    private var errors: [String: ShellError] = [:]
    private var sockets: [String] = []

    func stub(_ command: String, arguments: [String], output: String) {
        let key = ([command] + arguments).joined(separator: " ")
        stubs[key] = output
    }

    func stubError(_ command: String, arguments: [String], error: ShellError) {
        let key = ([command] + arguments).joined(separator: " ")
        errors[key] = error
    }

    static let testSocketPrefix = "/tmp/test-socket"
    static let testSocket = "/tmp/test-socket-12345"
    static let testPassword = "test-pass"

    func givenNoKittySockets() {
        stub("fd", arguments: ["--glob", "test-socket-*", "--type", "socket", "--max-depth", "1", "/tmp"],
             output: "")
    }

    struct KittyWindowStub {
        var id: Int
        var foregroundCmdline: [String]
        var title: String = "~/some-project"
    }

    func givenKittySessions(socket: String = testSocket, _ windows: [KittyWindowStub]) {
        if !sockets.contains(socket) {
            sockets.append(socket)
            stub("fd", arguments: ["--glob", "test-socket-*", "--type", "socket", "--max-depth", "1", "/tmp"],
                 output: sockets.joined(separator: "\n"))
        }
        let windowsJson = windows.map { w in
            let cmdlineJson = w.foregroundCmdline.map { "\"\($0)\"" }.joined(separator: ", ")
            return """
            {"id": \(w.id), "title": "\(w.title)", "cwd": "/tmp", "pid": 1000, \
            "cmdline": ["/bin/zsh"], \
            "foreground_processes": [{"cmdline": [\(cmdlineJson)], "cwd": "/tmp", "pid": 2000}]}
            """
        }.joined(separator: ", ")
        let json = """
        [{"id": 1, "tabs": [{"id": 1, "title": "", "windows": [\(windowsJson)]}]}]
        """
        stub("kitten", arguments: kittenPrefix(socket) + ["ls"], output: json)
    }

    func givenKittyWindowOutput(socket: String = testSocket, _ windowId: Int, content: String) {
        stub("kitten", arguments: kittenPrefix(socket) + ["get-text", "--extent", "all", "--match", "id:\(windowId)"],
             output: content)
    }

    func givenKittyRemoteControlDisabled(socket: String = testSocket) {
        if !sockets.contains(socket) {
            sockets.append(socket)
            stub("fd", arguments: ["--glob", "test-socket-*", "--type", "socket", "--max-depth", "1", "/tmp"],
                 output: sockets.joined(separator: "\n"))
        }
        stubError("kitten", arguments: kittenPrefix(socket) + ["ls"],
                  error: ShellError(message: "Remote control is disabled"))
    }

    func run(_ command: String, arguments: [String]) async throws -> String {
        let key = ([command] + arguments).joined(separator: " ")
        if let error = errors[key] {
            throw error
        }
        return stubs[key] ?? ""
    }

    private func kittenPrefix(_ socket: String) -> [String] {
        ["@", "--password", Self.testPassword, "--to", "unix:\(socket)"]
    }
}

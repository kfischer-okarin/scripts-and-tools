import Foundation

struct KittyWindow {
    let id: Int
    let foregroundCmdlines: [[String]]
}

struct KittySessionSource: SessionSource {
    let shell: ShellExecutor
    let password: String
    let socketPrefix: String

    func discoverSessions() async throws -> [String] {
        let sockets = try await findSockets()
        guard !sockets.isEmpty else { return [] }

        var sessions: [String] = []
        var errors: [Error] = []
        for socket in sockets {
            do {
                let json = try await shell.run("kitten", arguments: kittenArgs(socket, ["ls"]))
                let claudeWindowIds = parseWindows(from: json)
                    .filter { window in
                        window.foregroundCmdlines.contains { cmdline in
                            cmdline.first == "claude"
                        }
                    }
                    .map { "\(socket):\($0.id)" }
                sessions.append(contentsOf: claudeWindowIds)
            } catch {
                errors.append(error)
            }
        }
        if sessions.isEmpty && errors.count == sockets.count && !errors.isEmpty {
            throw errors[0]
        }
        return sessions
    }

    func captureOutput(session: String) async -> String {
        let parts = session.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return "" }
        let socket = String(parts[0])
        let windowId = String(parts[1])
        return (try? await shell.run("kitten", arguments: kittenArgs(socket, ["get-text", "--match", "id:\(windowId)"]))) ?? ""
    }

    private func findSockets() async throws -> [String] {
        let dir = (socketPrefix as NSString).deletingLastPathComponent
        let prefix = (socketPrefix as NSString).lastPathComponent
        let output = try await shell.run("fd", arguments: ["--glob", "\(prefix)-*", "--type", "socket", "--max-depth", "1", dir])
        return output
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func kittenArgs(_ socket: String, _ command: [String]) -> [String] {
        ["@", "--password", password, "--to", "unix:\(socket)"] + command
    }

    private func parseWindows(from json: String) -> [KittyWindow] {
        guard let data = json.data(using: .utf8),
              let osWindows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        var result: [KittyWindow] = []
        for osWindow in osWindows {
            guard let tabs = osWindow["tabs"] as? [[String: Any]] else { continue }
            for tab in tabs {
                guard let windows = tab["windows"] as? [[String: Any]] else { continue }
                for window in windows {
                    guard let id = window["id"] as? Int else { continue }
                    let fgProcesses = window["foreground_processes"] as? [[String: Any]] ?? []
                    let cmdlines = fgProcesses.compactMap { $0["cmdline"] as? [String] }
                    result.append(KittyWindow(id: id, foregroundCmdlines: cmdlines))
                }
            }
        }
        return result
    }
}

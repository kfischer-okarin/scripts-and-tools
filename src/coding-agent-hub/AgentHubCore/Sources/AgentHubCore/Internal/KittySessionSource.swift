import Foundation

struct KittyWindow {
    let id: Int
    let foregroundCmdlines: [[String]]
}

struct KittySessionSource: SessionSource {
    let shell: ShellExecutor
    let password: String?

    func discoverSessions() async throws -> [String] {
        let json = try await shell.run("kitten", arguments: kittenArgs(["ls"]))
        let windows = parseWindows(from: json)
        return windows
            .filter { window in
                window.foregroundCmdlines.contains { cmdline in
                    cmdline.contains { $0.contains("claude") }
                }
            }
            .map { String($0.id) }
    }

    func captureOutput(session: String) async -> String {
        (try? await shell.run("kitten", arguments: kittenArgs(["get-text", "--match", "id:\(session)"]))) ?? ""
    }

    private func kittenArgs(_ command: [String]) -> [String] {
        if let password {
            return ["@", "--password", password] + command
        }
        return ["@"] + command
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

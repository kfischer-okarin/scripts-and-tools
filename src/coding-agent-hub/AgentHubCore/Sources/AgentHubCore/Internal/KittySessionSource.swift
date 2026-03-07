import Foundation

struct KittyWindow {
    let id: Int
    let cmdline: [String]
}

struct KittySessionSource: SessionSource {
    let shell: ShellExecutor

    func discoverSessions() async throws -> [String] {
        let json = try await shell.run("kitten", arguments: ["@", "ls"])
        let windows = parseWindows(from: json)
        return windows
            .filter { $0.cmdline.contains(where: { $0.contains("claude") }) }
            .map { String($0.id) }
    }

    func captureOutput(session: String) async -> String {
        (try? await shell.run("kitten", arguments: ["@", "get-text", "--match", "id:\(session)"])) ?? ""
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
                    guard let id = window["id"] as? Int,
                          let cmdline = window["cmdline"] as? [String]
                    else { continue }
                    result.append(KittyWindow(id: id, cmdline: cmdline))
                }
            }
        }
        return result
    }
}

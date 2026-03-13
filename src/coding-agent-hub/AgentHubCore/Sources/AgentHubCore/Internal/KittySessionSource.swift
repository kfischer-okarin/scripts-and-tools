import AppKit
import Foundation
import os

private let kittyLogger = Logger(subsystem: "com.codingagenthub", category: "kitty")

struct KittyWindow {
    let id: Int
    let title: String
    let cwd: String
    let foregroundCmdlines: [[String]]
}

struct KittySessionSource: SessionSource {
    let shell: ShellExecutor
    let socketPrefix: String

    func discoverSessions() async throws -> [DiscoveredSession] {
        let sockets = try await findSockets()
        kittyLogger.debug("Found \(sockets.count, privacy: .public) sockets")
        guard !sockets.isEmpty else { return [] }

        var sessions: [DiscoveredSession] = []
        var errors: [Error] = []
        for socket in sockets {
            do {
                let json = try await shell.run("kitten", arguments: kittenArgs(socket, ["ls"]))
                let windows = parseWindows(from: json)
                kittyLogger.debug("Socket \(socket, privacy: .public): \(windows.count, privacy: .public) windows")
                let discovered = windows
                    .filter { window in
                        window.foregroundCmdlines.contains { cmdline in
                            cmdline.first == "claude"
                            && !cmdline.contains("-p")
                            && !cmdline.contains("--print")
                        }
                    }
                    .map { DiscoveredSession(id: "\(socket):\($0.id)", title: $0.title, cwd: $0.cwd) }
                kittyLogger.debug("Socket \(socket, privacy: .public): \(discovered.count, privacy: .public) claude sessions")
                sessions.append(contentsOf: discovered)
            } catch {
                kittyLogger.warning("Socket \(socket, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                errors.append(error)
            }
        }
        if sessions.isEmpty && errors.count == sockets.count && !errors.isEmpty {
            throw errors[0]
        }
        return sessions
    }

    func captureOutput(session: String) async -> String {
        let (socket, windowId) = parseSessionId(session)
        guard let socket, let windowId else {
            kittyLogger.warning("Invalid session ID: \(session, privacy: .public)")
            return ""
        }
        do {
            let output = try await shell.run("kitten", arguments: kittenArgs(socket, ["get-text", "--extent", "all", "--match", "id:\(windowId)"]))
            kittyLogger.debug("Captured \(output.count, privacy: .public) chars from window \(windowId, privacy: .public)")
            return output
        } catch {
            kittyLogger.warning("Capture failed for window \(windowId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    func focusSession(_ sessionId: String) async {
        let (socket, windowId) = parseSessionId(sessionId)
        guard let socket, let windowId else { return }
        _ = try? await shell.run("kitten", arguments: kittenArgs(socket, ["focus-window", "--match", "id:\(windowId)"]))
        activateKittyProcess(socket: socket)
    }

    private func parseSessionId(_ session: String) -> (socket: String?, windowId: String?) {
        let parts = session.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return (nil, nil) }
        return (String(parts[0]), String(parts[1]))
    }

    private func activateKittyProcess(socket: String) {
        let filename = (socket as NSString).lastPathComponent
        guard let dashRange = filename.range(of: "-", options: .backwards),
              let pid = Int32(filename[dashRange.upperBound...])
        else { return }
        NSRunningApplication(processIdentifier: pid)?.activate()
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
        ["@", "--to", "unix:\(socket)"] + command
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
                    let title = window["title"] as? String ?? ""
                    let fgProcesses = window["foreground_processes"] as? [[String: Any]] ?? []
                    let cmdlines = fgProcesses.compactMap { $0["cmdline"] as? [String] }
                    let cwd = fgProcesses.first.flatMap { $0["cwd"] as? String } ?? ""
                    result.append(KittyWindow(id: id, title: title, cwd: cwd, foregroundCmdlines: cmdlines))
                }
            }
        }
        return result
    }
}

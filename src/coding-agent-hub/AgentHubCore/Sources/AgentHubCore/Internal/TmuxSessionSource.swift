// NOTE: Currently unused — kept in case we need to revive tmux-based session discovery.
// The wrapper script at bin/claude-wrapper.sh pairs with this source.
struct TmuxSessionSource: SessionSource {
    let shell: ShellExecutor

    func discoverSessions() async -> [DiscoveredSession] {
        let output = (try? await shell.run("tmux", arguments: ["list-sessions", "-F", "#{session_name}"])) ?? ""
        return output.split(separator: "\n").map(String.init).filter { $0.hasPrefix("agent-") }
            .map { DiscoveredSession(id: $0, title: $0, cwd: "") }
    }

    func focusSession(_ sessionId: String) async {}

    func captureOutput(session: String) async -> String {
        (try? await shell.run("tmux", arguments: ["capture-pane", "-p", "-t", session, "-S", "-30"])) ?? ""
    }
}

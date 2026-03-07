import Foundation
import Observation

@Observable
public final class AgentHub {
    public private(set) var sessions: [AgentSession] = []

    private let shell: ShellExecutor

    public init(shell: ShellExecutor) {
        self.shell = shell
    }

    public func refresh() async {
        let sessionNames = await discoverAgentSessions()
        var updated: [AgentSession] = []
        for name in sessionNames {
            let output = (try? await shell.run("tmux", arguments: ["capture-pane", "-p", "-t", name, "-S", "-30"])) ?? ""
            let status = parseStatus(from: output)
            updated.append(AgentSession(id: name, status: status))
        }
        sessions = updated
    }

    private func discoverAgentSessions() async -> [String] {
        let output = (try? await shell.run("tmux", arguments: ["list-sessions", "-F", "#{session_name}"])) ?? ""
        return output.split(separator: "\n").map(String.init).filter { $0.hasPrefix("agent-") }
    }

    private func parseStatus(from output: String) -> SessionStatus {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for (index, line) in lines.enumerated().reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Do you want to") {
                return .awaitingPermission
            }
            if trimmed.hasPrefix("❯") && index > 0 && lines[index - 1].contains("─") {
                return .awaitingUserInput
            }
            if let first = trimmed.first, "·✢✳✶✻✽".contains(first) && trimmed.contains("…") {
                return .working
            }
        }
        return .unknown
    }
}

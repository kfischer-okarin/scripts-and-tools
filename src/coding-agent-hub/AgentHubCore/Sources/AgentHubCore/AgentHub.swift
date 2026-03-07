import Foundation
import Observation

@Observable
public final class AgentHub {
    public private(set) var sessions: [AgentSession] = []
    public private(set) var errorMessage: String?

    private let source: SessionSource

    public init(shell: ShellExecutor, kittyPassword: String, kittySocketPrefix: String) {
        self.source = KittySessionSource(shell: shell, password: kittyPassword, socketPrefix: kittySocketPrefix)
    }

    public func refresh() async {
        let sessionIds: [String]
        do {
            sessionIds = try await source.discoverSessions()
            errorMessage = nil
        } catch {
            sessions = []
            errorMessage = error.localizedDescription
            return
        }

        var updated: [AgentSession] = []
        for id in sessionIds {
            let output = await source.captureOutput(session: id)
            let status = parseStatus(from: output)
            updated.append(AgentSession(id: id, status: status))
        }
        sessions = updated
    }

    private func parseStatus(from output: String) -> SessionStatus {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var hasInputPrompt = false
        for (index, line) in lines.enumerated().reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Do you want to") {
                return .awaitingPermission
            }
            if trimmed.hasPrefix("❯") && index > 0 && lines[index - 1].contains("─") {
                hasInputPrompt = true
            }
            if let first = trimmed.first, "·✢✳✶✻✽".contains(first) && trimmed.contains("…") {
                return .working
            }
        }
        return hasInputPrompt ? .awaitingUserInput : .unknown
    }
}

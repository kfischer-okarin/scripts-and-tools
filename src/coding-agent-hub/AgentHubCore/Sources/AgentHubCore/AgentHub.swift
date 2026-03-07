import Foundation
import Observation

@Observable
public final class AgentHub {
    public private(set) var sessions: [AgentSession] = []
    public private(set) var errorMessage: String?

    private let source: SessionSource
    private let statusParser = StatusParser()

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
            let status = statusParser.parse(output)
            updated.append(AgentSession(id: id, status: status))
        }
        sessions = updated
    }
}

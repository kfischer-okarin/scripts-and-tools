import Foundation
import Observation

@Observable
public final class AgentHub {
    public private(set) var sessions: [AgentSession] = []
    public private(set) var errorMessage: String?

    private let source: SessionSource
    private let homeDirectory: String
    private let statusParser = StatusParser()
    private let contextParser = ContextParser()

    public init(shell: ShellExecutor, kittyPassword: String, kittySocketPrefix: String) {
        self.source = KittySessionSource(shell: shell, password: kittyPassword, socketPrefix: kittySocketPrefix)
        self.homeDirectory = shell.homeDirectory
    }

    public func refresh() async {
        let discovered: [DiscoveredSession]
        do {
            discovered = try await source.discoverSessions()
            errorMessage = nil
        } catch {
            sessions = []
            errorMessage = error.localizedDescription
            return
        }

        var updated: [AgentSession] = []
        for session in discovered {
            let output = await source.captureOutput(session: session.id)
            let status = statusParser.parse(output)
            let context = contextParser.parse(output)
            let cwd = session.cwd.hasPrefix(homeDirectory)
                ? "~" + session.cwd.dropFirst(homeDirectory.count)
                : session.cwd
            updated.append(AgentSession(id: session.id, title: session.title, cwd: String(cwd), context: context, status: status))
        }
        sessions = updated
    }
}

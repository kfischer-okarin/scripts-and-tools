import Foundation
import Observation

@Observable
public final class AgentHub {
    public private(set) var sessions: [AgentSession] = []
    public private(set) var errorMessage: String?

    private let source: SessionSource
    private let homeDirectory: String
    private let clock: AppClock
    private let statusParser = StatusParser()
    private let contextParser = ContextParser()
    private var lastOutputHashes: [String: Int] = [:]
    private var lastUpdatedTimes: [String: Date] = [:]

    public init(shell: ShellExecutor, kittyPassword: String, kittySocketPrefix: String, clock: AppClock = SystemClock()) {
        self.source = KittySessionSource(shell: shell, password: kittyPassword, socketPrefix: kittySocketPrefix)
        self.homeDirectory = shell.homeDirectory
        self.clock = clock
    }

    public func focusSession(_ session: AgentSession) async {
        await source.focusSession(session.id)
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

        let now = clock.now()
        var updated: [AgentSession] = []
        for session in discovered {
            let output = await source.captureOutput(session: session.id)
            let outputHash = output.hashValue

            if lastOutputHashes[session.id] != outputHash {
                lastOutputHashes[session.id] = outputHash
                lastUpdatedTimes[session.id] = now
            }

            let status = statusParser.parse(output)
            let context = contextParser.parse(output)
            let cwd = session.cwd.hasPrefix(homeDirectory)
                ? "~" + session.cwd.dropFirst(homeDirectory.count)
                : session.cwd
            updated.append(AgentSession(
                id: session.id, title: session.title, cwd: String(cwd),
                context: context, status: status,
                lastUpdated: lastUpdatedTimes[session.id] ?? now
            ))
        }
        sessions = updated
    }
}

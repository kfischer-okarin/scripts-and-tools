struct DiscoveredSession {
    let id: String
    let title: String
    let cwd: String
}

protocol SessionSource {
    func discoverSessions() async throws -> [DiscoveredSession]
    func captureOutput(session: String) async -> String
}

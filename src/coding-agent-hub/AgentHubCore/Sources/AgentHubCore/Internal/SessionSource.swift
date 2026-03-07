protocol SessionSource {
    func discoverSessions() async throws -> [String]
    func captureOutput(session: String) async -> String
}

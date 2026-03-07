protocol SessionSource {
    func discoverSessions() async -> [String]
    func captureOutput(session: String) async -> String
}

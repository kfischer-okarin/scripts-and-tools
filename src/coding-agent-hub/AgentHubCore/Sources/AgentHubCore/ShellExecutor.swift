public protocol ShellExecutor: Sendable {
    func run(_ command: String, arguments: [String]) async throws -> String
}

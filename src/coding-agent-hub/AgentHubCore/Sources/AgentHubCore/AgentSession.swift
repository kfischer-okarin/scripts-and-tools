public struct AgentSession: Identifiable {
    public let id: String
    public let title: String
    public let cwd: String
    public let context: [String]
    public var status: SessionStatus
}

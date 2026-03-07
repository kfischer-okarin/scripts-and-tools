import Foundation

public protocol ShellExecutor: Sendable {
    var homeDirectory: String { get }
    func run(_ command: String, arguments: [String]) async throws -> String
}

public struct ShellError: Error, LocalizedError {
    public let message: String
    public init(message: String) { self.message = message }
    public var errorDescription: String? { message }
}

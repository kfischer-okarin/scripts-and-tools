import Foundation

public protocol AppClock: Sendable {
    func now() -> Date
}

public struct SystemClock: AppClock {
    public init() {}
    public func now() -> Date { Date() }
}

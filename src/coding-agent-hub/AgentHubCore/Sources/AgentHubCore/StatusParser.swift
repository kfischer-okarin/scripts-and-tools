public struct StatusParser {
    public init() {}

    public func parse(_ output: String) -> SessionStatus {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var hasInputPrompt = false
        for (index, line) in lines.enumerated().reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Do you want to") && hasOptionsBelow(lines: lines, from: index) {
                return .awaitingPermission
            }
            if isUserInputLine(lines: lines, at: index) {
                hasInputPrompt = true
            }
            if let first = trimmed.first, "·✢✳✶✻✽".contains(first) && trimmed.contains("…") {
                return .working
            }
        }
        return hasInputPrompt ? .awaitingUserInput : .unknown
    }

    private func isUserInputLine(lines: [String], at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("❯"), index > 0 else { return false }
        let previousLine = lines[index - 1].trimmingCharacters(in: .whitespaces)
        return previousLine.hasPrefix(String(repeating: "─", count: 10))
    }

    private func hasOptionsBelow(lines: [String], from index: Int) -> Bool {
        for i in (index + 1)..<min(index + 4, lines.count) {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("❯") && !isUserInputLine(lines: lines, at: i) {
                return true
            }
        }
        return false
    }
}

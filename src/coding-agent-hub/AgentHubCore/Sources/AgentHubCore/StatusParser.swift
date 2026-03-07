public struct StatusParser {
    public init() {}

    public func parse(_ output: String) -> SessionStatus {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let inputAreaIndex = findInputArea(lines: lines) else {
            return .needingUserInput
        }
        let hyphenLineIndex = inputAreaIndex - 1
        if hasThinkingIndicator(lines: lines, above: hyphenLineIndex, within: 5) {
            return .working
        }
        return .idle
    }

    private func findInputArea(lines: [String]) -> Int? {
        for index in lines.indices.reversed() {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("❯"), index > 0 else { continue }
            let previousLine = lines[index - 1].trimmingCharacters(in: .whitespaces)
            if previousLine.hasPrefix(String(repeating: "─", count: 10)) {
                return index
            }
        }
        return nil
    }

    private func hasThinkingIndicator(lines: [String], above index: Int, within range: Int) -> Bool {
        let start = max(0, index - range)
        for i in stride(from: index - 1, through: start, by: -1) {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if let first = trimmed.first, "·✢✳✶✻✽".contains(first) && trimmed.contains("…") {
                return true
            }
        }
        return false
    }
}

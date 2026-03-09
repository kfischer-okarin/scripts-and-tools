public struct ContextParser {
    public init() {}

    public func parse(_ output: String) -> [String] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        if let topBorderIndex = findInputAreaTopBorder(lines: lines) {
            return linesAbove(topBorderIndex, in: lines)
        }

        if let promptBorderIndex = findPromptBorder(lines: lines) {
            return linesBelow(promptBorderIndex, in: lines)
        }

        return []
    }

    private func linesAbove(_ borderIndex: Int, in lines: [String]) -> [String] {
        let anchorIndex = findThinkingIndicator(lines: lines, above: borderIndex) ?? borderIndex
        let contentEnd = anchorIndex - 1
        guard contentEnd >= 0, trimmed(lines[contentEnd]).isEmpty else { return [] }

        let contentLines = lines[0..<contentEnd].filter { !trimmed($0).isEmpty }
        return Array(contentLines.suffix(5))
    }

    private func linesBelow(_ borderIndex: Int, in lines: [String]) -> [String] {
        let remaining = Array(lines[(borderIndex + 1)...])
        if let planIndex = remaining.firstIndex(where: { trimmed($0).lowercased().contains("plan:") }) {
            var startIndex = planIndex + 1
            if startIndex < remaining.count, isDashedLine(trimmed(remaining[startIndex])) {
                startIndex += 1
            }
            return Array(remaining[startIndex...].prefix(5))
        }
        return Array(remaining.prefix(5))
    }

    private func isDashedLine(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        return "─╌".contains(first) && line.count >= 10
    }

    private func trimmed(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespaces)
    }

    private func findThinkingIndicator(lines: [String], above index: Int) -> Int? {
        for i in stride(from: index - 1, through: max(0, index - 5), by: -1) {
            let t = trimmed(lines[i])
            if let first = t.first, "·✢✳✶✻✽".contains(first) && t.contains("…") {
                return i
            }
        }
        return nil
    }

    private func findInputAreaTopBorder(lines: [String]) -> Int? {
        let separator = String(repeating: "─", count: 10)
        for index in lines.indices.reversed() {
            guard trimmed(lines[index]).hasPrefix("❯"), index > 0 else { continue }
            if trimmed(lines[index - 1]).hasPrefix(separator) {
                return index - 1
            }
        }
        return nil
    }

    private func findPromptBorder(lines: [String]) -> Int? {
        for index in lines.indices.reversed() {
            guard isDashedLine(trimmed(lines[index])) else { continue }
            if index == 0 || trimmed(lines[index - 1]).isEmpty {
                return index
            }
        }
        return nil
    }
}

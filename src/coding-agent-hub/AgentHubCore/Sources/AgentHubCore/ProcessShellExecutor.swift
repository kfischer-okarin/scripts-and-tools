import Foundation

public final class ProcessShellExecutor: ShellExecutor {
    public let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    private let logHandle: FileHandle?

    public init(logPath: String = "/tmp/coding-agent-hub.log", loggingEnabled: Bool = false) {
        if loggingEnabled {
            FileManager.default.createFile(atPath: logPath, contents: nil)
            self.logHandle = FileHandle(forWritingAtPath: logPath)
            logHandle?.seekToEndOfFile()
        } else {
            self.logHandle = nil
        }
    }

    deinit {
        logHandle?.closeFile()
    }

    public func run(_ command: String, arguments: [String]) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        try process.run()
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let cmdString = ([command] + arguments).joined(separator: " ")

        if process.terminationStatus != 0 {
            log("FAIL [\(process.terminationStatus)] \(cmdString)\nstderr: \(stderr)")
            throw ShellError(message: stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        log("OK \(cmdString)\nstdout: \(String(stdout.prefix(500)))")
        return stdout
    }

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        if let data = "[\(timestamp)] \(message)\n".data(using: .utf8) {
            logHandle?.write(data)
        }
    }
}

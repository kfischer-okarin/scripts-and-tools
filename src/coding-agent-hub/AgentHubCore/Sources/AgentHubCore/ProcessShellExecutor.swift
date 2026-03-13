import Foundation
import os

private let shellLogger = Logger(subsystem: "com.codingagenthub", category: "shell")

private final class PipeCollector: @unchecked Sendable {
    var data = Data()
}

private func drainPipe(_ pipe: Pipe, group: DispatchGroup) -> PipeCollector {
    let collector = PipeCollector()
    group.enter()
    pipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        if chunk.isEmpty {
            pipe.fileHandleForReading.readabilityHandler = nil
            group.leave()
        } else {
            collector.data.append(chunk)
        }
    }
    return collector
}

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
        let cmdString = ([command] + arguments).joined(separator: " ")
        shellLogger.debug("START \(cmdString, privacy: .public)")
        let start = ContinuousClock.now

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data, Data, Int32), Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [command] + arguments
                process.environment = Self.processEnvironment
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let group = DispatchGroup()
                let stdoutCollector = drainPipe(stdoutPipe, group: group)
                let stderrCollector = drainPipe(stderrPipe, group: group)

                do {
                    try process.run()
                } catch {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                    return
                }

                stdoutPipe.fileHandleForWriting.closeFile()
                stderrPipe.fileHandleForWriting.closeFile()

                process.waitUntilExit()
                group.wait()

                stdoutPipe.fileHandleForReading.closeFile()
                stderrPipe.fileHandleForReading.closeFile()

                continuation.resume(returning: (stdoutCollector.data, stderrCollector.data, process.terminationStatus))
            }
        }

        let (stdoutData, stderrData, exitStatus) = result
        let elapsed = ContinuousClock.now - start
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        if exitStatus != 0 {
            shellLogger.warning("FAIL [\(exitStatus, privacy: .public)] \(cmdString, privacy: .public) (\(elapsed, privacy: .public)) stderr=\(stderr.prefix(500), privacy: .public)")
            log("FAIL [\(exitStatus)] \(cmdString)\nstderr: \(stderr)")
            throw ShellError(message: stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        shellLogger.debug("OK \(cmdString, privacy: .public) (\(elapsed, privacy: .public)) stdout=\(stdoutData.count, privacy: .public)B")
        log("OK \(cmdString)\nstdout: \(String(stdout.prefix(500)))")
        return stdout
    }

    private static let processEnvironment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        let extra = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
        ]
        let current = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let missing = extra.filter { !current.contains($0) }
        if !missing.isEmpty {
            env["PATH"] = (missing + [current]).joined(separator: ":")
        }
        return env
    }()

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        if let data = "[\(timestamp)] \(message)\n".data(using: .utf8) {
            logHandle?.write(data)
        }
    }
}

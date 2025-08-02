#!/usr/bin/env swift

import Foundation
import AppKit

// Define message types as an enum with associated values
enum LogMessage {
    case appActive(app: String)
    case systemMessage(message: String)

    var type: String {
        switch self {
        case .appActive: return "appActive"
        case .systemMessage: return "systemMessage"
        }
    }

    var orderedPairs: KeyValuePairs<String, Any> {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        let timestamp = dateFormatter.string(from: Date())

        switch self {
        case .appActive(let app):
            return [
                "timestamp": timestamp,
                "type": type,
                "app": app
            ]
        case .systemMessage(let message):
            return [
                "timestamp": timestamp,
                "type": type,
                "message": message
            ]
        }
    }
}

// Data directory for logs
let dataDir = "\(NSHomeDirectory())/.local/share/ActiveAppMonitor"

// Create directory if it doesn't exist
try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)

// Get current date for filename
func getCurrentDateString() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone.current
    return dateFormatter.string(from: Date())
}

private func orderedToJson(_ pairs: KeyValuePairs<String, Any>) -> String? {
    var jsonParts = [String]()

    for (key, value) in pairs {
        // Handle different value types
        let valueString: String

        if let stringValue = value as? String {
            // Manually escape string values
            let escapedValue = stringValue
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            valueString = "\"\(escapedValue)\""
        } else if let numberValue = value as? NSNumber {
            // Numbers don't need quotes
            valueString = "\(numberValue)"
        } else if let boolValue = value as? Bool {
            // Booleans
            valueString = boolValue ? "true" : "false"
        } else {
            // For complex types, wrap in array and use JSONSerialization
            if let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
               let jsonString = String(data: data, encoding: .utf8),
               jsonString.count > 2 {
                // Extract the value from [value] -> remove [ and ]
                let trimmed = jsonString.dropFirst().dropLast()
                valueString = String(trimmed)
            } else {
                continue
            }
        }

        jsonParts.append("\"\(key)\":\(valueString)")
    }

    return "{\(jsonParts.joined(separator: ","))}"
}

func logMessage(_ message: LogMessage) {
    guard let jsonString = orderedToJson(message.orderedPairs) else { return }

    // Write to stdout if running from terminal
    print(jsonString)

    // Get current log path (this can change if date changes)
    let logPath = "\(dataDir)/activity-\(getCurrentDateString()).log"
    let logURL = URL(fileURLWithPath: logPath)

    // Also write to log file
    let logEntry = jsonString + "\n"
    if let data = logEntry.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
}

// 1) Log startup
logMessage(.systemMessage(message: "ActiveAppMonitor started"))

// 2) Subscribe to activation notifications
let nc = NSWorkspace.shared.notificationCenter
nc.addObserver(
  forName: NSWorkspace.didActivateApplicationNotification,
  object: nil,
  queue: .main
) { note in
    if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                 as? NSRunningApplication {
        logMessage(.appActive(app: app.localizedName ?? "Unknown"))
    }
}

// 3) Spin the run loop
RunLoop.main.run()

#!/usr/bin/env swift

import Foundation
import AppKit

// Set up logging to file
let dataDir = "\(NSHomeDirectory())/.local/share/ActiveAppMonitor"
let logPath = "\(dataDir)/activity.log"

// Create directory if it doesn't exist
try? FileManager.default.createDirectory(atPath: dataDir, withIntermediateDirectories: true, attributes: nil)

let logURL = URL(fileURLWithPath: logPath)

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

func logMessage(_ type: String, _ content: [String: String]) {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone.current
    let timestamp = dateFormatter.string(from: Date())

    // Build ordered key-value pairs based on type
    let orderedPairs: KeyValuePairs<String, Any>

    switch type {
    case "appActive":
        orderedPairs = [
            "timestamp": timestamp,
            "type": type,
            "app": content["app"] ?? "Unknown"
        ]
    case "systemMessage":
        orderedPairs = [
            "timestamp": timestamp,
            "type": type,
            "message": content["message"] ?? ""
        ]
    default:
        orderedPairs = [
            "timestamp": timestamp,
            "type": type
        ]
    }

    guard let jsonString = orderedToJson(orderedPairs) else { return }

    // Write to stdout if running from terminal
    print(jsonString)

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
logMessage("systemMessage", ["message": "ActiveAppMonitor started"])

// 2) Subscribe to activation notifications
let nc = NSWorkspace.shared.notificationCenter
nc.addObserver(
  forName: NSWorkspace.didActivateApplicationNotification,
  object: nil,
  queue: .main
) { note in
    if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                 as? NSRunningApplication {
        logMessage("appActive", ["app": app.localizedName ?? "Unknown"])
    }
}

// 3) Spin the run loop
RunLoop.main.run()

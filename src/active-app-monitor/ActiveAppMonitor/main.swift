#!/usr/bin/env swift

import Foundation
import AppKit

// Set up logging to file
let logPath = "\(NSHomeDirectory())/Library/Logs/ActiveAppMonitor.log"
let logURL = URL(fileURLWithPath: logPath)

func logMessage(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    let logEntry = "[\(timestamp)] \(message)\n"

    // Write to stdout if running from terminal
    print(message)

    // Also write to log file
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
if let name = NSWorkspace.shared.frontmostApplication?.localizedName {
    logMessage("▶️ ActiveAppMonitor started. Currently active: \(name)")
} else {
    logMessage("▶️ ActiveAppMonitor started. (couldn't read initial frontmost app)")
}

// 2) Subscribe to activation notifications
let nc = NSWorkspace.shared.notificationCenter
nc.addObserver(
  forName: NSWorkspace.didActivateApplicationNotification,
  object: nil,
  queue: .main
) { note in
    if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
                 as? NSRunningApplication {
        logMessage("→ Switched to: \(app.localizedName ?? "Unknown")")
    }
}

// 3) Spin the run loop
RunLoop.main.run()

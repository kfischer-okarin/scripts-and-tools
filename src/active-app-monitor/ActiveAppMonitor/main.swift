#!/usr/bin/env swift -I . Logger.swift

import Foundation
import AppKit

// Initialize logging
initializeLogging()

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

//
//  Logging.swift
//  SpaceWalker
//
//  Created by andev on 10/22/25.
//

import Foundation
import os

/// Centralized OSLog/Logger utility
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "SpaceWalker"

    static let general = Logger(subsystem: subsystem, category: "General")
    static let auth    = Logger(subsystem: subsystem, category: "Auth")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let ui      = Logger(subsystem: subsystem, category: "UI")

    // Timestamp formatter for HH:mm:ss.SSS (thread-safe via serial queue)
    private static let tsQueue = DispatchQueue(label: "AppLog.timestamp.formatter")
    private static let tsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .current
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func timestamp() -> String {
        tsQueue.sync { tsFormatter.string(from: Date()) }
    }
}

// MARK: - Debug-only helpers
func LogGeneral(_ message: String) {
    #if DEBUG
    let ts = AppLog.timestamp()
    AppLog.general.debug("[\(ts)] \(message, privacy: .public)")
    #endif
}

func LogAuth(_ message: String) {
    #if DEBUG
    let ts = AppLog.timestamp()
    AppLog.auth.debug("[\(ts)] \(message, privacy: .public)")
    #endif
}

func LogNetwork(_ message: String) {
    #if DEBUG
    let ts = AppLog.timestamp()
    AppLog.network.debug("[\(ts)] \(message, privacy: .public)")
    #endif
}

func LogUI(_ message: String) {
    #if DEBUG
    let ts = AppLog.timestamp()
    AppLog.ui.debug("[\(ts)] \(message, privacy: .public)")
    #endif
}


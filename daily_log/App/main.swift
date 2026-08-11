//
//  main.swift
//  daily_log
//
//  Plain AppKit entry point: an LSUIElement agent owns its windows directly,
//  so there is no SwiftUI App scene to suppress.
//

import AppKit

/// NSApplication holds its delegate weakly.
nonisolated(unsafe) var retainedDelegate: AppDelegate?

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    retainedDelegate = delegate
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}

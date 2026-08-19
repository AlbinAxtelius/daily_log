//
//  AppInfo.swift
//  daily_log
//
//  Where the running build says what it is.
//
//  Ad-hoc signing means an upgrade can look like a different app to macOS, so
//  "which build am I actually looking at?" is a question worth being able to
//  answer without opening Finder.
//

import Foundation

enum AppInfo {
    /// `CFBundleShortVersionString` — the marketing version, e.g. `1.0.1`.
    static let version: String = string(for: "CFBundleShortVersionString")

    /// `CFBundleVersion` — the build number.
    static let build: String = string(for: "CFBundleVersion")

    /// Chrome-sized, e.g. `v1.0.1`.
    static var short: String { "v\(version)" }

    /// Tooltip-sized, e.g. `Version 1.0.1 (1)`. The build number only earns its
    /// place when it says something the version doesn't.
    static var full: String {
        build.isEmpty || build == version
            ? "Version \(version)"
            : "Version \(version) (\(build))"
    }

    /// Falls back rather than crashing: the test bundle has no host app, so
    /// `Bundle.main` there is the xctest runner and carries neither key.
    private static func string(for key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? "—"
    }
}

//
//  Formatting.swift
//  daily_log
//

import Foundation

enum Fmt {
    /// Hours, trimmed: 6 -> "6", 5.5 -> "5.5", 4.25 -> "4.25".
    static func hours(_ h: Double) -> String {
        if h == 0 { return "0" }
        var s = String(format: "%.2f", h)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// Every total the app shows is a hint, never a figure. Hence the tilde.
    static func approxHours(_ h: Double) -> String { "~\(hours(h))h" }

    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dayShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE MM-dd"
        return f
    }()

    /// "Mon"
    static let weekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    /// "3 Aug"
    static let dayCompact: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    static let dayLong: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    static let dayFull: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f
    }()

    static func minutesOfDay(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }

    /// A derived span: "45m", "1h", "1h 30m".
    static func duration(minutes: Double) -> String {
        let total = max(0, Int(minutes.rounded()))
        if total < 60 { return "\(total)m" }
        let h = total / 60, rest = total % 60
        return rest == 0 ? "\(h)h" : "\(h)h \(rest)m"
    }
}

//
//  Models.swift
//  daily_log
//
//  Entry, Project, Settings — the whole data model.
//

import Foundation
import Carbon.HIToolbox

// MARK: - Entry

/// A single "here's what I'm doing" stamp. No end time, no duration:
/// duration is derived from the next entry (see `Store.timeline(onDay:)`).
struct Entry: Identifiable, Codable, Hashable {
    var id: String
    var at: Date
    var project: String
    var note: String

    init(id: String = Entry.newID(), at: Date, project: String, note: String) {
        self.id = id
        self.at = at
        self.project = project
        self.note = note
    }

    static func newID() -> String {
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        let salt = UInt32.random(in: 0 ... .max)
        return "e_" + String(ms, radix: 36).uppercased() + String(salt, radix: 36).uppercased()
    }
}

// MARK: - Project

struct Project: Identifiable, Codable, Hashable {
    var key: String
    var name: String
    var archived: Bool

    var id: String { key }

    init(key: String, name: String? = nil, archived: Bool = false) {
        self.key = key
        self.name = name ?? key
        self.archived = archived
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? key
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }

    /// `acme portal!` -> `acmeportal`. Tags are keys; the display name is free-form.
    static func slug(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let kept = lowered.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        }
        return String(String.UnicodeScalarView(kept))
    }
}

// MARK: - Settings

struct Settings: Codable, Equatable {
    /// Carbon virtual key code + Carbon modifier mask. Default ⌃⌥Space.
    var hotKeyCode: UInt32 = UInt32(kVK_Space)
    var hotKeyModifiers: UInt32 = UInt32(controlKey | optionKey)

    /// `Calendar` weekdays, 1 = Sunday. Default Mon–Fri.
    var workDays: [Int] = [2, 3, 4, 5, 6]
    /// Minutes past midnight.
    var workStartMinutes: Int = 8 * 60
    var workEndMinutes: Int = 17 * 60

    /// Nudge after this much silence.
    var silenceMinutes: Int = 60
    /// End-of-day summary, minutes past midnight.
    var endOfDayMinutes: Int = 16 * 60 + 30

    /// Derived durations are clamped to this.
    var capMinutes: Int = 90
    /// A day runs dayStartHour -> dayStartHour.
    var dayStartHour: Int = 4

    /// nil = the default Application Support location.
    var dataPath: String?

    /// Set once the first-run consent sheet has been shown.
    var didOnboard: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        hotKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .hotKeyCode) ?? d.hotKeyCode
        hotKeyModifiers = try c.decodeIfPresent(UInt32.self, forKey: .hotKeyModifiers) ?? d.hotKeyModifiers
        workDays = try c.decodeIfPresent([Int].self, forKey: .workDays) ?? d.workDays
        workStartMinutes = try c.decodeIfPresent(Int.self, forKey: .workStartMinutes) ?? d.workStartMinutes
        workEndMinutes = try c.decodeIfPresent(Int.self, forKey: .workEndMinutes) ?? d.workEndMinutes
        silenceMinutes = try c.decodeIfPresent(Int.self, forKey: .silenceMinutes) ?? d.silenceMinutes
        endOfDayMinutes = try c.decodeIfPresent(Int.self, forKey: .endOfDayMinutes) ?? d.endOfDayMinutes
        capMinutes = try c.decodeIfPresent(Int.self, forKey: .capMinutes) ?? d.capMinutes
        dayStartHour = try c.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? d.dayStartHour
        dataPath = try c.decodeIfPresent(String.self, forKey: .dataPath)
        didOnboard = try c.decodeIfPresent(Bool.self, forKey: .didOnboard) ?? false
    }

    /// True if `date` falls inside the configured work window.
    func isWorkTime(_ date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = comps.weekday, workDays.contains(weekday) else { return false }
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return minutes >= workStartMinutes && minutes < workEndMinutes
    }
}

// MARK: - JSON

enum JSONIO {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(iso.string(from: date))
        }
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = iso.date(from: s) ?? isoFractional.date(from: s) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unreadable date \(s)")
            )
        }
        return d
    }()
}

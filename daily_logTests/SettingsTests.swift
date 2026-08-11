//
//  SettingsTests.swift
//  daily_logTests
//

import Foundation
import Testing

@Suite("Settings.isWorkTime")
struct WorkTimeTests {
    /// A fixed calendar, so these don't depend on where the test machine sits.
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return cal
    }()

    private static func date(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute) = (2026, 8, day, hour, minute)
        return calendar.date(from: c)!
    }

    @Test("Inside the default Mon–Fri 08:00–17:00 window")
    func inside() {
        // 2026-08-05 is a Wednesday.
        #expect(Settings().isWorkTime(Self.date(5, 10, 0), calendar: Self.calendar))
        #expect(Settings().isWorkTime(Self.date(5, 8, 0), calendar: Self.calendar))
        #expect(Settings().isWorkTime(Self.date(5, 16, 59), calendar: Self.calendar))
    }

    @Test("Outside it")
    func outside() {
        #expect(!Settings().isWorkTime(Self.date(5, 7, 59), calendar: Self.calendar))
        #expect(!Settings().isWorkTime(Self.date(5, 17, 0), calendar: Self.calendar))
    }

    @Test("Weekends are never work time")
    func weekend() {
        // 2026-08-08 is a Saturday, 08-09 a Sunday.
        #expect(!Settings().isWorkTime(Self.date(8, 10, 0), calendar: Self.calendar))
        #expect(!Settings().isWorkTime(Self.date(9, 10, 0), calendar: Self.calendar))
    }

    @Test("A custom window is honoured")
    func custom() {
        var settings = Settings()
        settings.workDays = [7]                 // Saturday only
        settings.workStartMinutes = 10 * 60
        settings.workEndMinutes = 12 * 60
        #expect(settings.isWorkTime(Self.date(8, 11, 0), calendar: Self.calendar))
        #expect(!settings.isWorkTime(Self.date(8, 12, 0), calendar: Self.calendar))
        #expect(!settings.isWorkTime(Self.date(5, 11, 0), calendar: Self.calendar))
    }
}

@Suite("Settings decoding")
struct SettingsDecodingTests {
    @Test("An empty object decodes to the defaults")
    func emptyObject() throws {
        let decoded = try JSONIO.decoder.decode(Settings.self, from: Data("{}".utf8))
        #expect(decoded == Settings())
    }

    @Test("Unknown-to-old-versions keys fall back per field")
    func partial() throws {
        let json = Data(#"{"capMinutes":45,"dayStartHour":6}"#.utf8)
        let decoded = try JSONIO.decoder.decode(Settings.self, from: json)
        #expect(decoded.capMinutes == 45)
        #expect(decoded.dayStartHour == 6)
        #expect(decoded.silenceMinutes == Settings().silenceMinutes)
        #expect(decoded.workDays == Settings().workDays)
        #expect(decoded.dataPath == nil)
    }

    @Test("Round trip")
    func roundTrip() throws {
        var settings = Settings()
        settings.capMinutes = 120
        settings.dataPath = "~/Documents/daily"
        settings.didOnboard = true
        let data = try JSONIO.encoder.encode(settings)
        #expect(try JSONIO.decoder.decode(Settings.self, from: data) == settings)
    }
}

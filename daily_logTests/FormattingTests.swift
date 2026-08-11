//
//  FormattingTests.swift
//  daily_logTests
//

import Testing

@Suite("Fmt.hours")
struct HoursTests {
    @Test("Trailing zeros are trimmed", arguments: [
        (0.0, "0"),
        (6.0, "6"),
        (5.5, "5.5"),
        (4.25, "4.25"),
        (0.1, "0.1"),
    ])
    func hours(value: Double, expected: String) {
        #expect(Fmt.hours(value) == expected)
    }

    @Test("Totals are hints, so they wear a tilde")
    func approx() {
        #expect(Fmt.approxHours(5.5) == "~5.5h")
        #expect(Fmt.approxHours(0) == "~0h")
    }
}

@Suite("Fmt.minutesOfDay")
struct MinutesOfDayTests {
    @Test("Clock formatting", arguments: [
        (0, "00:00"), (675, "11:15"), (545, "09:05"), (1439, "23:59"),
    ])
    func clock(minutes: Int, expected: String) {
        #expect(Fmt.minutesOfDay(minutes) == expected)
    }
}

@Suite("Fmt.duration")
struct DurationTests {
    @Test("Spans", arguments: [
        (0.0, "0m"),
        (45.0, "45m"),
        (59.6, "1h"),     // rounds to the minute first
        (60.0, "1h"),
        (90.0, "1h 30m"),
        (125.0, "2h 5m"),
    ])
    func duration(minutes: Double, expected: String) {
        #expect(Fmt.duration(minutes: minutes) == expected)
    }

    @Test("Negative spans clamp to zero")
    func negative() {
        #expect(Fmt.duration(minutes: -5) == "0m")
    }
}

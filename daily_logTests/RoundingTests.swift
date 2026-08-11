//
//  RoundingTests.swift
//  daily_logTests
//
//  Every total the app shows is rounded to a quarter hour. Nothing is invented.
//

import Testing

@Suite("Store.roundHours")
struct RoundHoursTests {
    @Test("Quarter-hour rounding", arguments: [
        (0.0, 0.0),
        (45.0, 0.75),
        (90.0, 1.5),      // the default cap
        (100.0, 1.75),    // 1h40 rounds up to 1.75
        (20.0, 0.25),     // 20m rounds up to a quarter
        (7.0, 0.0),       // 7m rounds away to nothing
        (480.0, 8.0),
    ])
    func rounds(minutes: Double, hours: Double) {
        #expect(Store.roundHours(minutes: minutes) == hours)
    }

    @Test("Rounding always lands on a quarter")
    func alwaysQuarters() {
        for minutes in stride(from: 0.0, through: 600.0, by: 1.0) {
            let hours = Store.roundHours(minutes: minutes)
            #expect((hours * 4).truncatingRemainder(dividingBy: 1) == 0)
        }
    }
}

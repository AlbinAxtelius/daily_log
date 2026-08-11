//
//  InputParserTests.swift
//  daily_logTests
//

import Testing

@Suite("InputParser.parse")
struct InputParserParseTests {
    @Test("A tag and a note")
    func tagAndNote() {
        let parsed = InputParser.parse("#acme auth refactor")
        #expect(parsed.timeOfDay == nil)
        #expect(parsed.projectKey == "acme")
        #expect(parsed.note == "auth refactor")
    }

    @Test("Time prefix backfills")
    func timePrefix() {
        let parsed = InputParser.parse("1115 #acme design sync")
        #expect(parsed.timeOfDay == 11 * 60 + 15)
        #expect(parsed.projectKey == "acme")
        #expect(parsed.note == "design sync")
    }

    @Test("A bare note inherits the project")
    func bareNote() {
        let parsed = InputParser.parse("standup")
        #expect(parsed.projectKey == nil)
        #expect(parsed.note == "standup")
    }

    @Test("The tag need not lead")
    func tagInTheMiddle() {
        let parsed = InputParser.parse("auth #acme refactor")
        #expect(parsed.projectKey == "acme")
        #expect(parsed.note == "auth refactor")
    }

    @Test("The tag is slugged")
    func taggedSlug() {
        #expect(InputParser.parse("#Acme-Portal! notes").projectKey == "acme-portal")
    }

    @Test("A lone # is a note, not a tag")
    func loneHash() {
        let parsed = InputParser.parse("# hmm")
        #expect(parsed.projectKey == nil)
        #expect(parsed.note == "# hmm")
    }

    @Test("A time is only a prefix in first position")
    func timeMustLead() {
        let parsed = InputParser.parse("standup 1115")
        #expect(parsed.timeOfDay == nil)
        #expect(parsed.note == "standup 1115")
    }

    @Test("An unparseable time stays in the note")
    func rejectedTimeIsNote() {
        let parsed = InputParser.parse("2500 #acme x")
        #expect(parsed.timeOfDay == nil)
        #expect(parsed.note == "2500 x")
    }

    @Test("Empty input")
    func empty() {
        #expect(InputParser.parse("").isEmpty)
        #expect(InputParser.parse("   ").isEmpty)
    }
}

@Suite("InputParser.timeOfDay")
struct InputParserTimeTests {
    @Test("Accepted forms", arguments: [
        ("1115", 675), ("11:15", 675),
        ("915", 555), ("9:05", 545),
        ("115", 75), ("0000", 0), ("2359", 1439),
    ])
    func accepted(token: String, minutes: Int) {
        #expect(InputParser.timeOfDay(token) == minutes)
    }

    @Test("Rejected forms", arguments: [
        "2400",   // hour out of range
        "1160",   // minute out of range
        "9:5",    // minute must be two digits
        "11",     // too short
        "12345",  // too long
        "11:15:00",
        "abc",
        "11a5",
    ])
    func rejected(token: String) {
        #expect(InputParser.timeOfDay(token) == nil)
    }
}

@Suite("InputParser autocomplete")
struct InputParserTagTests {
    @Test("A trailing partial tag is offered")
    func trailing() {
        #expect(InputParser.trailingTag("#acm") == "acm")
        #expect(InputParser.trailingTag("auth #ac") == "ac")
    }

    @Test("A completed tag is not offered again")
    func notAfterSpace() {
        #expect(InputParser.trailingTag("#acme ") == nil)
        #expect(InputParser.trailingTag("standup") == nil)
        #expect(InputParser.trailingTag("") == nil)
    }

    @Test("Completion replaces the trailing tag")
    func complete() {
        #expect(InputParser.completeTrailingTag("#ac", with: "acme") == "#acme ")
        #expect(InputParser.completeTrailingTag("1115 #ac", with: "acme") == "1115 #acme ")
    }

    @Test("Completion with no tag is a no-op")
    func completeNoTag() {
        #expect(InputParser.completeTrailingTag("standup", with: "acme") == "standup")
    }
}

//
//  ProjectTests.swift
//  daily_logTests
//

import Foundation
import Testing

@Suite("Project.slug")
struct ProjectSlugTests {
    @Test("Slugs", arguments: [
        ("acme portal!", "acmeportal"),
        ("Acme", "acme"),
        ("acme-portal_1", "acme-portal_1"),
        ("ACME/2", "acme2"),
        ("   ", ""),
        ("", ""),
    ])
    func slug(raw: String, expected: String) {
        #expect(Project.slug(raw) == expected)
    }

    @Test("Non-ASCII letters survive")
    func unicode() {
        #expect(Project.slug("Ärende") == "ärende")
    }
}

@Suite("Project decoding")
struct ProjectDecodingTests {
    @Test("A bare key gets a name and an unarchived flag")
    func defaults() throws {
        let json = Data(#"{"key":"acme"}"#.utf8)
        let project = try JSONIO.decoder.decode(Project.self, from: json)
        #expect(project.name == "acme")
        #expect(project.archived == false)
    }

    @Test("Round trip")
    func roundTrip() throws {
        let project = Project(key: "acme", name: "Acme Corp", archived: true)
        let data = try JSONIO.encoder.encode(project)
        #expect(try JSONIO.decoder.decode(Project.self, from: data) == project)
    }
}

@Suite("Entry coding")
struct EntryCodingTests {
    @Test("Round trip preserves the timestamp to the second")
    func roundTrip() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 7
        components.hour = 9
        components.minute = 30
        components.second = 12
        let at = try #require(Calendar(identifier: .gregorian).date(from: components))

        let entry = Entry(id: "e_TEST", at: at, project: "acme", note: "auth refactor")
        let data = try JSONIO.encoder.encode(entry)
        let decoded = try JSONIO.decoder.decode(Entry.self, from: data)

        #expect(decoded == entry)
    }

    @Test("Fractional-second timestamps are still readable")
    func fractionalSeconds() throws {
        let json = Data(#"{"id":"e_1","at":"2026-08-07T09:30:12.482Z","project":"acme","note":"x"}"#.utf8)
        let entry = try JSONIO.decoder.decode(Entry.self, from: json)
        #expect(entry.project == "acme")
    }

    @Test("Generated ids are distinct and prefixed")
    func ids() {
        let ids = (0..<50).map { _ in Entry.newID() }
        #expect(ids.allSatisfy { $0.hasPrefix("e_") })
        #expect(Set(ids).count == ids.count)
    }
}

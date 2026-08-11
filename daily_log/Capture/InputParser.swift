//
//  InputParser.swift
//  daily_log
//
//  `1115 #acme design sync` -> 11:15, project acme, note "design sync".
//

import Foundation

struct ParsedInput: Equatable {
    /// Minutes past midnight, when the input carried a time prefix.
    var timeOfDay: Int?
    /// The `#tag`, slugged. nil means "inherit the previous entry's project".
    var projectKey: String?
    var note: String

    var isEmpty: Bool { timeOfDay == nil && projectKey == nil && note.isEmpty }
}

enum InputParser {
    static func parse(_ raw: String) -> ParsedInput {
        var tokens = raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var result = ParsedInput(timeOfDay: nil, projectKey: nil, note: "")

        if let first = tokens.first, let minutes = timeOfDay(first) {
            result.timeOfDay = minutes
            tokens.removeFirst()
        }

        if let idx = tokens.firstIndex(where: { $0.hasPrefix("#") && $0.count > 1 }) {
            result.projectKey = Project.slug(String(tokens[idx].dropFirst()))
            tokens.remove(at: idx)
        }

        result.note = tokens.joined(separator: " ")
        return result
    }

    /// Accepts `1115`, `915`, `11:15`, `9:05`. Rejects anything out of range.
    static func timeOfDay(_ token: String) -> Int? {
        let hour: Int, minute: Int

        if token.contains(":") {
            let parts = token.split(separator: ":")
            guard parts.count == 2,
                  let h = Int(parts[0]), let m = Int(parts[1]),
                  parts[1].count == 2 else { return nil }
            (hour, minute) = (h, m)
        } else {
            guard token.allSatisfy(\.isNumber), token.count == 3 || token.count == 4,
                  let value = Int(token) else { return nil }
            (hour, minute) = (value / 100, value % 100)
        }

        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// The `#tag` currently under the cursor-ish (i.e. the trailing one), for autocomplete.
    static func trailingTag(_ raw: String) -> String? {
        guard let last = raw.split(separator: " ").last, last.hasPrefix("#"),
              !raw.hasSuffix(" ") else { return nil }
        return Project.slug(String(last.dropFirst()))
    }

    /// Replaces the trailing `#partial` with `#key `.
    static func completeTrailingTag(_ raw: String, with key: String) -> String {
        var tokens = raw.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard let idx = tokens.lastIndex(where: { $0.hasPrefix("#") }) else { return raw }
        tokens[idx] = "#\(key)"
        return tokens.joined(separator: " ") + " "
    }
}

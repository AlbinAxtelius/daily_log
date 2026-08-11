//
//  Store.swift
//  daily_log
//
//  Owns entries, projects and settings; persists each as readable JSON.
//  Durations are never stored — they are derived here.
//

import Foundation
import Observation

@Observable
final class Store {
    static let shared = Store()

    private(set) var entries: [Entry] = []      // always sorted by `at`
    private(set) var projects: [Project] = []

    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            saveSettings()
            if settings.dataPath != oldValue.dataPath { reloadData() }
            onSettingsChanged?()
        }
    }

    /// Fired whenever an entry is logged — the nudge timer listens.
    var onEntryLogged: (() -> Void)?
    var onSettingsChanged: (() -> Void)?

    private let calendar = Calendar.current

    init() {
        settings = Store.loadSettings()
        reloadData()
    }

    // MARK: - Locations

    /// settings.json always lives here, otherwise a custom data path could never be found again.
    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("daily", isDirectory: true)
    }

    var dataDirectory: URL {
        if let path = settings.dataPath, !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return Store.defaultDirectory
    }

    private var entriesURL: URL { dataDirectory.appendingPathComponent("entries.json") }
    private var projectsURL: URL { dataDirectory.appendingPathComponent("projects.json") }
    private static var settingsURL: URL { defaultDirectory.appendingPathComponent("settings.json") }

    // MARK: - Persistence

    private static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONIO.decoder.decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        ensureDirectory(url.deletingLastPathComponent())
        guard let data = try? JSONIO.encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func loadSettings() -> Settings {
        load(Settings.self, from: settingsURL) ?? Settings()
    }

    private func reloadData() {
        entries = (Store.load([Entry].self, from: entriesURL) ?? []).sorted { $0.at < $1.at }
        projects = Store.load([Project].self, from: projectsURL) ?? []
    }

    private func saveEntries() { Store.write(entries, to: entriesURL) }
    private func saveProjects() { Store.write(projects, to: projectsURL) }
    private func saveSettings() { Store.write(settings, to: Store.settingsURL) }

    // MARK: - Days

    /// The logical day a timestamp belongs to, keyed by the midnight of that day.
    /// With a 04:00 day start, 00:40 Saturday belongs to Friday.
    func logicalDay(of date: Date) -> Date {
        let shifted = date.addingTimeInterval(-Double(settings.dayStartHour) * 3600)
        return calendar.startOfDay(for: shifted)
    }

    var today: Date { logicalDay(of: Date()) }

    /// Monday-first week containing `day`, as logical-day keys.
    /// Normalised to midnight so the results can be used as `entries(onDay:)` keys.
    func week(containing day: Date) -> [Date] {
        let base = calendar.startOfDay(for: day)
        let weekday = calendar.component(.weekday, from: base)
        let offsetFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offsetFromMonday, to: base) else {
            return [base]
        }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monday).map(calendar.startOfDay(for:))
        }
    }

    func weekNumber(of day: Date) -> Int {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = calendar.timeZone
        return cal.component(.weekOfYear, from: day)
    }

    func shiftWeek(_ day: Date, by weeks: Int) -> Date {
        shiftDay(day, by: weeks * 7)
    }

    func shiftDay(_ day: Date, by days: Int) -> Date {
        // startOfDay again so DST transitions can't drift the key off midnight.
        calendar.date(byAdding: .day, value: days, to: day)
            .map(calendar.startOfDay(for:)) ?? day
    }

    /// Turns a logical day plus minutes-past-midnight into a real timestamp,
    /// respecting the day start: 01:00 on a 04:00-start day is the *next* calendar morning.
    func timestamp(onDay day: Date, minutesOfDay minutes: Int) -> Date {
        let base = minutes < settings.dayStartHour * 60
            ? calendar.date(byAdding: .day, value: 1, to: day) ?? day
            : day
        return calendar.startOfDay(for: base).addingTimeInterval(Double(minutes) * 60)
    }

    func entries(onDay day: Date) -> [Entry] {
        entries.filter { logicalDay(of: $0.at) == day }
    }

    // MARK: - Derived durations

    /// Entries of a day paired with their derived minutes.
    /// `min(next − this, cap)`; the last entry of the day gets the cap.
    /// Gaps are never invented — a day simply may not add up to eight hours.
    func timeline(onDay day: Date) -> [(entry: Entry, minutes: Double)] {
        let dayEntries = entries(onDay: day)
        let cap = Double(settings.capMinutes)
        return dayEntries.enumerated().map { index, entry in
            guard index + 1 < dayEntries.count else { return (entry, cap) }
            let gap = dayEntries[index + 1].at.timeIntervalSince(entry.at) / 60
            return (entry, max(0, min(gap, cap)))
        }
    }

    static func roundHours(minutes: Double) -> Double {
        ((minutes / 60) * 4).rounded() / 4
    }

    /// Rounded hours per project key for a day, biggest first.
    func projectHours(onDay day: Date) -> [(key: String, hours: Double)] {
        var totals: [String: Double] = [:]
        for item in timeline(onDay: day) {
            totals[item.entry.project, default: 0] += item.minutes
        }
        return totals
            .map { (key: $0.key, hours: Store.roundHours(minutes: $0.value)) }
            .filter { $0.hours > 0 }
            .sorted { $0.hours == $1.hours ? $0.key < $1.key : $0.hours > $1.hours }
    }

    func totalHours(onDay day: Date) -> Double {
        projectHours(onDay: day).reduce(0) { $0 + $1.hours }
    }

    /// Week grid: rounded daily values, so the columns actually add up to the totals row.
    func weekGrid(containing day: Date) -> (days: [Date], keys: [String], hours: [Date: [String: Double]]) {
        let days = week(containing: day)
        var grid: [Date: [String: Double]] = [:]
        var keys: [String] = []
        for d in days {
            var row: [String: Double] = [:]
            for item in projectHours(onDay: d) {
                row[item.key] = item.hours
                if !keys.contains(item.key) { keys.append(item.key) }
            }
            grid[d] = row
        }
        let totals = keys.map { key in (key, days.reduce(0.0) { $0 + (grid[$1]?[key] ?? 0) }) }
        keys = totals.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }.map(\.0)
        return (days, keys, grid)
    }

    // MARK: - Entries

    var lastEntry: Entry? { entries.last }

    /// The project a bare note would inherit — the previous entry's, across day boundaries.
    func stickyProject(before date: Date = Date()) -> String? {
        entries.last { $0.at <= date }?.project ?? entries.last?.project
    }

    @discardableResult
    func log(project key: String, note: String, at date: Date = Date()) -> Entry {
        ensureProject(key)
        let entry = Entry(at: date, project: key, note: note)
        insert(entry)
        onEntryLogged?()
        return entry
    }

    private func insert(_ entry: Entry) {
        entries.append(entry)
        entries.sort { $0.at < $1.at }
        saveEntries()
    }

    func update(_ entry: Entry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        ensureProject(entry.project)
        entries[idx] = entry
        entries.sort { $0.at < $1.at }
        saveEntries()
    }

    func delete(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    // MARK: - Projects

    func project(_ key: String) -> Project? {
        projects.first { $0.key == key }
    }

    func displayName(_ key: String) -> String {
        project(key)?.name ?? key
    }

    func knows(_ key: String) -> Bool {
        projects.contains { $0.key == key }
    }

    var activeProjects: [Project] {
        projects.filter { !$0.archived }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Projects matching a partial tag, most-recently-used first.
    func suggestions(for partial: String, limit: Int = 5) -> [Project] {
        let recency = recentProjectKeys()
        return activeProjects
            .filter { partial.isEmpty || $0.key.hasPrefix(partial) || $0.name.lowercased().contains(partial) }
            .sorted { a, b in
                let ai = recency.firstIndex(of: a.key) ?? Int.max
                let bi = recency.firstIndex(of: b.key) ?? Int.max
                return ai == bi ? a.key < b.key : ai < bi
            }
            .prefix(limit)
            .map { $0 }
    }

    private func recentProjectKeys() -> [String] {
        var seen: [String] = []
        for entry in entries.reversed() where !seen.contains(entry.project) {
            seen.append(entry.project)
        }
        return seen
    }

    @discardableResult
    func addProject(key: String, name: String? = nil) -> Project {
        if let existing = project(key) { return existing }
        let project = Project(key: key, name: name)
        projects.append(project)
        saveProjects()
        return project
    }

    private func ensureProject(_ key: String) {
        guard !key.isEmpty, !knows(key) else { return }
        addProject(key: key)
    }

    /// Renaming may change the key, which rewrites every entry that used it.
    func renameProject(_ key: String, toKey newKey: String, name: String) {
        guard let idx = projects.firstIndex(where: { $0.key == key }) else { return }
        let target = Project.slug(newKey.isEmpty ? key : newKey)

        if target != key, let clashIdx = projects.firstIndex(where: { $0.key == target }) {
            // Merging into an existing project: keep the survivor, drop the duplicate.
            projects[clashIdx].name = name
            projects.remove(at: idx)
        } else {
            projects[idx].key = target
            projects[idx].name = name
        }

        if target != key {
            for i in entries.indices where entries[i].project == key {
                entries[i].project = target
            }
            saveEntries()
        }
        saveProjects()
    }

    func setArchived(_ archived: Bool, for key: String) {
        guard let idx = projects.firstIndex(where: { $0.key == key }) else { return }
        projects[idx].archived = archived
        saveProjects()
    }

    func deleteProject(_ key: String) {
        projects.removeAll { $0.key == key }
        saveProjects()
    }

    func entryCount(for key: String) -> Int {
        entries.count { $0.project == key }
    }

    // MARK: - Summaries

    /// The end-of-day notification body: "acme ~5.5h · internal ~1h".
    func rollupLine(onDay day: Date) -> String {
        let parts = projectHours(onDay: day).map { "\(displayName($0.key)) \(Fmt.approxHours($0.hours))" }
        return parts.isEmpty ? "Nothing logged." : parts.joined(separator: " · ")
    }

    /// The quoted note list under the rollup.
    func noteLine(onDay day: Date, limit: Int = 5) -> String {
        var notes: [String] = []
        for entry in entries(onDay: day) where !entry.note.isEmpty {
            if !notes.contains(entry.note) { notes.append(entry.note) }
        }
        guard !notes.isEmpty else { return "" }
        let shown = notes.prefix(limit).joined(separator: ", ")
        return notes.count > limit ? "\(shown), …" : shown
    }
}

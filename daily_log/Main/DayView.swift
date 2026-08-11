//
//  DayView.swift
//  daily_log
//
//  Project rollup by default; unfold a project to edit its entries in place.
//

import SwiftUI

struct DayView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var navigation

    let day: Date

    @State private var unfolded: Set<String> = []
    @State private var editing: Entry?

    var body: some View {
        let rollup = store.projectHours(onDay: day)
        let total = store.totalHours(onDay: day)

        VStack(alignment: .leading, spacing: 0) {
            header(rollup: rollup, total: total)

            if rollup.isEmpty {
                EmptyPane(
                    symbol: "tray",
                    title: "Nothing logged.",
                    message: "Entries you capture on this day show up here, grouped by project."
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rollup, id: \.key) { item in
                            ProjectCard(
                                day: day,
                                projectKey: item.key,
                                hours: item.hours,
                                share: total > 0 ? item.hours / total : 0,
                                isOpen: unfolded.contains(item.key),
                                toggle: { toggle(item.key) },
                                edit: { editing = $0 }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(item: $editing) { entry in
            EntryEditor(entry: entry, day: day)
                .environment(store)
        }
    }

    private func header(rollup: [(key: String, hours: Double)], total: Double) -> some View {
        PageHeader(
            title: Fmt.dayLong.string(from: day),
            subtitle: total > 0
                ? "\(Fmt.dayFull.string(from: day)) · \(Fmt.approxHours(total))"
                : Fmt.dayFull.string(from: day)
        ) {
            Button { navigation.route = .week(day) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()
            .help("Back to the week")
        } trailing: {
            HStack(spacing: 10) {
                if !rollup.isEmpty {
                    StackedBar(segments: rollup.map { (key: $0.key, hours: $0.hours) },
                               scale: max(total, 0.01), height: 5)
                        .frame(width: 120)
                }

                HStack(spacing: 6) {
                    Button { navigation.route = .day(store.shiftDay(day, by: -1)) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Previous day")

                    Button { navigation.route = .day(store.shiftDay(day, by: 1)) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help("Next day")
                }
                .controlSize(.small)
            }
        }
    }

    private func toggle(_ key: String) {
        withAnimation(.easeOut(duration: 0.14)) {
            if unfolded.contains(key) { unfolded.remove(key) } else { unfolded.insert(key) }
        }
    }
}

// MARK: - One project's share of the day

private struct ProjectCard: View {
    @Environment(Store.self) private var store

    let day: Date
    let projectKey: String
    let hours: Double
    let share: Double
    let isOpen: Bool
    let toggle: () -> Void
    let edit: (Entry) -> Void

    private var rows: [(entry: Entry, minutes: Double)] {
        store.timeline(onDay: day).filter { $0.entry.project == projectKey }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 9) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 10)

                    ProjectDot(key: projectKey, size: 8)

                    Text(store.displayName(projectKey))
                        .font(.system(size: 13, weight: .semibold))

                    Spacer(minLength: 12)

                    Text(Fmt.approxHours(hours))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 9)

            ShareBar(key: projectKey, fraction: share)
                .padding(.horizontal, 14)

            if isOpen {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(rows, id: \.entry.id) { row in
                        EntryRow(entry: row.entry, minutes: row.minutes, edit: edit)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 8)
            } else {
                let notes = rows.map(\.entry.note).filter { !$0.isEmpty }
                if !notes.isEmpty {
                    Text(notes.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 9)
                        .padding(.bottom, 12)
                } else {
                    Color.clear.frame(height: 12)
                }
            }
        }
        .card()
    }
}

private struct EntryRow: View {
    @Environment(Store.self) private var store

    let entry: Entry
    let minutes: Double
    let edit: (Entry) -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(Fmt.clock.string(from: entry.at))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Text(Fmt.duration(minutes: minutes))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 46, alignment: .leading)

            Text(entry.note.isEmpty ? "—" : entry.note)
                .font(.system(size: 12))
                .foregroundStyle(entry.note.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .lineLimit(1)

            Spacer(minLength: 8)

            // Actions stay out of the way until you go looking for them.
            HStack(spacing: 2) {
                Button { edit(entry) } label: {
                    Image(systemName: "pencil")
                }
                .help("Edit")

                Button { store.delete(entry) } label: {
                    Image(systemName: "trash")
                }
                .help("Delete")
            }
            .buttonStyle(.accessoryBar)
            .controlSize(.small)
            .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.05 : 0))
        )
        .onHover { hovering = $0 }
    }
}

// MARK: - Editor

struct EntryEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entry: Entry
    let day: Date

    @State private var timeText = ""
    @State private var projectKey = ""
    @State private var note = ""
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit entry")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Time")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("HH:mm", text: $timeText)
                        .frame(width: 90)
                }
                GridRow {
                    Text("Project").foregroundStyle(.secondary)
                    Picker("", selection: $projectKey) {
                        ForEach(pickerProjects, id: \.key) { project in
                            Text(project.name).tag(project.key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
                GridRow {
                    Text("Note").foregroundStyle(.secondary)
                    TextField("what you did", text: $note)
                        .frame(width: 280)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 20)

            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            Divider()
                .padding(.top, 18)

            HStack {
                Button("Delete", role: .destructive) {
                    store.delete(entry)
                    dismiss()
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 430)
        .onAppear {
            timeText = Fmt.clock.string(from: entry.at)
            projectKey = entry.project
            note = entry.note
        }
    }

    /// Archived projects still show if this entry belongs to one.
    private var pickerProjects: [Project] {
        var list = store.activeProjects
        if !list.contains(where: { $0.key == entry.project }),
           let own = store.project(entry.project) {
            list.insert(own, at: 0)
        }
        return list
    }

    private func save() {
        guard let minutes = InputParser.timeOfDay(timeText) else {
            problem = "Time must look like 09:30 or 0930."
            return
        }
        var updated = entry
        updated.at = store.timestamp(onDay: day, minutesOfDay: minutes)
        updated.project = projectKey
        updated.note = note
        store.update(updated)
        dismiss()
    }
}

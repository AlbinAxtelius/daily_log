//
//  CaptureBarView.swift
//  daily_log
//

import SwiftUI

struct CaptureBarView: View {
    @Environment(Store.self) private var store

    let onLog: () -> Void
    let onDismiss: () -> Void
    let onOpenWindow: () -> Void
    let onHeight: (CGFloat) -> Void

    @State private var text = ""
    @State private var expanded = false
    /// An unrecognised tag waiting for "create project X?" confirmation.
    @State private var pendingProject: String?
    @State private var problem: String?
    @FocusState private var focused: Bool

    private var suggestions: [Project] {
        guard let partial = InputParser.trailingTag(text) else { return [] }
        return store.suggestions(for: partial)
    }

    private var today: Date { store.today }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            input

            if let pendingProject {
                confirmCreate(pendingProject)
            } else if !suggestions.isEmpty {
                suggestionRow
            } else if let problem {
                hint(problem, tone: .orange)
            }

            if expanded {
                Divider().opacity(0.6)
                todayList
            }

            Divider().opacity(0.6)
            footer
        }
        .frame(width: 620, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        .onKeyPress(.downArrow) {
            expanded = true
            return .handled
        }
        .onKeyPress(.escape) {
            if pendingProject != nil { pendingProject = nil; return .handled }
            onDismiss()
            return .handled
        }
        .onKeyPress(.tab) {
            guard let first = suggestions.first else { return .ignored }
            text = InputParser.completeTrailingTag(text, with: first.key)
            return .handled
        }
        .onChange(of: text) { _, _ in
            pendingProject = nil
            problem = nil
            if !text.isEmpty { expanded = true }
        }
        .onAppear {
            DispatchQueue.main.async { focused = true }
        }
    }

    // MARK: - Input

    private var input: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            TextField("What are you doing?", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .regular))
                .focused($focused)
                .onSubmit(submit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Accessories

    private var suggestionRow: some View {
        HStack(spacing: 6) {
            ForEach(suggestions) { project in
                Button {
                    text = InputParser.completeTrailingTag(text, with: project.key)
                    focused = true
                } label: {
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("⇥ complete")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func confirmCreate(_ key: String) -> some View {
        hint("create project “\(key)”?  ↩ yes · esc no", tone: .accentColor)
    }

    private func hint(_ message: String, tone: Color) -> some View {
        HStack {
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tone)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Today

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("today")
                Text("·")
                Text(Fmt.approxHours(store.totalHours(onDay: today)))
                if let top = store.projectHours(onDay: today).first {
                    Text("·")
                    Text(store.displayName(top.key))
                }
                Spacer()
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            let entries = store.entries(onDay: today)
            if entries.isEmpty {
                Text("Nothing logged yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(entries) { entry in
                            HStack(spacing: 10) {
                                Text(Fmt.clock.string(from: entry.at))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(entry.note.isEmpty ? store.displayName(entry.project) : entry.note)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Text(store.displayName(entry.project))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 190)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("↩ log")
            Text("·")
            Text("⌘↩ window")
            Text("·")
            Text("esc")
            Spacer()
            if !expanded {
                Text("↓ today")
                Text("·")
            }
            // A step quieter than the key hints — it is reference, not guidance.
            Text(AppInfo.short)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    // MARK: - Logging

    private func submit() {
        let parsed = InputParser.parse(text)
        guard !parsed.isEmpty else {
            onDismiss()
            return
        }

        guard let key = resolveProject(parsed) else { return }

        let at = parsed.timeOfDay.map { store.timestamp(onDay: today, minutesOfDay: $0) } ?? Date()
        store.log(project: key, note: parsed.note, at: at)

        text = ""
        pendingProject = nil
        onLog()
    }

    /// Returns nil when the caller should wait — either for a create-project
    /// confirmation or for the user to supply a project at all.
    private func resolveProject(_ parsed: ParsedInput) -> String? {
        guard let key = parsed.projectKey else {
            guard let sticky = store.stickyProject() else {
                problem = "Add a #project — there's nothing to inherit yet."
                return nil
            }
            return sticky
        }

        if store.knows(key) { return key }

        // Typo drift gets caught right here.
        guard pendingProject == key else {
            pendingProject = key
            return nil
        }
        store.addProject(key: key)
        return key
    }
}

//
//  SettingsView.swift
//  daily_log
//

import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(Store.self) private var store

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var dataPathDraft = ""

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Settings", subtitle: "Capture, nudges and how totals are derived") {
                EmptyView()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Capture", symbol: "keyboard") {
                        labelled("Hotkey") {
                            HotKeyField(
                                keyCode: $store.settings.hotKeyCode,
                                modifiers: $store.settings.hotKeyModifiers
                            )
                        }
                        rowDivider
                        labelled("Launch at login") {
                            Toggle("", isOn: $launchAtLogin)
                                .labelsHidden()
                                .controlSize(.small)
                                .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
                        }
                    }

                    section("Work hours", symbol: "clock") {
                        labelled("Days") {
                            HStack(spacing: 4) {
                                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                                    let weekday = index + 1
                                    Toggle(symbol, isOn: dayBinding(weekday))
                                        .toggleStyle(.button)
                                        .controlSize(.small)
                                }
                            }
                        }
                        rowDivider
                        labelled("From") {
                            MinutesField(minutes: $store.settings.workStartMinutes)
                        }
                        rowDivider
                        labelled("To") {
                            MinutesField(minutes: $store.settings.workEndMinutes)
                        }
                    }

                    section("Nudges", symbol: "bell") {
                        labelled("Nudge after silence") {
                            Stepper(
                                "\(store.settings.silenceMinutes) min",
                                value: $store.settings.silenceMinutes, in: 10...480, step: 5
                            )
                            .frame(width: 150)
                        }
                        rowDivider
                        labelled("Remind again after") {
                            Stepper(
                                store.settings.repeatMinutes == 0
                                    ? "Off" : "\(store.settings.repeatMinutes) min",
                                value: $store.settings.repeatMinutes, in: 0...120, step: 5
                            )
                            .frame(width: 150)
                        }
                        rowDivider
                        labelled("End-of-day summary") {
                            MinutesField(minutes: $store.settings.endOfDayMinutes)
                        }
                        rowDivider
                        NudgeTestRow()
                        footnote("Test notifications are the real thing, actions included — “Same as before” will log an entry.")
                    }

                    section("Derivation", symbol: "function") {
                        labelled("Duration cap") {
                            Stepper(
                                "\(store.settings.capMinutes) min",
                                value: $store.settings.capMinutes, in: 15...480, step: 15
                            )
                            .frame(width: 150)
                        }
                        rowDivider
                        labelled("Day starts at") {
                            Stepper(
                                String(format: "%02d:00", store.settings.dayStartHour),
                                value: $store.settings.dayStartHour, in: 0...12
                            )
                            .frame(width: 150)
                        }
                        footnote("Rounded to 0.25 h. A 00:40 entry lands on the day that just ended.")
                    }

                    section("Data", symbol: "folder") {
                        labelled("Folder") {
                            HStack(spacing: 6) {
                                TextField("default", text: $dataPathDraft)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 250)
                                    .onSubmit(applyDataPath)
                                Button("Choose…", action: chooseFolder)
                                Button("Reveal") {
                                    NSWorkspace.shared.activateFileViewerSelecting([store.dataDirectory])
                                }
                            }
                            .controlSize(.small)
                        }
                        footnote("entries.json and projects.json live here. settings.json always stays in \(Store.defaultDirectory.path).")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear { dataPathDraft = store.settings.dataPath ?? "" }
    }

    // MARK: - Pieces

    private func section(_ title: String, symbol: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var rowDivider: some View {
        Divider().opacity(0.5).padding(.leading, 14)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 8)
    }

    private func labelled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 150, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var weekdaySymbols: [String] {
        var symbols = Calendar.current.veryShortWeekdaySymbols
        if symbols.count != 7 { symbols = ["S", "M", "T", "W", "T", "F", "S"] }
        return symbols
    }

    private func dayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { store.settings.workDays.contains(weekday) },
            set: { on in
                var days = Set(store.settings.workDays)
                if on { days.insert(weekday) } else { days.remove(weekday) }
                store.settings.workDays = days.sorted()
            }
        )
    }

    // MARK: - Actions

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.dataDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        dataPathDraft = url.path
        applyDataPath()
    }

    private func applyDataPath() {
        let trimmed = dataPathDraft.trimmingCharacters(in: .whitespaces)
        store.settings.dataPath = trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Notification self-test

/// Posts the real nudge and the real summary on demand, and reports why nothing
/// showed up if it didn't. The only way to check notifications short of waiting an hour.
private struct NudgeTestRow: View {
    @State private var diagnostics: NudgeCenter.Diagnostics?
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Test")
                    .font(.system(size: 12))
                    .frame(width: 150, alignment: .leading)

                HStack(spacing: 6) {
                    Button("Send nudge") { send(.silence) }
                    Button("Send summary") { send(.endOfDay) }
                    if let diagnostics, !diagnostics.isHealthy {
                        Button("Open System Settings…", action: openNotificationSettings)
                    }
                }
                .controlSize(.small)

                Spacer(minLength: 0)

                if let diagnostics {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor(diagnostics))
                            .frame(width: 6, height: 6)
                        Text(diagnostics.summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(failed ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .padding(.leading, 162)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .task { await refresh() }
    }

    private func statusColor(_ diagnostics: NudgeCenter.Diagnostics) -> Color {
        if diagnostics.isHealthy { return .green }
        return diagnostics.authorization == .denied || !diagnostics.isBundled ? .red : .orange
    }

    private func send(_ kind: NudgeCenter.TestKind) {
        Task {
            guard let center = NudgeCenter.current else {
                message = "Nudge centre isn't running."
                failed = true
                return
            }
            switch await center.sendTest(kind) {
            case .delivered(let text):
                message = text
                failed = false
            case .blocked(let reason):
                message = reason
                failed = true
            }
            await refresh()
        }
    }

    private func refresh() async {
        diagnostics = await NudgeCenter.current?.diagnostics()
    }

    private func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) { return }
        }
    }
}

// MARK: - Minutes-past-midnight field

struct MinutesField: View {
    @Binding var minutes: Int
    @State private var text = ""

    var body: some View {
        TextField("HH:mm", text: $text)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .frame(width: 74)
            .font(.system(size: 12, design: .monospaced))
            .onAppear { text = Fmt.minutesOfDay(minutes) }
            .onChange(of: minutes) { _, new in text = Fmt.minutesOfDay(new) }
            .onSubmit(commit)
            .onExitCommand(perform: reset)
    }

    private func commit() {
        if let parsed = InputParser.timeOfDay(text) {
            minutes = parsed
        }
        text = Fmt.minutesOfDay(minutes)
    }

    private func reset() { text = Fmt.minutesOfDay(minutes) }
}

// MARK: - Hotkey recorder

struct HotKeyField: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    @State private var recording = false

    var body: some View {
        Button {
            recording.toggle()
        } label: {
            Text(recording ? "Press a combination…" : HotKeyDisplay.string(keyCode: keyCode, modifiers: modifiers))
                .font(.system(size: 12, weight: .medium))
                .frame(width: 170)
                .padding(.vertical, 3)
                .background(recording ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.quaternary),
                            in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .background(
            KeyCatcher(recording: $recording) { code, flags in
                keyCode = code
                modifiers = flags
                recording = false
            }
        )
    }
}

/// Grabs one key-down while recording, without touching the global event stream.
private struct KeyCatcher: NSViewRepresentable {
    @Binding var recording: Bool
    let onCapture: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onCapture = onCapture
        view.isRecording = recording
        if recording, view.window?.firstResponder !== view {
            view.window?.makeFirstResponder(view)
        }
    }

    final class CatcherView: NSView {
        var onCapture: ((UInt32, UInt32) -> Void)?
        var isRecording = false

        override var acceptsFirstResponder: Bool { isRecording }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            let carbonFlags = HotKeyDisplay.carbonModifiers(from: event.modifierFlags)
            // A bare key would swallow normal typing everywhere.
            guard carbonFlags != 0 else { NSSound.beep(); return }
            isRecording = false
            onCapture?(UInt32(event.keyCode), carbonFlags)
        }
    }
}

//
//  MainWindow.swift
//  daily_log
//
//  Week view (primary), day view, projects and settings. Closing it never quits.
//

import AppKit
import Observation
import SwiftUI

enum Route: Hashable {
    case week(Date)
    case day(Date)
    case projects
    case settings
}

@Observable
final class Navigation {
    var route: Route

    init(route: Route) {
        self.route = route
    }
}

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private let store: Store
    private weak var coordinator: (any AppCoordinator)?
    private let navigation: Navigation
    private var window: NSWindow?

    init(store: Store, coordinator: (any AppCoordinator)? = nil) {
        self.store = store
        self.coordinator = coordinator
        self.navigation = Navigation(route: .week(store.today))
        super.init()
    }

    func show(day: Date?) {
        if let day {
            navigation.route = .week(day)
        }
        makeWindowIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func showSettings() {
        navigation.route = .settings
        makeWindowIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowIfNeeded() {
        guard window == nil else { return }

        let root = MainWindowView(onCapture: { [weak self] in self?.coordinator?.showCapture() })
            .environment(store)
            .environment(navigation)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Daily"
        // The nav bar below doubles as the titlebar, so the real one gets out of the way.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: root)
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("DailyMainWindow")
        self.window = window
    }

    // Closing hides; the agent keeps running.
    func windowWillClose(_ notification: Notification) {}
}

// MARK: - Root

struct MainWindowView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var navigation

    var onCapture: () -> Void = {}

    /// Clears the traffic lights, which the transparent titlebar leaves in place.
    private static let trafficLightInset: CGFloat = 78

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.window)
        }
        .frame(minWidth: 680, minHeight: 460)
    }

    private var navBar: some View {
        HStack(spacing: 12) {
            Picker("", selection: sectionBinding) {
                Text("Week").tag(Section.week)
                Text("Projects").tag(Section.projects)
                Text("Settings").tag(Section.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 240)

            Spacer(minLength: 12)

            Button(action: onCapture) {
                Label("Log", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .controlSize(.small)
            .help("Open the capture bar (\(HotKeyDisplay.string(keyCode: store.settings.hotKeyCode, modifiers: store.settings.hotKeyModifiers)))")
        }
        .padding(.leading, Self.trafficLightInset)
        .padding(.trailing, 14)
        .frame(height: 52)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.route {
        case .week(let day):
            WeekView(anchor: day)
        case .day(let day):
            DayView(day: day)
        case .projects:
            ProjectsView()
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Section switching

    private enum Section: Hashable { case week, projects, settings }

    private var sectionBinding: Binding<Section> {
        Binding(
            get: {
                switch navigation.route {
                case .week, .day: .week
                case .projects: .projects
                case .settings: .settings
                }
            },
            set: { section in
                switch section {
                case .week:
                    if case .week = navigation.route { return }
                    if case .day(let day) = navigation.route {
                        navigation.route = .week(day)
                    } else {
                        navigation.route = .week(store.today)
                    }
                case .projects: navigation.route = .projects
                case .settings: navigation.route = .settings
                }
            }
        )
    }
}

// MARK: - Shared page chrome

/// Every page opens the same way: a title block on the left, controls on the right.
struct PageHeader<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            leading()

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }
}

extension PageHeader where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

/// Shown when a surface has nothing to say yet.
struct EmptyPane: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
}

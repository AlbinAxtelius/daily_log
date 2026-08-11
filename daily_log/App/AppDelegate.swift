//
//  AppDelegate.swift
//  daily_log
//
//  Menu-bar agent shell: status item, global hotkey, notifications, windows.
//

import AppKit
import ServiceManagement
import UserNotifications

@MainActor
protocol AppCoordinator: AnyObject {
    func showCapture()
    func showMainWindow(day: Date?)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, AppCoordinator {
    private let store = Store.shared
    private var statusItem: NSStatusItem?

    private lazy var capture = CapturePanelController(store: store, coordinator: self)
    private lazy var mainWindow = MainWindowController(store: store, coordinator: self)
    private lazy var nudges = NudgeCenter(store: store, coordinator: self)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setUpStatusItem()
        applyHotKey()

        // Touch the nudge centre so categories register before anything is scheduled.
        nudges.scheduleAll()

        store.onEntryLogged = { [weak self] in self?.nudges.scheduleSilenceNudge() }
        store.onSettingsChanged = { [weak self] in
            self?.applyHotKey()
            self?.nudges.scheduleAll()
        }

        runFirstRunConsentIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "text.append", accessibilityDescription: "Daily"
        )
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func statusItemClicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        if isRightClick {
            showMenu()
        } else {
            capture.toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture…", action: #selector(menuCapture), keyEquivalent: "")
        menu.addItem(withTitle: "Open Daily", action: #selector(menuOpen), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(menuSettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Daily", action: #selector(menuQuit), keyEquivalent: "q")
        for item in menu.items { item.target = self }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func menuCapture() { showCapture() }
    @objc private func menuOpen() { showMainWindow(day: store.today) }
    @objc private func menuSettings() { mainWindow.showSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - Hotkey

    private func applyHotKey() {
        HotKeyManager.shared.onFire = { [weak self] in self?.capture.toggle() }
        HotKeyManager.shared.register(
            keyCode: store.settings.hotKeyCode,
            modifiers: store.settings.hotKeyModifiers
        )
    }

    // MARK: - AppCoordinator

    func showCapture() {
        capture.show()
    }

    func showMainWindow(day: Date?) {
        capture.dismiss()
        mainWindow.show(day: day)
    }

    // MARK: - First run

    /// Login item and notification permission are asked for together, once.
    private func runFirstRunConsentIfNeeded() {
        guard !store.settings.didOnboard else {
            nudges.requestAuthorization()
            return
        }

        store.settings.didOnboard = true

        let alert = NSAlert()
        alert.messageText = "Let Daily run in the background?"
        alert.informativeText = """
            Daily lives in the menu bar and nudges you when you've gone quiet for a while.

            It needs to start at login to do that, and permission to post notifications.
            """
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not now")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            try? SMAppService.mainApp.register()
        }
        nudges.requestAuthorization()
    }
}

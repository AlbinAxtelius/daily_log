//
//  CapturePanel.swift
//  daily_log
//
//  The centred, Spotlight-style bar. Both the menu-bar icon and the global
//  hotkey summon this — there is no anchored popover.
//

import AppKit
import SwiftUI

final class CapturePanel: NSPanel {
    var onCancel: (() -> Void)?
    var onCommandReturn: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn, event.modifierFlags.contains(.command) {
            onCommandReturn?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class CapturePanelController {
    private let store: Store
    private weak var coordinator: AppCoordinator?
    private var panel: CapturePanel?
    /// Top edge stays put while the bar grows downward.
    private var anchorTop: CGFloat = 0

    private static let width: CGFloat = 620

    init(store: Store, coordinator: AppCoordinator) {
        self.store = store
        self.coordinator = coordinator
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? dismiss() : show()
    }

    func show() {
        if panel != nil { dismiss() }

        let panel = CapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.onCancel = { [weak self] in self?.dismiss() }
        panel.onCommandReturn = { [weak self] in self?.openMainWindow() }

        let root = CaptureBarView(
            onLog: { [weak self] in self?.dismiss() },
            onDismiss: { [weak self] in self?.dismiss() },
            onOpenWindow: { [weak self] in self?.openMainWindow() },
            onHeight: { [weak self] height in self?.resize(to: height) }
        )
        .environment(store)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: Self.width, height: 64)
        panel.contentView = hosting

        position(panel, height: 64)
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
    }

    private func openMainWindow() {
        dismiss()
        coordinator?.showMainWindow(day: store.today)
    }

    private func position(_ panel: CapturePanel, height: CGFloat) {
        let screen = screenUnderCursor()
        let frame = screen.visibleFrame
        let x = frame.midX - Self.width / 2
        // Sits high on the screen, Spotlight-style.
        anchorTop = frame.minY + frame.height * 0.78
        panel.setFrame(
            NSRect(x: x, y: anchorTop - height, width: Self.width, height: height),
            display: true
        )
    }

    private func resize(to height: CGFloat) {
        guard let panel, height > 0 else { return }
        let rounded = height.rounded(.up)
        guard abs(panel.frame.height - rounded) > 0.5 else { return }
        panel.setFrame(
            NSRect(x: panel.frame.minX, y: anchorTop - rounded, width: Self.width, height: rounded),
            display: true, animate: false
        )
    }

    private func screenUnderCursor() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}

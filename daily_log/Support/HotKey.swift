//
//  HotKey.swift
//  daily_log
//
//  Carbon RegisterEventHotKey — deliberately *not* a global NSEvent monitor,
//  which would demand Accessibility permission for no benefit.
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onFire: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x44414c59 // 'DALY'

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr { hotKeyRef = ref }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKeyManager.shared.onFire?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}

// MARK: - Display

enum HotKeyDisplay {
    static func string(keyCode: UInt32, modifiers: UInt32) -> String {
        var out = ""
        if modifiers & UInt32(controlKey) != 0 { out += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { out += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { out += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { out += "⌘" }
        return out + keyName(keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var out: UInt32 = 0
        if flags.contains(.control) { out |= UInt32(controlKey) }
        if flags.contains(.option) { out |= UInt32(optionKey) }
        if flags.contains(.shift) { out |= UInt32(shiftKey) }
        if flags.contains(.command) { out |= UInt32(cmdKey) }
        return out
    }

    private static let names: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_Grave: "`",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    static func keyName(_ code: UInt32) -> String {
        names[Int(code)] ?? "key \(code)"
    }
}

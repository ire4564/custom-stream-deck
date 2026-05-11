import Foundation
import AppKit
import Carbon.HIToolbox
import os

/// macOS 전역 단축키 매니저. Carbon RegisterEventHotKey 사용.
/// 한 번에 하나의 단축키만 등록한다(덱 토글용).
final class HotkeyManager {
    static let shared = HotkeyManager()
    private let logger = Logger(subsystem: "com.dohee.streamdec", category: "Hotkey")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    private init() {
        installEventHandler()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)
            DispatchQueue.main.async { manager.handler?() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)
    }

    /// 단축키 등록(또는 교체). nil 이면 기존 단축키 해제.
    func register(_ spec: HotkeySpec?, handler: @escaping () -> Void) {
        unregister()
        self.handler = handler
        guard let spec else { return }
        let modifiers = carbonModifiers(from: NSEvent.ModifierFlags(rawValue: spec.modifierFlags))
        let hotKeyID = EventHotKeyID(signature: OSType(0x53444B31), id: 1) // "SDK1"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(spec.keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            hotKeyRef = ref
            logger.info("Hotkey registered: \(spec.displayString, privacy: .public)")
        } else {
            logger.error("Hotkey register failed status=\(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - Helpers

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    /// NSEvent → HotkeySpec 변환 (캡처 UI 에서 사용).
    static func makeSpec(from event: NSEvent) -> HotkeySpec? {
        let keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty else { return nil } // 모디파이어 없는 단축키는 금지
        let display = displayString(keyCode: keyCode, modifiers: flags)
        return HotkeySpec(keyCode: keyCode, modifierFlags: flags.rawValue, displayString: display)
    }

    static func displayString(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += keyName(forKeyCode: keyCode)
        return s
    }

    private static func keyName(forKeyCode kc: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "⇥", 49: "Space", 50: "`",
            51: "⌫", 53: "⎋",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        return map[kc] ?? "Key#\(kc)"
    }
}

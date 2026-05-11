import AppKit
import SwiftUI

/// 메뉴바 → "단축키 설정…" 으로 여는 작은 윈도우.
/// 패널에서는 .sheet 가 잘 동작하지 않을 수 있어 별도 윈도우로 띄움.
final class HotkeyEditorWindowController: NSWindowController {
    private static var current: HotkeyEditorWindowController?

    static func show() {
        if let c = current {
            c.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: HotkeyEditorView(onClose: {
            current?.close()
            current = nil
        }))
        let window = NSWindow(contentViewController: host)
        window.title = "단축키 설정"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 380, height: 200))
        window.center()
        let c = HotkeyEditorWindowController(window: window)
        current = c
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct HotkeyEditorView: View {
    let onClose: () -> Void
    @State private var capturing = false
    @State private var displayString: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("덱 표시/숨김 전역 단축키")
                .font(.headline)
            Text("아래 영역을 클릭한 뒤, 원하는 단축키 조합(⌘/⌥/⌃/⇧ + 키)을 누르세요.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HotkeyCaptureField(displayString: $displayString, capturing: $capturing) { spec in
                DeckViewModel.shared.setHotkey(spec)
            }
            .frame(height: 44)

            HStack {
                Button("해제") {
                    displayString = ""
                    DeckViewModel.shared.setHotkey(nil)
                }
                Spacer()
                Button("닫기") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            if let spec = DeckViewModel.shared.profile.windowSettings.toggleHotkey {
                displayString = spec.displayString
            }
        }
    }
}

/// NSEvent monitor 기반의 단축키 캡처 영역.
struct HotkeyCaptureField: NSViewRepresentable {
    @Binding var displayString: String
    @Binding var capturing: Bool
    let onCapture: (HotkeySpec) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let v = CaptureView()
        v.onUpdate = { s in
            displayString = s
        }
        v.onCapture = { spec in
            onCapture(spec)
        }
        return v
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.text = displayString.isEmpty ? "여기를 클릭하고 단축키 입력" : displayString
        nsView.needsDisplay = true
    }

    final class CaptureView: NSView {
        var text: String = "여기를 클릭하고 단축키 입력"
        var onUpdate: ((String) -> Void)?
        var onCapture: ((HotkeySpec) -> Void)?
        private var isFocused = false

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            isFocused = true
            needsDisplay = true
        }

        override func becomeFirstResponder() -> Bool {
            isFocused = true
            needsDisplay = true
            return true
        }

        override func resignFirstResponder() -> Bool {
            isFocused = false
            needsDisplay = true
            return true
        }

        override func keyDown(with event: NSEvent) {
            guard let spec = HotkeyManager.makeSpec(from: event) else {
                NSSound.beep()
                return
            }
            text = spec.displayString
            onUpdate?(spec.displayString)
            onCapture?(spec)
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            let bg = NSColor.controlBackgroundColor.cgColor
            let border = isFocused ? NSColor.controlAccentColor : NSColor.separatorColor
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            NSColor(cgColor: bg)?.setFill()
            path.fill()
            border.setStroke()
            path.lineWidth = isFocused ? 2 : 1
            path.stroke()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            let attr = NSAttributedString(string: text, attributes: attrs)
            let size = attr.size()
            attr.draw(at: NSPoint(x: (bounds.width - size.width)/2, y: (bounds.height - size.height)/2))
        }
    }
}

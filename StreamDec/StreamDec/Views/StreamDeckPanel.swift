import AppKit

/// Space 전환·앱 활성화 변동 시에도 자리/표시 상태가 흔들리지 않도록 한 NSPanel 서브클래스.
final class StreamDeckPanel: NSPanel {
    /// nonactivating panel 이므로 main window가 되지 않는다.
    override var canBecomeMain: Bool { false }
    /// 마우스 클릭 시에만 key 가 되도록(메뉴/단축키 입력 시는 key 가 됨).
    override var canBecomeKey: Bool { true }

    /// 사용자가 패널 어디든 클릭하면 우리 앱을 활성화 → macOS 상단 메뉴바가 StreamDec 메뉴로 교체.
    /// nonactivating panel 은 클릭만으로 NSApp 이 활성화되지 않으므로 mouseDown 시점에 명시적으로 처리.
    /// 단, 액션 실행 직후 짧은 윈도우에는 양보(suppress).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            MainActor.assumeIsolated {
                if Date() >= AppDelegate.suppressAutoActivateUntil {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        super.sendEvent(event)
    }
}

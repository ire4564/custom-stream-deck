import AppKit

// SPM executable 진입점. main thread = main actor.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // .regular → 메뉴바(상단)에 앱 메뉴가 표시되도록 한다.
    // (Dock 아이콘은 Info.plist LSUIElement 가 true 이므로 숨겨지지 않음 → false 로 두거나
    //  AppDelegate에서 패널 닫힘 시 .accessory 로 토글한다.)
    app.setActivationPolicy(.regular)
    // run() 은 반환하지 않음.
    app.run()
}

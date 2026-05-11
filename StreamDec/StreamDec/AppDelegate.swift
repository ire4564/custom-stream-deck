import AppKit
import SwiftUI
import Combine
import os

extension Notification.Name {
    static let openProfileManager = Notification.Name("StreamDec.openProfileManager")
    static let openBulkEditor = Notification.Name("StreamDec.openBulkEditor")
}

/// WindowSettings 에서 frame 필드를 뺀 비교용 뷰. 드래그 피드백 루프 방지.
private struct WindowSettingsView: Equatable {
    let alwaysOnTop: Bool
    let opacity: Double
    let clickThrough: Bool
    let locked: Bool
    let toggleHotkey: HotkeySpec?

    init(_ profile: Profile) {
        let s = profile.windowSettings
        self.alwaysOnTop = s.alwaysOnTop
        self.opacity = s.opacity
        self.clickThrough = s.clickThrough
        self.locked = s.locked
        self.toggleHotkey = s.toggleHotkey
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    static let logger = Logger(subsystem: "com.dohee.streamdec", category: "AppDelegate")
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var deckPanel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []
    /// AlwaysOnTop 메뉴 항목 등 갱신 위한 참조.
    private var alwaysOnTopItem: NSMenuItem?
    private var clickThroughItem: NSMenuItem?
    private var lockItem: NSMenuItem?
    private var profileMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        Self.logger.info("StreamDec launched")
        let profile = ProfileStore.shared.bootstrapDefaultIfNeeded()
        Self.logger.info("Bootstrapped profile: \(profile.name, privacy: .public) (\(profile.id.uuidString, privacy: .public))")
        setupMenuBar()
        setupMainMenu()              // 상단 macOS 메뉴바
        setupDeckPanel()
        restoreSavedFrame()
        applyWindowSettings()
        bindToViewModel()
        registerHotkey()
        showDeck()
    }

    /// 창의 닫기 버튼이 없으므로, 마지막 창이 닫혀도 앱이 종료되면 안 된다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x3.square", accessibilityDescription: "StreamDec")
            button.toolTip = "StreamDec"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "덱 보이기/숨기기", action: #selector(toggleDeck), keyEquivalent: "d").target = self

        menu.addItem(.separator())

        alwaysOnTopItem = menu.addItem(withTitle: "항상 위", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem?.target = self

        clickThroughItem = menu.addItem(withTitle: "클릭 통과", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem?.target = self

        lockItem = menu.addItem(withTitle: "위치·크기 잠금", action: #selector(toggleLock), keyEquivalent: "")
        lockItem?.target = self

        let opacityMenu = NSMenu(title: "투명도")
        for v in [100, 80, 60, 40, 20] {
            let mi = NSMenuItem(title: "\(v)%", action: #selector(setOpacityPreset(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = v
            opacityMenu.addItem(mi)
        }
        let opacityRoot = NSMenuItem(title: "투명도", action: nil, keyEquivalent: "")
        opacityRoot.submenu = opacityMenu
        menu.addItem(opacityRoot)

        menu.addItem(.separator())

        let profileRoot = NSMenuItem(title: "프로필", action: nil, keyEquivalent: "")
        let profileMenu = NSMenu(title: "프로필")
        profileMenu.delegate = self
        profileRoot.submenu = profileMenu
        menu.addItem(profileRoot)
        self.profileMenu = profileMenu

        let hk = NSMenuItem(title: "단축키 설정…", action: #selector(openHotkeyEditor), keyEquivalent: ",")
        hk.target = self
        menu.addItem(hk)

        let sec = NSMenuItem(title: "권한 및 보안…", action: #selector(openSecurityWindow), keyEquivalent: "")
        sec.target = self
        menu.addItem(sec)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        updateMenuStates()
    }

    // MARK: - Main Menu (상단 macOS 메뉴바)

    private var mainAlwaysOnTopItem: NSMenuItem?
    private var mainClickThroughItem: NSMenuItem?
    private var mainLockItem: NSMenuItem?
    private var mainEditModeItem: NSMenuItem?

    private func setupMainMenu() {
        let main = NSMenu()

        // 앱 메뉴 (좌측 끝, Bold 표시)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let aboutItem = NSMenuItem(title: "StreamDec 정보", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "서비스", action: nil, keyEquivalent: ""))
        appMenu.addItem(.separator())
        let hideItem = NSMenuItem(title: "StreamDec 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        appMenu.addItem(.separator())
        let quitMain = NSMenuItem(title: "StreamDec 종료", action: #selector(quit), keyEquivalent: "q")
        quitMain.target = self
        appMenu.addItem(quitMain)
        appMenuItem.submenu = appMenu
        main.addItem(appMenuItem)

        // 편집 메뉴
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "편집")
        mainEditModeItem = NSMenuItem(title: "편집 모드", action: #selector(toggleEditMode), keyEquivalent: "e")
        mainEditModeItem?.target = self
        editMenu.addItem(mainEditModeItem!)
        editMenu.addItem(.separator())
        let add = NSMenuItem(title: "버튼 추가", action: #selector(menuAddButton), keyEquivalent: "n"); add.target = self
        let dup = NSMenuItem(title: "선택 복제", action: #selector(menuDuplicate), keyEquivalent: "d")
        dup.keyEquivalentModifierMask = [.command, .shift]; dup.target = self
        let del = NSMenuItem(title: "선택 삭제", action: #selector(menuDelete), keyEquivalent: "\u{0008}"); del.target = self
        let bulk = NSMenuItem(title: "일괄 편집…", action: #selector(menuBulk), keyEquivalent: "b"); bulk.target = self
        // 'z' 는 표준 Undo 키와 충돌하므로 삭제 복구는 단축키 없이 항목으로만 노출.
        let restore = NSMenuItem(title: "삭제 복구", action: #selector(menuRestore), keyEquivalent: ""); restore.target = self
        editMenu.addItem(add); editMenu.addItem(dup); editMenu.addItem(del); editMenu.addItem(bulk); editMenu.addItem(restore)

        // 표준 편집 액션 (TextField 등 first responder 로 라우팅)
        editMenu.addItem(.separator())
        let undo  = NSMenuItem(title: "실행 취소",   action: Selector(("undo:")),      keyEquivalent: "z")
        let redo  = NSMenuItem(title: "다시 실행",   action: Selector(("redo:")),      keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        let cut   = NSMenuItem(title: "잘라내기",    action: #selector(NSText.cut(_:)),       keyEquivalent: "x")
        let copy  = NSMenuItem(title: "복사",        action: #selector(NSText.copy(_:)),      keyEquivalent: "c")
        let paste = NSMenuItem(title: "붙여넣기",    action: #selector(NSText.paste(_:)),     keyEquivalent: "v")
        let selAll = NSMenuItem(title: "모두 선택",  action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        [undo, redo, NSMenuItem.separator(), cut, copy, paste, selAll].forEach {
            // target = nil → first responder 체인으로 라우팅 (텍스트 필드가 자동 처리)
            $0.target = nil
            editMenu.addItem($0)
        }

        editItem.submenu = editMenu
        main.addItem(editItem)

        // 레이아웃 메뉴
        let layoutItem = NSMenuItem()
        let layoutMenu = NSMenu(title: "레이아웃")
        for preset in DeckLayout.Preset.allCases.filter({ $0 != .custom }) {
            let mi = NSMenuItem(title: preset.displayName, action: #selector(menuSetLayout(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = preset.rawValue
            layoutMenu.addItem(mi)
        }
        layoutMenu.addItem(.separator())
        for size in DeckSize.allCases {
            let mi = NSMenuItem(title: "크기: \(size.displayName)", action: #selector(menuSetSize(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = size.rawValue
            layoutMenu.addItem(mi)
        }
        layoutItem.submenu = layoutMenu
        main.addItem(layoutItem)

        // 동작 메뉴
        let behaviorItem = NSMenuItem()
        let behaviorMenu = NSMenu(title: "동작")
        mainAlwaysOnTopItem = NSMenuItem(title: "항상 위", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        mainAlwaysOnTopItem?.target = self
        mainClickThroughItem = NSMenuItem(title: "클릭 통과", action: #selector(toggleClickThrough), keyEquivalent: "")
        mainClickThroughItem?.target = self
        mainLockItem = NSMenuItem(title: "위치·크기 잠금", action: #selector(toggleLock), keyEquivalent: "")
        mainLockItem?.target = self
        behaviorMenu.addItem(mainAlwaysOnTopItem!)
        behaviorMenu.addItem(mainClickThroughItem!)
        behaviorMenu.addItem(mainLockItem!)
        behaviorMenu.addItem(.separator())
        let opacitySub = NSMenu(title: "투명도")
        for v in [100, 80, 60, 40, 20] {
            let mi = NSMenuItem(title: "\(v)%", action: #selector(setOpacityPreset(_:)), keyEquivalent: "")
            mi.target = self; mi.tag = v
            opacitySub.addItem(mi)
        }
        let opacityRoot = NSMenuItem(title: "투명도", action: nil, keyEquivalent: "")
        opacityRoot.submenu = opacitySub
        behaviorMenu.addItem(opacityRoot)
        behaviorMenu.addItem(.separator())
        let hk = NSMenuItem(title: "단축키 설정…", action: #selector(openHotkeyEditor), keyEquivalent: ",")
        hk.target = self
        behaviorMenu.addItem(hk)
        let sec = NSMenuItem(title: "권한 및 보안…", action: #selector(openSecurityWindow), keyEquivalent: "")
        sec.target = self
        behaviorMenu.addItem(sec)
        behaviorItem.submenu = behaviorMenu
        main.addItem(behaviorItem)

        // 프로필 메뉴
        let profileItem = NSMenuItem()
        let pMenu = NSMenu(title: "프로필")
        pMenu.delegate = self
        profileItem.submenu = pMenu
        main.addItem(profileItem)
        // 기존 status item 메뉴와 구분하기 위해 별도 변수에 저장하지 않고 delegate 만 공유

        // 창 메뉴
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "창")
        let toggle = NSMenuItem(title: "덱 보이기/숨기기", action: #selector(toggleDeck), keyEquivalent: "d")
        toggle.target = self
        windowMenu.addItem(toggle)
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        updateMenuStates()
    }

    @objc private func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func toggleEditMode() {
        DeckViewModel.shared.toggleEditMode()
    }

    @objc private func menuAddButton() { DeckViewModel.shared.addEmptyButton() }
    @objc private func menuDuplicate() { DeckViewModel.shared.duplicateSelected() }
    @objc private func menuDelete() { DeckViewModel.shared.deleteSelected() }
    @objc private func menuBulk() { NotificationCenter.default.post(name: .openBulkEditor, object: nil) }
    @objc private func menuRestore() { DeckViewModel.shared.restoreLastDeleted() }

    @objc private func menuSetLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = DeckLayout.Preset(rawValue: raw) else { return }
        DeckViewModel.shared.setLayoutPreset(preset)
    }

    @objc private func menuSetSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let size = DeckSize(rawValue: raw) else { return }
        DeckViewModel.shared.setDeckSize(size)
    }

    private func updateMenuStates() {
        let s = DeckViewModel.shared.profile.windowSettings
        alwaysOnTopItem?.state = s.alwaysOnTop ? .on : .off
        clickThroughItem?.state = s.clickThrough ? .on : .off
        lockItem?.state = s.locked ? .on : .off
        mainAlwaysOnTopItem?.state = s.alwaysOnTop ? .on : .off
        mainClickThroughItem?.state = s.clickThrough ? .on : .off
        mainLockItem?.state = s.locked ? .on : .off
        mainEditModeItem?.state = DeckViewModel.shared.isEditing ? .on : .off
    }

    // MARK: - Deck Panel

    private func setupDeckPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 320)
        // closable / titled 제거: 어떤 윈도우 chrome 도 그리지 않도록 borderless 로.
        let panel = StreamDeckPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // 시스템 shadow 는 borderless + clear background 에서 모서리에 검은 dithering 을 만들어
        // 점선처럼 보이게 함. 우리는 SwiftUI .shadow 로 직접 그리므로 끈다.
        panel.hasShadow = false
        // Space 전환 깜빡임 방지: 모든 Space + 전체화면 보조 + 미션컨트롤에서 정지 + 윈도우 사이클 제외
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.delegate = self
        panel.center()

        let host = NSHostingController(rootView: DeckRootView())
        panel.contentViewController = host
        // 외곽선 보이지 않도록 contentView layer 의 border 명시적 제거
        host.view.wantsLayer = true
        host.view.layer?.borderWidth = 0
        host.view.layer?.borderColor = NSColor.clear.cgColor

        deckPanel = panel
    }

    // MARK: - Window settings binding

    private func bindToViewModel() {
        // frame 변경은 드래그/리사이즈에서 발생하므로 sink 에서 다시 setFrame 하지 않는다.
        // 그 외(alwaysOnTop/opacity/clickThrough/locked/toggleHotkey)만 비교.
        DeckViewModel.shared.$profile
            .map(WindowSettingsView.init)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.applyWindowSettings()
                self?.updateMenuStates()
                self?.registerHotkey()
            }
            .store(in: &cancellables)

        // 편집 모드 ↔ 일반 모드 전환에 따라 윈도우 배경 드래그 활성/비활성.
        // 편집 모드일 때는 버튼 드래그(onDrag)가 윈도우 이동에 가로채이지 않도록 false.
        DeckViewModel.shared.$isEditing
            .removeDuplicates()
            .sink { [weak self] editing in
                self?.applyMovableState(editing: editing)
                self?.updateMenuStates()
            }
            .store(in: &cancellables)

        // 사용자가 레이아웃 / DeckSize 를 명시적으로 바꿨을 때만 패널을 그 크기로 재조정.
        DeckViewModel.shared.resizeToLayoutSignal
            .sink { [weak self] _ in
                self?.applyMinSize(forceResize: true)
            }
            .store(in: &cancellables)

        // 초기 1회: minSize 만 적용 (사용자가 마지막에 저장한 frame 은 그대로 유지)
        applyMinSize(forceResize: false)
    }

    /// 현재 레이아웃 / DeckSize 기준으로 패널의 최소 크기를 계산해 적용.
    /// - forceResize == true 면 현재 frame 도 그 minSize 로 setFrame (사용자가 사이즈를 명시적으로 바꾼 시점).
    /// - false 면 minSize 만 갱신 (앱 부팅 시).
    private func applyMinSize(forceResize: Bool) {
        guard let panel = deckPanel else { return }
        let layout = DeckViewModel.shared.profile.layout
        let target = panelSize(for: layout)

        // 최소 크기 적용 (외곽 frame 기준)
        panel.minSize = target

        if forceResize {
            // 사용자가 사이즈 메뉴를 선택한 시점. 패널 좌상단 고정으로 크기만 바꿈.
            var frame = panel.frame
            let topLeft = NSPoint(x: frame.origin.x, y: frame.maxY)
            frame.size = target
            frame.origin.x = topLeft.x
            frame.origin.y = topLeft.y - target.height
            panel.setFrame(frame, display: true, animate: true)
        } else {
            // 부팅 직후 — 현재 frame 이 minSize 보다 작으면 늘려서 minSize 보장.
            var frame = panel.frame
            if frame.width < target.width || frame.height < target.height {
                let topLeft = NSPoint(x: frame.origin.x, y: frame.maxY)
                frame.size.width = max(frame.width, target.width)
                frame.size.height = max(frame.height, target.height)
                frame.origin.x = topLeft.x
                frame.origin.y = topLeft.y - frame.height
                panel.setFrame(frame, display: true, animate: false)
            }
        }
    }

    /// 현재 레이아웃에 맞춘 권장 패널 외곽 크기.
    /// DeckRootView 의 padding(8) + header(약 28) + VStack spacing(12) + 그리드 spacing(8) 을 반영.
    private func panelSize(for layout: DeckLayout) -> CGSize {
        let cell = layout.size.cellSide
        let cols = CGFloat(layout.columns)
        let rows = CGFloat(layout.rows)
        let gridSpacing: CGFloat = 8
        let outerPadding: CGFloat = 8
        let headerHeight: CGFloat = 28
        let vStackSpacing: CGFloat = 12 // header ↔ grid

        let contentWidth = cell * cols + gridSpacing * (cols - 1) + outerPadding * 2
        let contentHeight = cell * rows + gridSpacing * (rows - 1)
            + outerPadding * 2 + headerHeight + vStackSpacing

        // titled 패널이지만 titleVisibility=hidden + fullSizeContentView 라 외곽 = content 크기에 가깝다.
        // 약간의 안전 여유.
        return CGSize(width: ceil(contentWidth), height: ceil(contentHeight) + 4)
    }

    /// 윈도우 배경 드래그 가능 여부 갱신.
    /// - 편집 모드: false (버튼 드래그 우선)
    /// - 일반 모드: locked 가 아닐 때만 true
    private func applyMovableState(editing: Bool) {
        guard let panel = deckPanel else { return }
        let locked = DeckViewModel.shared.profile.windowSettings.locked
        panel.isMovableByWindowBackground = !editing && !locked
    }

    /// frame 을 제외한 표시·동작 옵션만 패널에 적용.
    private func applyWindowSettings() {
        guard let panel = deckPanel else { return }
        let s = DeckViewModel.shared.profile.windowSettings

        panel.level = s.alwaysOnTop ? .floating : .normal
        panel.alphaValue = CGFloat(s.opacity)
        panel.ignoresMouseEvents = s.clickThrough
        panel.isMovable = !s.locked
        panel.styleMask = panel.styleMask.subtracting([.resizable])
        if !s.locked {
            panel.styleMask.insert(.resizable)
        }
        // 윈도우 배경 드래그도 편집모드/잠금 상태에 따라 함께 갱신.
        applyMovableState(editing: DeckViewModel.shared.isEditing)
    }

    /// 부팅 시 1회 frame 복원. 이후에는 호출하지 않음(드래그 피드백 방지).
    private func restoreSavedFrame() {
        guard let panel = deckPanel else { return }
        let s = DeckViewModel.shared.profile.windowSettings
        if let x = s.frameX, let y = s.frameY, let w = s.frameWidth, let h = s.frameHeight {
            let frame = NSRect(x: x, y: y, width: max(200, w), height: max(200, h))
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    private func registerHotkey() {
        let spec = DeckViewModel.shared.profile.windowSettings.toggleHotkey
        HotkeyManager.shared.register(spec) { [weak self] in
            self?.toggleDeck()
        }
    }

    // MARK: - Window delegate

    private var frameSaveWorkItem: DispatchWorkItem?

    func windowDidMove(_ notification: Notification) {
        scheduleFrameSave()
    }

    func windowDidResize(_ notification: Notification) {
        scheduleFrameSave()
    }

    /// 액션 실행 직후 짧은 시간(0.6초) 동안은 자동 activate 를 억제.
    /// 그 사이에 새 앱이 frontmost 로 자리잡을 수 있도록 양보.
    static var suppressAutoActivateUntil: Date = .distantPast

    /// 패널이 클릭되어 key window 가 되면 우리 앱을 활성화 → macOS 상단 메뉴바가 우리 앱 메뉴로 교체됨.
    /// 단, 액션 실행으로 다른 앱에 양보해야 하는 시점에는 호출하지 않는다.
    func windowDidBecomeKey(_ notification: Notification) {
        if Date() < Self.suppressAutoActivateUntil { return }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 드래그가 끝난 뒤(0.25s idle) 한 번만 저장. 매 픽셀 디스크 I/O 방지.
    private func scheduleFrameSave() {
        frameSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let panel = self?.deckPanel else { return }
            DeckViewModel.shared.saveFrame(panel.frame)
        }
        frameSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: - Show / Hide

    private func showDeck() {
        deckPanel?.orderFrontRegardless()
    }

    @objc private func toggleDeck() {
        guard let panel = deckPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Menu actions

    @objc private func toggleAlwaysOnTop() {
        let cur = DeckViewModel.shared.profile.windowSettings.alwaysOnTop
        DeckViewModel.shared.setAlwaysOnTop(!cur)
    }

    @objc private func toggleClickThrough() {
        let cur = DeckViewModel.shared.profile.windowSettings.clickThrough
        DeckViewModel.shared.setClickThrough(!cur)
    }

    @objc private func toggleLock() {
        let cur = DeckViewModel.shared.profile.windowSettings.locked
        DeckViewModel.shared.setLocked(!cur)
    }

    @objc private func setOpacityPreset(_ sender: NSMenuItem) {
        DeckViewModel.shared.setOpacity(Double(sender.tag) / 100.0)
    }

    @objc private func openHotkeyEditor() {
        HotkeyEditorWindowController.show()
    }

    @objc private func openSecurityWindow() {
        SecurityWindowController.show()
    }

    // MARK: - Profile submenu

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        Task { @MainActor in
            rebuildProfileSubmenu(menu)
        }
    }

    private func rebuildProfileSubmenu(_ menu: NSMenu) {
        guard menu === profileMenu else { return }
        menu.removeAllItems()
        let vm = DeckViewModel.shared
        for p in vm.allProfiles {
            let mi = NSMenuItem(title: p.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = p.id.uuidString
            mi.state = (p.id == vm.profile.id) ? .on : .off
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        let manage = NSMenuItem(title: "프로필 관리…", action: #selector(openProfileManager), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String, let id = UUID(uuidString: s) else { return }
        DeckViewModel.shared.switchProfile(to: id)
    }

    @objc private func openProfileManager() {
        // 패널 위에서 시트로 띄우면 잘 동작하므로, 헤더 메뉴와 같은 시트 트리거를 위해 알림 발행.
        NotificationCenter.default.post(name: .openProfileManager, object: nil)
        deckPanel?.orderFrontRegardless()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

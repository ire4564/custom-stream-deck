import Foundation

/// 레이아웃 + 버튼 집합 + 창 표시 옵션을 묶은 하나의 프로필.
struct Profile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var layout: DeckLayout
    var buttons: [DeckButton]
    var windowSettings: WindowSettings
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        layout: DeckLayout = .default,
        buttons: [DeckButton] = [],
        windowSettings: WindowSettings = .default,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.layout = layout
        self.buttons = buttons
        self.windowSettings = windowSettings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 빈 슬롯이 모두 채워진 기본 프로필 생성.
    static func makeDefault(name: String = "Default") -> Profile {
        let layout = DeckLayout.default
        var buttons: [DeckButton] = []
        for r in 0..<layout.rows {
            for c in 0..<layout.columns {
                buttons.append(DeckButton(row: r, column: c))
            }
        }
        return Profile(name: name, layout: layout, buttons: buttons)
    }
}

/// 프로필 단위로 저장되는 창 표시/동작 설정.
struct WindowSettings: Codable, Equatable {
    var alwaysOnTop: Bool
    var opacity: Double            // 0.2 ~ 1.0
    var clickThrough: Bool
    var locked: Bool
    var frameX: Double?
    var frameY: Double?
    var frameWidth: Double?
    var frameHeight: Double?
    /// 전역 단축키 (Carbon hot key code). nil 이면 미지정.
    var toggleHotkey: HotkeySpec?

    static let `default` = WindowSettings(
        alwaysOnTop: true,
        opacity: 1.0,
        clickThrough: false,
        locked: false,
        frameX: nil, frameY: nil, frameWidth: nil, frameHeight: nil,
        toggleHotkey: nil
    )
}

/// 단축키 표현. modifierFlags 는 NSEvent.ModifierFlags.rawValue.
struct HotkeySpec: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt
    var displayString: String
}

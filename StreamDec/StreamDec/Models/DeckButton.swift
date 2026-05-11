import Foundation

/// 덱의 한 버튼. 그리드 좌표 + 액션 + 시각 스타일.
struct DeckButton: Codable, Identifiable, Equatable {
    var id: UUID
    /// 0-based grid row.
    var row: Int
    /// 0-based grid column.
    var column: Int
    var action: ButtonAction
    var style: DeckButtonStyle

    init(
        id: UUID = UUID(),
        row: Int,
        column: Int,
        action: ButtonAction = .none,
        style: DeckButtonStyle = .default
    ) {
        self.id = id
        self.row = row
        self.column = column
        self.action = action
        self.style = style
    }
}

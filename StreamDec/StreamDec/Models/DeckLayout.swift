import Foundation

/// 덱의 그리드 구조와 표시 형태.
struct DeckLayout: Codable, Equatable {
    var preset: Preset
    var size: DeckSize
    var orientation: DeckOrientation
    /// 자유 배치 시 사용될 행/열. preset == .custom 일 때만 의미가 있다.
    var customRows: Int
    var customColumns: Int

    enum Preset: String, Codable, CaseIterable {
        case grid2x2
        case grid3x3
        case grid4x2
        case grid5x3
        case custom

        var rows: Int {
            switch self {
            case .grid2x2: return 2
            case .grid3x3: return 3
            case .grid4x2: return 2
            case .grid5x3: return 3
            case .custom: return 0
            }
        }

        var columns: Int {
            switch self {
            case .grid2x2: return 2
            case .grid3x3: return 3
            case .grid4x2: return 4
            case .grid5x3: return 5
            case .custom: return 0
            }
        }

        var displayName: String {
            switch self {
            case .grid2x2: return "2 × 2"
            case .grid3x3: return "3 × 3"
            case .grid4x2: return "4 × 2"
            case .grid5x3: return "5 × 3"
            case .custom: return "자유 배치"
            }
        }
    }

    var rows: Int { preset == .custom ? customRows : preset.rows }
    var columns: Int { preset == .custom ? customColumns : preset.columns }
    var slotCount: Int { rows * columns }

    static let `default` = DeckLayout(
        preset: .grid3x3,
        size: .mini,                       // 사용자 작업을 가리지 않도록 가장 작은 크기 기본값
        orientation: .floatingIsland,
        customRows: 3,
        customColumns: 3
    )
}

enum DeckSize: String, Codable, CaseIterable {
    case mini, compact, normal, large

    /// 한 칸(셀)의 한 변 픽셀 크기.
    var cellSide: CGFloat {
        switch self {
        case .mini: return 36
        case .compact: return 56
        case .normal: return 72
        case .large: return 86
        }
    }

    var displayName: String {
        switch self {
        case .mini: return "Mini"
        case .compact: return "Compact"
        case .normal: return "Normal"
        case .large: return "Large"
        }
    }
}

enum DeckOrientation: String, Codable, CaseIterable {
    case vertical, horizontal, floatingIsland

    var displayName: String {
        switch self {
        case .vertical: return "세로형"
        case .horizontal: return "가로형"
        case .floatingIsland: return "플로팅 아일랜드"
        }
    }
}

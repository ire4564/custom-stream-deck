import Foundation

/// 버튼의 시각 스타일.
struct DeckButtonStyle: Codable, Equatable {
    var label: String
    var labelVisible: Bool
    var labelColorHex: String        // "#RRGGBB" 또는 "#RRGGBBAA"
    var labelFontSize: Double
    var labelAlignment: LabelAlignment

    var backgroundColorHex: String   // 단색 또는 그라데이션 시작
    var backgroundColorHexEnd: String? // 그라데이션 종료. nil 이면 단색.
    var backgroundTransparent: Bool

    var iconSource: IconSource
    /// GIF 데이터 (Application Support 하위에 저장될 상대 경로).
    var gifRelativePath: String?
    /// 아이콘과 GIF가 동시에 설정된 경우 우선순위.
    var gifPriority: Bool

    enum LabelAlignment: String, Codable, CaseIterable {
        case leading, center, trailing
    }

    enum IconSource: Codable, Equatable {
        case none
        case sfSymbol(name: String)
        case file(relativePath: String)

        private enum CodingKeys: String, CodingKey { case type, value }
        private enum Kind: String, Codable { case none, sfSymbol, file }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try c.decode(Kind.self, forKey: .type)
            switch kind {
            case .none: self = .none
            case .sfSymbol: self = .sfSymbol(name: try c.decode(String.self, forKey: .value))
            case .file: self = .file(relativePath: try c.decode(String.self, forKey: .value))
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .none:
                try c.encode(Kind.none, forKey: .type)
            case .sfSymbol(let name):
                try c.encode(Kind.sfSymbol, forKey: .type)
                try c.encode(name, forKey: .value)
            case .file(let path):
                try c.encode(Kind.file, forKey: .type)
                try c.encode(path, forKey: .value)
            }
        }
    }

    static let `default` = DeckButtonStyle(
        label: "",
        labelVisible: true,
        labelColorHex: "#FFFFFF",
        labelFontSize: 11,
        labelAlignment: .center,
        backgroundColorHex: "#3B82F6",
        backgroundColorHexEnd: nil,
        backgroundTransparent: false,
        iconSource: .sfSymbol(name: "square"),
        gifRelativePath: nil,
        gifPriority: false
    )
}

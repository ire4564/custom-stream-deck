import SwiftUI
import AppKit

/// HEX 문자열 ↔ Color 변환 유틸.
enum HexColor {
    /// "#RRGGBB" / "#RRGGBBAA" / "#RGB" 등을 Color 로 변환. 실패 시 fallback.
    static func color(_ hex: String, fallback: Color = .blue) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }

        // #RGB → #RRGGBB
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }

        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else {
            return fallback
        }

        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

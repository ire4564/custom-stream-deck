import Foundation

/// 버튼이 클릭되었을 때 실행될 액션 종류.
enum ButtonAction: Codable, Equatable {
    case none
    case openApp(OpenAppPayload)
    case openPath(OpenPathPayload)
    case openURL(OpenURLPayload)
    case runShell(ShellPayload)
    case runAppleScript(AppleScriptPayload)

    // MARK: Payloads

    struct OpenAppPayload: Codable, Equatable {
        var bundleIdentifier: String?
        var applicationURL: URL?
        /// 이미 실행 중이면 새 인스턴스 대신 포커스만 줄지 여부.
        var focusIfRunning: Bool
    }

    struct OpenPathPayload: Codable, Equatable {
        var path: String
        /// 지정된 앱으로 열기. nil 이면 시스템 기본 앱.
        var openWithBundleIdentifier: String?
        /// Security-scoped bookmark (있으면 우선 사용).
        var bookmarkData: Data?
    }

    struct OpenURLPayload: Codable, Equatable {
        /// http://, https://, mailto:, slack://, file:// 등 모든 URL 스킴 지원.
        var urlString: String
        /// 지정 브라우저/앱으로 열기. nil 이면 시스템 기본.
        var openWithBundleIdentifier: String?
    }

    struct ShellPayload: Codable, Equatable {
        var script: String
        var arguments: [String]
        /// 실행 전 확인 다이얼로그 표시 여부.
        var requireConfirmation: Bool
        /// 허용 목록(allowlist) 식별자. nil 이면 일반 실행.
        var allowlistID: UUID?
    }

    struct AppleScriptPayload: Codable, Equatable {
        var source: String
        var requireConfirmation: Bool
    }

    // MARK: - Codable (custom tagged)

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum Kind: String, Codable {
        case none, openApp, openPath, openURL, runShell, runAppleScript
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .none:
            self = .none
        case .openApp:
            self = .openApp(try c.decode(OpenAppPayload.self, forKey: .payload))
        case .openPath:
            self = .openPath(try c.decode(OpenPathPayload.self, forKey: .payload))
        case .openURL:
            self = .openURL(try c.decode(OpenURLPayload.self, forKey: .payload))
        case .runShell:
            self = .runShell(try c.decode(ShellPayload.self, forKey: .payload))
        case .runAppleScript:
            self = .runAppleScript(try c.decode(AppleScriptPayload.self, forKey: .payload))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(Kind.none, forKey: .type)
        case .openApp(let p):
            try c.encode(Kind.openApp, forKey: .type)
            try c.encode(p, forKey: .payload)
        case .openPath(let p):
            try c.encode(Kind.openPath, forKey: .type)
            try c.encode(p, forKey: .payload)
        case .openURL(let p):
            try c.encode(Kind.openURL, forKey: .type)
            try c.encode(p, forKey: .payload)
        case .runShell(let p):
            try c.encode(Kind.runShell, forKey: .type)
            try c.encode(p, forKey: .payload)
        case .runAppleScript(let p):
            try c.encode(Kind.runAppleScript, forKey: .type)
            try c.encode(p, forKey: .payload)
        }
    }

    var displayName: String {
        switch self {
        case .none: return "(액션 없음)"
        case .openApp: return "앱 실행"
        case .openPath: return "파일/폴더 열기"
        case .openURL: return "링크 열기"
        case .runShell: return "쉘 스크립트"
        case .runAppleScript: return "AppleScript"
        }
    }
}

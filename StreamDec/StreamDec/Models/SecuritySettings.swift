import Foundation

/// 글로벌 보안 설정. 프로필과 별개로 ~/Library/Application Support/StreamDec/security.json 에 저장.
struct SecuritySettings: Codable, Equatable {
    var confirmBeforeScript: Bool
    /// 화이트리스트. 비어 있으면 모든 스크립트 허용(단, confirmBeforeScript 옵션은 별개).
    var allowedScripts: [AllowedScript]

    static let `default` = SecuritySettings(
        confirmBeforeScript: true,
        allowedScripts: []
    )
}

struct AllowedScript: Codable, Identifiable, Equatable, Hashable {
    enum Kind: String, Codable { case command, path }
    let id: UUID
    var kind: Kind
    /// command: 정확히 일치할 쉘 명령 / path: 허용된 파일 경로 prefix
    var value: String
    var note: String

    init(id: UUID = UUID(), kind: Kind, value: String, note: String = "") {
        self.id = id; self.kind = kind; self.value = value; self.note = note
    }
}

/// 최근 실행 기록.
struct ExecutionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let buttonLabel: String?
    let actionDisplayName: String
    let success: Bool
    let message: String

    init(buttonLabel: String?, actionDisplayName: String, success: Bool, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.buttonLabel = buttonLabel
        self.actionDisplayName = actionDisplayName
        self.success = success
        self.message = message
    }
}

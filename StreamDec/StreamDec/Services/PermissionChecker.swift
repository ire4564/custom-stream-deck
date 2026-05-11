import Foundation
import AppKit
import ApplicationServices

/// macOS 시스템 권한 상태 점검 + 시스템 설정 딥링크.
@MainActor
enum PermissionChecker {

    enum Status {
        case granted, denied, unknown

        var symbolName: String {
            switch self {
            case .granted: return "checkmark.circle.fill"
            case .denied: return "xmark.octagon.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .granted: return "허용됨"
            case .denied: return "거부/미부여"
            case .unknown: return "확인 필요"
            }
        }
    }

    /// Accessibility (전역 단축키/일부 자동화에 영향). 프롬프트 없이 상태만 확인.
    static func accessibilityStatus() -> Status {
        return AXIsProcessTrusted() ? .granted : .denied
    }

    /// Automation (AppleScript로 다른 앱 제어). 시도 전까지는 알 수 없음 → unknown.
    static func automationStatus() -> Status {
        // 실제 사용 전엔 판별이 어려움. AppleScript dry-run 으로 확인은 위험 → 사용자가 액션 실행하면 알게 됨.
        return .unknown
    }

    /// Full Disk Access 추정. ~/Library/Mail 가 읽히면 부여로 추정.
    static func fullDiskAccessStatus() -> Status {
        let probe = ("~/Library/Mail" as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: probe)
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return .granted
        } catch {
            // 접근 거부면 .denied, 디렉토리 없으면 unknown
            if FileManager.default.fileExists(atPath: url.path) {
                return .denied
            }
            return .unknown
        }
    }

    // MARK: - System Settings deep links

    static func openSystemSettings(pane: SettingsPane) {
        if let url = URL(string: pane.urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    enum SettingsPane {
        case accessibility, automation, fullDiskAccess

        var urlString: String {
            switch self {
            case .accessibility:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .automation:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            case .fullDiskAccess:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
            }
        }
    }
}

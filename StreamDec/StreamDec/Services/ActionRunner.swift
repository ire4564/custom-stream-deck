import AppKit
import Foundation
import os

/// 버튼에 등록된 ButtonAction 을 실제로 실행하는 서비스.
/// - 모든 실행은 비동기(async). 호출자는 await 로 완료를 기다리거나 task 로 띄울 수 있다.
/// - 안전 정책:
///   - 쉘 스크립트는 `arguments` 배열로만 전달 (셸 보간 금지)
///   - 확인 옵션이 켜져 있으면 modal alert 로 사용자 컨펌
///   - 실패/결과는 `ActionLog` 에 기록 (Phase 8 에서 UI 노출)
@MainActor
final class ActionRunner {
    static let shared = ActionRunner()

    private let logger = Logger(subsystem: "com.dohee.streamdec", category: "ActionRunner")
    private(set) var recentLogs: [ActionLog] = []
    private let maxLogs = 200

    private init() {}

    // MARK: - Entry

    @discardableResult
    func run(_ action: ButtonAction, buttonLabel: String? = nil) async -> ActionResult {
        let started = Date()
        let security = SecurityStore.shared

        // 다른 앱을 띄우는 액션이면 잠시(0.8초) 우리 앱의 자동 activate 를 억제.
        switch action {
        case .openApp, .openPath, .openURL:
            AppDelegate.suppressAutoActivateUntil = Date().addingTimeInterval(0.8)
        default: break
        }

        // 1) 허용 목록 검사 (스크립트/경로 액션만)
        if !security.isAllowed(action: action) {
            let r = ActionResult.failed(message: "허용 목록에 등록되지 않은 액션입니다.")
            recordExecution(action: action, buttonLabel: buttonLabel, started: started, result: r)
            return r
        }

        // 2) 글로벌 '실행 전 확인' 옵션 (스크립트류만)
        let needsGlobalConfirm = security.settings.confirmBeforeScript
        let result: ActionResult
        switch action {
        case .none:
            result = .skipped(reason: "액션이 설정되지 않음")
        case .openApp(let payload):
            result = await runOpenApp(payload)
        case .openPath(let payload):
            result = await runOpenPath(payload)
        case .openURL(let payload):
            result = await runOpenURL(payload)
        case .runShell(let payload):
            let needConfirm = payload.requireConfirmation || needsGlobalConfirm
            if needConfirm, !confirm(message: "이 쉘 스크립트를 실행할까요?", detail: payload.script) {
                result = .cancelled
            } else {
                result = await runShell(payload)
            }
        case .runAppleScript(let payload):
            let needConfirm = payload.requireConfirmation || needsGlobalConfirm
            if needConfirm, !confirm(message: "이 AppleScript를 실행할까요?", detail: payload.source) {
                result = .cancelled
            } else {
                result = await runAppleScript(payload)
            }
        }

        recordExecution(action: action, buttonLabel: buttonLabel, started: started, result: result)
        return result
    }

    private func recordExecution(action: ButtonAction, buttonLabel: String?, started: Date, result: ActionResult) {
        appendLog(ActionLog(
            timestamp: started,
            duration: Date().timeIntervalSince(started),
            buttonLabel: buttonLabel,
            actionName: action.displayName,
            result: result
        ))
        // 영구 실행 기록
        let success = result.isSuccess
        let message: String
        switch result {
        case .succeeded: message = "성공"
        case .failed(let m): message = m
        case .cancelled: message = "사용자가 취소"
        case .skipped(let r): message = "건너뜀: \(r)"
        }
        SecurityStore.shared.appendRecord(
            ExecutionRecord(
                buttonLabel: buttonLabel,
                actionDisplayName: action.displayName,
                success: success,
                message: message
            )
        )
    }

    // MARK: - Individual runners

    private func runOpenApp(_ p: ButtonAction.OpenAppPayload) async -> ActionResult {
        let workspace = NSWorkspace.shared

        // 1) URL 결정: 저장된 URL → bundleId 검색 순서.
        var appURL: URL?
        if let direct = p.applicationURL, FileManager.default.fileExists(atPath: direct.path) {
            appURL = direct
        }
        if appURL == nil, let bid = p.bundleIdentifier {
            appURL = workspace.urlForApplication(withBundleIdentifier: bid)
        }
        guard let url = appURL else {
            return .failed(message: "앱을 찾을 수 없습니다. (경로/번들 ID 를 다시 등록해 주세요)")
        }

        // 2) 우리 앱이 frontmost 라면 활성화 양보 (cooperative activation 차단 회피).
        NSApp.deactivate()

        // 3) NSWorkspace 가 focus-or-launch 를 자동 처리하도록 한다.
        //    - focusIfRunning = true   → 기존 인스턴스에 포커스 (createsNew = false)
        //    - focusIfRunning = false  → 새 인스턴스 (createsNew = true)
        //   NSRunningApplication.activate 직접 호출은 macOS 14+ 에서 cooperative-activation 정책에 막힐 수 있어
        //   사용하지 않는다.
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.addsToRecentItems = true
        config.createsNewApplicationInstance = !p.focusIfRunning

        let result = await withCheckedContinuation { (cont: CheckedContinuation<ActionResult, Never>) in
            workspace.openApplication(at: url, configuration: config) { _, error in
                if let error = error {
                    cont.resume(returning: .failed(message: error.localizedDescription))
                } else {
                    cont.resume(returning: .succeeded)
                }
            }
        }
        if case .succeeded = result { return result }

        // 4) 비동기 호출 실패 → 동기 폴백.
        if workspace.open(url) { return .succeeded }
        return result
    }

    private func runOpenPath(_ p: ButtonAction.OpenPathPayload) async -> ActionResult {
        let workspace = NSWorkspace.shared
        let url = URL(fileURLWithPath: (p.path as NSString).expandingTildeInPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failed(message: "경로가 존재하지 않습니다: \(url.path)")
        }

        if let bid = p.openWithBundleIdentifier,
           let appURL = workspace.urlForApplication(withBundleIdentifier: bid) {
            let config = NSWorkspace.OpenConfiguration()
            return await withCheckedContinuation { (cont: CheckedContinuation<ActionResult, Never>) in
                workspace.open([url], withApplicationAt: appURL, configuration: config) { _, error in
                    if let error = error {
                        cont.resume(returning: .failed(message: error.localizedDescription))
                    } else {
                        cont.resume(returning: .succeeded)
                    }
                }
            }
        } else {
            let ok = workspace.open(url)
            return ok ? .succeeded : .failed(message: "열기 실패")
        }
    }

    private func runOpenURL(_ p: ButtonAction.OpenURLPayload) async -> ActionResult {
        let raw = p.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return .failed(message: "URL 이 비어 있습니다.") }
        let normalized: String
        if raw.contains("://") || raw.hasPrefix("mailto:") || raw.hasPrefix("tel:") {
            normalized = raw
        } else {
            normalized = "https://\(raw)"
        }
        guard let url = URL(string: normalized) else {
            return .failed(message: "올바르지 않은 URL: \(raw)")
        }

        NSApp.deactivate()

        let workspace = NSWorkspace.shared
        // 브라우저 식별: 사용자가 지정했거나, 시스템 기본 브라우저.
        let browserURL: URL? = {
            if let bid = p.openWithBundleIdentifier {
                return workspace.urlForApplication(withBundleIdentifier: bid)
            }
            if url.scheme == "http" || url.scheme == "https" {
                let probe = URL(string: "https://www.example.com")!
                return workspace.urlForApplication(toOpen: probe)
            }
            return nil
        }()
        let browserBID = browserURL.flatMap { Bundle(url: $0)?.bundleIdentifier }

        // 1) http(s) 이고 지원 브라우저면 AppleScript 로 기존 탭 포커스 시도.
        if (url.scheme == "http" || url.scheme == "https"),
           let bid = browserBID,
           let script = Self.focusOrOpenTabScript(browserBID: bid, url: normalized) {
            let success = await Task.detached(priority: .userInitiated) { () -> Bool in
                var err: NSDictionary?
                guard let s = NSAppleScript(source: script) else { return false }
                _ = s.executeAndReturnError(&err)
                // err 가 nil 이면 스크립트가 성공적으로 끝남 (포커스 OR 새 탭). 둘 다 우리에겐 succeeded.
                return err == nil
            }.value
            if success { return .succeeded }
            // AppleScript 실패(자동화 권한 미허용 등) → 폴백.
        }

        // 2) 폴백: NSWorkspace.open
        if let appURL = browserURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            return await withCheckedContinuation { (cont: CheckedContinuation<ActionResult, Never>) in
                workspace.open([url], withApplicationAt: appURL, configuration: config) { _, error in
                    if let error = error {
                        cont.resume(returning: .failed(message: error.localizedDescription))
                    } else {
                        cont.resume(returning: .succeeded)
                    }
                }
            }
        }
        return workspace.open(url) ? .succeeded : .failed(message: "URL 열기 실패")
    }

    /// 브라우저별 "이미 같은 URL 탭이 있으면 포커스, 없으면 새 탭" AppleScript.
    /// 지원: Safari, Chromium 계열(Chrome, Brave, Edge, Vivaldi).
    /// 처음 실행 시 macOS 가 자동화 권한 prompt 표시 → 사용자가 허용해야 동작.
    private static func focusOrOpenTabScript(browserBID: String, url: String) -> String? {
        let escaped = url.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "\"", with: "\\\"")
        switch browserBID {
        case "com.apple.Safari":
            return """
            tell application id "com.apple.Safari"
                activate
                set targetURL to "\(escaped)"
                set found to false
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t is targetURL then
                            set current tab of w to t
                            set index of w to 1
                            set found to true
                            exit repeat
                        end if
                    end repeat
                    if found then exit repeat
                end repeat
                if not found then
                    if (count of windows) = 0 then
                        make new document with properties {URL:targetURL}
                    else
                        tell front window to set current tab to (make new tab with properties {URL:targetURL})
                    end if
                end if
            end tell
            """
        case "com.google.Chrome",
             "com.brave.Browser",
             "com.microsoft.edgemac",
             "com.vivaldi.Vivaldi",
             "com.operasoftware.Opera":
            return """
            tell application id "\(browserBID)"
                activate
                set targetURL to "\(escaped)"
                set found to false
                repeat with w in windows
                    set i to 0
                    repeat with t in tabs of w
                        set i to i + 1
                        if URL of t is targetURL then
                            set active tab index of w to i
                            set index of w to 1
                            set found to true
                            exit repeat
                        end if
                    end repeat
                    if found then exit repeat
                end repeat
                if not found then
                    if (count of windows) = 0 then
                        make new window
                    end if
                    tell front window to make new tab with properties {URL:targetURL}
                end if
            end tell
            """
        default:
            return nil
        }
    }

    private func runShell(_ p: ButtonAction.ShellPayload) async -> ActionResult {
        // arguments 배열로 분리하여 셸 인젝션 방지.
        let script = p.script
        let args = p.arguments

        return await Task.detached(priority: .userInitiated) { () -> ActionResult in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // -c "script" arg1 arg2 ... 형태로 전달.
            // arg는 $1, $2... 로 스크립트 안에서 사용 가능.
            process.arguments = ["-c", script, "streamdec"] + args

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
                process.waitUntilExit()
                let status = process.terminationStatus
                if status == 0 {
                    return .succeeded
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    return .failed(message: "exit=\(status) \(errStr.prefix(200))")
                }
            } catch {
                return .failed(message: error.localizedDescription)
            }
        }.value
    }

    private func runAppleScript(_ p: ButtonAction.AppleScriptPayload) async -> ActionResult {
        let source = p.source
        return await Task.detached(priority: .userInitiated) { () -> ActionResult in
            var errorDict: NSDictionary?
            let script = NSAppleScript(source: source)
            _ = script?.executeAndReturnError(&errorDict)
            if let err = errorDict {
                let message = err[NSAppleScript.errorMessage] as? String ?? "AppleScript 실행 실패"
                return .failed(message: message)
            }
            return .succeeded
        }.value
    }

    // MARK: - Confirm

    private func confirm(message: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail.count > 400 ? String(detail.prefix(400)) + "…" : detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "실행")
        alert.addButton(withTitle: "취소")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Log

    private func appendLog(_ log: ActionLog) {
        recentLogs.insert(log, at: 0)
        if recentLogs.count > maxLogs {
            recentLogs.removeLast(recentLogs.count - maxLogs)
        }
        logger.info("Action result: \(log.actionName, privacy: .public) → \(String(describing: log.result), privacy: .public)")
    }
}

// MARK: - Models

enum ActionResult: CustomStringConvertible {
    case succeeded
    case failed(message: String)
    case cancelled
    case skipped(reason: String)

    var description: String {
        switch self {
        case .succeeded: return "succeeded"
        case .failed(let m): return "failed(\(m))"
        case .cancelled: return "cancelled"
        case .skipped(let r): return "skipped(\(r))"
        }
    }

    var isSuccess: Bool {
        if case .succeeded = self { return true }
        return false
    }
}

struct ActionLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let buttonLabel: String?
    let actionName: String
    let result: ActionResult
}

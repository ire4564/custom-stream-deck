import Foundation
import os

@MainActor
final class SecurityStore: ObservableObject {
    static let shared = SecurityStore()
    private let logger = Logger(subsystem: "com.dohee.streamdec", category: "SecurityStore")
    private let fm = FileManager.default

    @Published var settings: SecuritySettings = .default
    @Published var records: [ExecutionRecord] = []

    private var settingsURL: URL {
        ProfileStore.shared.rootURL.appendingPathComponent("security.json")
    }
    private var recordsURL: URL {
        ProfileStore.shared.rootURL.appendingPathComponent("execution_log.json")
    }

    private init() {
        load()
    }

    func load() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: settingsURL),
           let s = try? dec.decode(SecuritySettings.self, from: data) {
            settings = s
        }
        if let data = try? Data(contentsOf: recordsURL),
           let r = try? dec.decode([ExecutionRecord].self, from: data) {
            records = r
        }
    }

    func saveSettings() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            logger.error("saveSettings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveRecords() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(records)
            try data.write(to: recordsURL, options: .atomic)
        } catch {
            logger.error("saveRecords failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Allowed scripts CRUD

    func addAllowed(_ entry: AllowedScript) {
        settings.allowedScripts.append(entry)
        saveSettings()
    }
    func removeAllowed(_ id: UUID) {
        settings.allowedScripts.removeAll { $0.id == id }
        saveSettings()
    }
    func setConfirmBeforeScript(_ on: Bool) {
        settings.confirmBeforeScript = on
        saveSettings()
    }

    /// 주어진 액션이 허용되는지 검사. 허용 목록이 비어있으면 통과.
    func isAllowed(action: ButtonAction) -> Bool {
        if settings.allowedScripts.isEmpty { return true }
        switch action {
        case .runShell(let p):
            let trimmed = p.script.trimmingCharacters(in: .whitespacesAndNewlines)
            return settings.allowedScripts.contains {
                $0.kind == .command && trimmed.hasPrefix($0.value)
            }
        case .openPath(let p):
            return settings.allowedScripts.contains {
                $0.kind == .path && p.path.hasPrefix($0.value)
            }
        default:
            return true
        }
    }

    // MARK: - Execution log

    func appendRecord(_ record: ExecutionRecord) {
        records.insert(record, at: 0)
        // 최근 200개만 유지
        if records.count > 200 {
            records.removeLast(records.count - 200)
        }
        saveRecords()
    }

    func clearRecords() {
        records.removeAll()
        saveRecords()
    }
}

import Foundation
import os

/// 프로필 영속화 책임을 가진 저장소.
/// 위치: ~/Library/Application Support/StreamDec/
/// - profiles/<uuid>.json
/// - state.json   (현재 활성 프로필 ID 등)
final class ProfileStore {
    static let shared = ProfileStore()

    private let logger = Logger(subsystem: "com.dohee.streamdec", category: "ProfileStore")
    private let fm = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var rootURL: URL
    private var profilesURL: URL { rootURL.appendingPathComponent("profiles", isDirectory: true) }
    private var stateURL: URL { rootURL.appendingPathComponent("state.json") }

    private init() {
        let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let base = (appSupport ?? URL(fileURLWithPath: NSHomeDirectory()))
            .appendingPathComponent("StreamDec", isDirectory: true)
        self.rootURL = base

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        ensureDirectories()
    }

    // MARK: - Filesystem prep

    private func ensureDirectories() {
        for dir in [rootURL, profilesURL] {
            if !fm.fileExists(atPath: dir.path) {
                do {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch {
                    logger.error("Failed to create directory \(dir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - State (active profile id)

    struct State: Codable, Equatable {
        var activeProfileID: UUID?
        /// 일회성 마이그레이션 플래그: 모든 프로필을 최소 사이즈로 한 번 자동 조정했는지.
        /// 이후 사용자가 사이즈를 바꾸면 그대로 존중하기 위해 true 로 표시하고 다시 건드리지 않음.
        var didApplyMiniSizeMigration: Bool = false
    }

    func loadState() -> State {
        guard fm.fileExists(atPath: stateURL.path),
              let data = try? Data(contentsOf: stateURL),
              let state = try? decoder.decode(State.self, from: data) else {
            return State(activeProfileID: nil)
        }
        return state
    }

    func saveState(_ state: State) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            logger.error("saveState failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Profiles

    func listProfiles() -> [Profile] {
        guard let urls = try? fm.contentsOfDirectory(at: profilesURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var result: [Profile] = []
        for url in urls where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let profile = try? decoder.decode(Profile.self, from: data) {
                result.append(profile)
            }
        }
        return result.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ profile: Profile) throws {
        var p = profile
        p.updatedAt = Date()
        let url = profilesURL.appendingPathComponent("\(p.id.uuidString).json")
        let data = try encoder.encode(p)
        try data.write(to: url, options: .atomic)
    }

    func delete(profileID: UUID) throws {
        let url = profilesURL.appendingPathComponent("\(profileID.uuidString).json")
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    /// 프로필이 하나도 없으면 기본 프로필을 만들고, 활성 프로필을 보장한다.
    func bootstrapDefaultIfNeeded() -> Profile {
        var profiles = listProfiles()
        var state = loadState()

        if profiles.isEmpty {
            let def = Profile.makeDefault()
            try? save(def)
            state.activeProfileID = def.id
            state.didApplyMiniSizeMigration = true
            saveState(state)
            return def
        }

        // 일회성 마이그레이션: 모든 프로필을 mini 로 한 번 자동 조정.
        if !state.didApplyMiniSizeMigration {
            for var p in profiles {
                if p.layout.size != .mini {
                    p.layout.size = .mini
                    try? save(p)
                }
            }
            state.didApplyMiniSizeMigration = true
            saveState(state)
            profiles = listProfiles()
        }

        if let activeID = state.activeProfileID,
           let active = profiles.first(where: { $0.id == activeID }) {
            return active
        }

        // 활성 프로필이 사라졌으면 첫 번째로 fallback.
        let first = profiles[0]
        state.activeProfileID = first.id
        saveState(state)
        return first
    }

    // MARK: - Resources (icons / gifs)

    /// 프로필 단위 리소스 디렉토리. (아이콘/GIF 파일을 여기에 보관)
    func resourcesDirectory(for profileID: UUID) -> URL {
        let url = rootURL
            .appendingPathComponent("resources", isDirectory: true)
            .appendingPathComponent(profileID.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}

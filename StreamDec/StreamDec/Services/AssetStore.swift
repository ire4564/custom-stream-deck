import Foundation
import AppKit
import os

/// 아이콘/GIF 자산을 Application Support 의 assets/ 디렉토리에 복사하고
/// 모델에는 상대 경로만 저장한다.
final class AssetStore {
    static let shared = AssetStore()
    private let logger = Logger(subsystem: "com.dohee.streamdec", category: "AssetStore")
    private let fm = FileManager.default

    var assetsURL: URL {
        let url = ProfileStore.shared.rootURL.appendingPathComponent("assets", isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    /// 외부 파일을 assets/ 로 복사 후 상대 경로(파일명) 반환.
    func importFile(_ source: URL) throws -> String {
        let ext = source.pathExtension.lowercased()
        let name = "\(UUID().uuidString).\(ext)"
        let dest = assetsURL.appendingPathComponent(name)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)
        logger.info("Imported asset \(name, privacy: .public)")
        return name
    }

    /// 상대 경로 → 절대 URL.
    func absoluteURL(forRelativePath relPath: String) -> URL {
        assetsURL.appendingPathComponent(relPath)
    }

    /// 안 쓰는 자산 정리 (Phase 9 에서 호출). 지금은 미사용.
    func remove(relativePath: String) {
        let url = absoluteURL(forRelativePath: relativePath)
        try? fm.removeItem(at: url)
    }
}

import SwiftUI
import AppKit
import ImageIO

/// 정적 이미지 또는 GIF 애니메이션을 표시한다.
/// - 정적 이미지: SwiftUI Image + scaledToFit (비율 유지 fit)
/// - GIF: ImageIO 로 프레임 추출 → TimelineView 로 순환 표시 (역시 SwiftUI Image + scaledToFit)
/// 이 구조로 NSImageView 의 fit 이슈를 우회해 절대 잘리지 않게 한다.
struct AnimatedImageView: View {
    let url: URL
    /// 비율 처리 방식. fit = 컨테이너 안에 들어가게, fill = 컨테이너 가득 채움(잘림 허용).
    var contentMode: ContentMode = .fit

    @State private var frames: [GIFFrame] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if frames.count > 1 {
                TimelineView(.animation) { context in
                    let img = currentFrame(at: context.date)
                    if let img {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    } else {
                        Color.clear
                    }
                }
            } else if let only = frames.first {
                Image(nsImage: only.image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loaded {
                Color.clear
            } else {
                Color.clear
            }
        }
        .onAppear(perform: load)
        .onChange(of: url) { _ in load() }
    }

    // MARK: - GIF frame model

    private struct GIFFrame {
        let image: NSImage
        /// 누적 시작 시간 (sec)
        let startOffset: Double
        let duration: Double
    }

    private func currentFrame(at date: Date) -> NSImage? {
        guard !frames.isEmpty else { return nil }
        let total = frames.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return frames.first?.image }
        let elapsed = date.timeIntervalSince1970.truncatingRemainder(dividingBy: total)
        // 누적 startOffset 으로 찾기
        for f in frames where elapsed >= f.startOffset && elapsed < f.startOffset + f.duration {
            return f.image
        }
        return frames.last?.image
    }

    // MARK: - Load

    private func load() {
        frames = []
        loaded = false
        DispatchQueue.global(qos: .userInitiated).async {
            let extracted = Self.extractFrames(from: url)
            DispatchQueue.main.async {
                self.frames = extracted
                self.loaded = true
            }
        }
    }

    private static func extractFrames(from url: URL) -> [GIFFrame] {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
        let count = CGImageSourceGetCount(src)
        guard count > 0 else { return [] }

        // 단일 프레임(= 정적 이미지)는 그냥 NSImage 로 로드
        if count == 1 {
            if let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                return [GIFFrame(image: img, startOffset: 0, duration: 0)]
            }
            return []
        }

        var result: [GIFFrame] = []
        var acc: Double = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let gifProps = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = gifProps?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = gifProps?[kCGImagePropertyGIFDelayTime] as? Double
            // 0 이거나 비정상 값은 0.1초로 보정
            let raw = unclamped ?? clamped ?? 0.1
            let dur = raw < 0.02 ? 0.1 : raw
            let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            result.append(GIFFrame(image: img, startOffset: acc, duration: dur))
            acc += dur
        }
        return result
    }
}

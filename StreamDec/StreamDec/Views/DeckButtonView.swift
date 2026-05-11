import SwiftUI

struct DeckButtonView: View {
    let button: DeckButton
    let cellSide: CGFloat
    let isRunning: Bool
    var isEditing: Bool = false
    var isSelected: Bool = false
    var isDragging: Bool = false
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                mediaFill       // 큰 이미지/GIF 가 우선 표시일 때 버튼 전체에 aspect-fill 로 깔림
                mediaScrim      // 이미지 위에 아래→위 그라데이션 (가독성 보조)
                content
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .frame(width: cellSide, height: cellSide)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(isHovering ? 1.04 : (isRunning ? 0.97 : 1.0))
            .opacity(isDragging ? 0.5 : 1.0)
            .overlay(selectionOverlay)
            .overlay(runningPulse)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isRunning)
            .animation(.easeOut(duration: 0.12), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var runningPulse: some View {
        if isRunning {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.7), lineWidth: 2)
                .blur(radius: 1)
        }
    }

    @ViewBuilder
    private var selectionOverlay: some View {
        if isEditing && isSelected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2.5)
        } else if isEditing {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape
            .fill(backgroundStyle)
            // 상단 하이라이트 (글로시 효과)
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            // 하단 안쪽 그림자 (베벨 느낌)
            .overlay(
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.45),
                                Color.black.opacity(0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // 떠 있는 듯한 외부 그림자
            .shadow(color: .black.opacity(isHovering ? 0.45 : 0.30), radius: isHovering ? 10 : 6, x: 0, y: isHovering ? 5 : 3)
            .shadow(color: .black.opacity(0.20), radius: 1, x: 0, y: 1)
    }

    private var backgroundStyle: AnyShapeStyle {
        if button.style.backgroundTransparent {
            return AnyShapeStyle(Color.clear)
        }
        let start = HexColor.color(button.style.backgroundColorHex)
        if let endHex = button.style.backgroundColorHexEnd, !endHex.isEmpty {
            let end = HexColor.color(endHex)
            return AnyShapeStyle(
                LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        return AnyShapeStyle(start)
    }

    /// 이미지/GIF 가 등록되어 있으면 무조건 그것을 버튼 배경으로 사용한다.
    /// (별도 우선순위 토글 없이도 즉시 교체)
    private var useMediaForeground: Bool {
        button.style.gifRelativePath != nil
    }

    /// 버튼 배경을 가득 채우는 이미지/GIF (aspect-fill, 모서리 클리핑은 부모 clipShape 가 담당).
    @ViewBuilder
    private var mediaFill: some View {
        if useMediaForeground, let path = button.style.gifRelativePath {
            let url = AssetStore.shared.absoluteURL(forRelativePath: path)
            AnimatedImageView(url: url, contentMode: .fill)
                .id(url)  // url 변경 시 view 재생성 → 캐시된 frames 즉시 폐기
                .frame(width: cellSide, height: cellSide)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    /// 이미지 + 라벨이 함께 있을 때만 라벨 가독성을 위한 아래→위 검정 그라데이션 표시.
    /// 라벨이 없으면 이미지를 가리지 않도록 표시하지 않는다.
    @ViewBuilder
    private var mediaScrim: some View {
        let showsLabel = button.style.labelVisible && !button.style.label.isEmpty
        if useMediaForeground && showsLabel {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(width: cellSide, height: cellSide)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var content: some View {
        let showsLabel = button.style.labelVisible && !button.style.label.isEmpty
        VStack(spacing: 4) {
            // 큰 이미지 모드면 아이콘은 표시 안 함 (이미지가 이미 배경에 깔려 있음).
            if !useMediaForeground {
                iconView
                    .frame(width: cellSide * 0.5, height: cellSide * 0.5)
                    .font(.system(size: cellSide * 0.32, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1.2, x: 0, y: 1)
            }

            if showsLabel {
                Text(button.style.label)
                    .font(.system(size: CGFloat(button.style.labelFontSize), weight: .semibold))
                    .foregroundStyle(HexColor.color(button.style.labelColorHex, fallback: .white))
                    .shadow(color: .black.opacity(0.55), radius: 1.8, x: 0, y: 1)
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
        .padding(6)
        // 큰 이미지 모드면 라벨이 아래쪽에 표시되도록 정렬
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: useMediaForeground ? .bottom : .center
        )
    }

    /// 작은 아이콘 (SF Symbol 또는 파일 이미지). 큰 이미지 모드는 content 가 직접 그림.
    @ViewBuilder
    private var iconView: some View {
        switch button.style.iconSource {
        case .none:
            EmptyView()
        case .sfSymbol(let name):
            Image(systemName: name)
        case .file(let path):
            let url = AssetStore.shared.absoluteURL(forRelativePath: path)
            if let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .id(path)
            } else {
                Image(systemName: "photo")
            }
        }
    }

    private var isIconNone: Bool {
        if case .none = button.style.iconSource { return true }
        return false
    }

    private var textAlignment: TextAlignment {
        switch button.style.labelAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch button.style.labelAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

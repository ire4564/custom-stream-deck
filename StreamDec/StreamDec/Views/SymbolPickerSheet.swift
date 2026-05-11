import SwiftUI

/// 자주 쓰는 SF Symbol 을 그리드에서 선택. 검색 텍스트로 시스템 심볼 직접 입력도 가능.
struct SymbolPickerSheet: View {
    let current: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""

    // 자주 쓰일 만한 큐레이션 셋. (전체 SF Symbol 셋은 macOS 빌트인이 아니므로 일부만)
    private let symbols: [String] = [
        // 일반
        "star", "star.fill", "heart", "heart.fill", "bolt", "bolt.fill",
        "flame", "flame.fill", "sparkles", "moon", "moon.fill", "sun.max",
        // 파일/폴더
        "folder", "folder.fill", "doc", "doc.fill", "doc.text", "tray",
        "archivebox", "shippingbox", "externaldrive",
        // 미디어
        "play.fill", "pause.fill", "stop.fill", "forward.fill", "backward.fill",
        "speaker.wave.2.fill", "speaker.slash.fill", "mic.fill", "video.fill", "camera.fill",
        // 통신
        "envelope", "envelope.fill", "bubble.left", "bubble.left.fill", "phone.fill",
        // 액션
        "plus", "minus", "xmark", "checkmark", "arrow.clockwise", "arrow.uturn.left",
        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
        // 시스템
        "gearshape.fill", "wrench.fill", "hammer.fill", "terminal", "terminal.fill",
        "command", "option", "control", "power",
        // 앱
        "safari", "globe", "calendar", "clock", "timer", "alarm.fill",
        "bell.fill", "tag.fill", "bookmark.fill",
        // 개발
        "curlybraces", "chevron.left.forwardslash.chevron.right", "ladybug.fill",
        "doc.plaintext", "list.bullet", "checklist",
        // 미디어 편집
        "scissors", "wand.and.stars", "paintbrush.fill", "eyedropper",
        "rectangle.stack", "photo", "photo.fill",
        // 음악
        "music.note", "music.note.list", "music.mic",
        // 보안
        "lock.fill", "lock.open.fill", "key.fill", "shield.fill",
        "person.fill", "person.2.fill",
        // 기타
        "cart.fill", "bag.fill", "creditcard.fill", "house.fill", "cloud.fill",
        "wifi", "antenna.radiowaves.left.and.right"
    ]

    private var filtered: [String] {
        guard !query.isEmpty else { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SF Symbol 선택").font(.headline)
                Spacer()
                Button("닫기") { dismiss() }
            }
            TextField("심볼 이름 검색 또는 직접 입력 (Enter로 적용)", text: $query, onCommit: {
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onSelect(trimmed)
                    dismiss()
                }
            })
            .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            onSelect(name)
                            dismiss()
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 18))
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(name == current ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        .help(name)
                    }
                }
                .padding(4)
            }
        }
        .padding(16)
        .frame(width: 480, height: 460)
    }
}

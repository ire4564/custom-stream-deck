import SwiftUI
import AppKit

/// 단일 버튼의 시각 커스터마이징을 위한 시트.
/// - 즉시 미리보기: 좌측에 실시간 프리뷰.
/// - 되돌리기: 기본 스타일로 복원.
struct StyleEditorSheet: View {
    @ObservedObject var vm: DeckViewModel
    let buttonID: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var style: DeckButtonStyle = .default
    @State private var iconPickerOpen = false
    @State private var useGradient: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            preview
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    section("라벨") {
                        Toggle(isOn: $style.labelVisible) {
                            Text("텍스트 제목 표시")
                                .font(.subheadline.weight(.medium))
                        }
                        .toggleStyle(.switch)

                        TextField("라벨 텍스트", text: $style.label)
                            .disabled(!style.labelVisible)
                        HStack {
                            Text("크기")
                            Slider(value: $style.labelFontSize, in: 8...20, step: 1)
                            Text("\(Int(style.labelFontSize))")
                                .monospacedDigit()
                                .frame(width: 24, alignment: .trailing)
                        }
                        .disabled(!style.labelVisible)
                        Picker("정렬", selection: $style.labelAlignment) {
                            Text("좌").tag(DeckButtonStyle.LabelAlignment.leading)
                            Text("중").tag(DeckButtonStyle.LabelAlignment.center)
                            Text("우").tag(DeckButtonStyle.LabelAlignment.trailing)
                        }
                        .pickerStyle(.segmented)
                        .disabled(!style.labelVisible)
                        hexField(label: "라벨 색", binding: $style.labelColorHex)
                            .disabled(!style.labelVisible)
                    }
                    .opacity(1.0) // 섹션 자체는 흐려지지 않도록 (토글은 항상 또렷)

                    section("배경") {
                        Toggle("투명 배경", isOn: $style.backgroundTransparent)
                        hexField(label: "배경색", binding: $style.backgroundColorHex)
                            .disabled(style.backgroundTransparent)
                        paletteRow()
                        Toggle("그라데이션 사용", isOn: $useGradient)
                            .disabled(style.backgroundTransparent)
                            .onChange(of: useGradient) { on in
                                style.backgroundColorHexEnd = on ? (style.backgroundColorHexEnd ?? "#1E40AF") : nil
                            }
                        if useGradient {
                            hexField(
                                label: "끝 색",
                                binding: Binding(
                                    get: { style.backgroundColorHexEnd ?? "#1E40AF" },
                                    set: { style.backgroundColorHexEnd = $0 }
                                )
                            )
                        }
                    }

                    section("아이콘") {
                        iconRow
                    }

                    section("큰 이미지 / GIF") {
                        HStack {
                            Text(style.gifRelativePath.map { "선택됨: \($0)" } ?? "이미지/GIF 없음")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button("선택…") { pickImageOrGIF() }
                            if style.gifRelativePath != nil {
                                Button("제거") { style.gifRelativePath = nil }
                            }
                        }
                        Text("이미지를 등록하면 버튼 배경으로 자동 표시됩니다. PNG · JPG · HEIC · GIF 지원, GIF는 자동 애니메이션.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 620, height: 520)
        .toolbar { }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("기본값으로 초기화") {
                    style = .default
                    useGradient = false
                }
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("적용") {
                    vm.setStyle(style, for: buttonID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .onAppear {
            if let b = vm.profile.buttons.first(where: { $0.id == buttonID }) {
                style = b.style
                useGradient = (b.style.backgroundColorHexEnd != nil)
            }
        }
        .sheet(isPresented: $iconPickerOpen) {
            SymbolPickerSheet(current: currentSymbolName) { name in
                style.iconSource = .sfSymbol(name: name)
            }
        }
    }

    private var currentSymbolName: String {
        if case .sfSymbol(let n) = style.iconSource { return n }
        return "star.fill"
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 12) {
            Text("미리보기").font(.caption).foregroundStyle(.secondary)
            DeckButtonView(
                button: previewButton,
                cellSide: 140,
                isRunning: false,
                onTap: {}
            )
            Text("호버 상태").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 180)
    }

    private var previewButton: DeckButton {
        var b = vm.profile.buttons.first(where: { $0.id == buttonID }) ?? DeckButton(row: 0, column: 0)
        b.style = style
        return b
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07))
        )
    }

    @ViewBuilder
    private func hexField(label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label).frame(width: 60, alignment: .leading)
            TextField("#RRGGBB", text: binding)
                .textFieldStyle(.roundedBorder)
            RoundedRectangle(cornerRadius: 4)
                .fill(HexColor.color(binding.wrappedValue))
                .frame(width: 24, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.3)))
        }
    }

    private func paletteRow() -> some View {
        let palette = [
            "#3B82F6", "#10B981", "#F59E0B", "#EF4444",
            "#8B5CF6", "#EC4899", "#06B6D4", "#64748B",
            "#000000", "#FFFFFF"
        ]
        return HStack(spacing: 6) {
            ForEach(palette, id: \.self) { hex in
                Button {
                    style.backgroundColorHex = hex
                    style.backgroundTransparent = false
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HexColor.color(hex))
                        .frame(width: 22, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var iconRow: some View {
        HStack {
            iconPreview
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.12)))
            Button("SF Symbol…") { iconPickerOpen = true }
            Button("파일에서…") { pickIconFile() }
            Button("제거") { style.iconSource = .none }
            Spacer()
        }
    }

    @ViewBuilder
    private var iconPreview: some View {
        switch style.iconSource {
        case .none:
            Image(systemName: "questionmark").foregroundStyle(.secondary)
        case .sfSymbol(let name):
            Image(systemName: name).font(.system(size: 20)).foregroundStyle(.primary)
        case .file(let path):
            let url = AssetStore.shared.absoluteURL(forRelativePath: path)
            // .id(path) 로 path 변경 시 view 강제 재생성 → 새 NSImage 로드
            if let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().scaledToFit().id(path)
            } else {
                Image(systemName: "photo")
            }
        }
    }

    // MARK: - File pickers

    private func pickIconFile() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let rel = try AssetStore.shared.importFile(url)
                style.iconSource = .file(relativePath: rel)
            } catch {
                NSSound.beep()
            }
        }
    }

    private func pickImageOrGIF() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        // GIF + 모든 일반 이미지 포맷을 받는다. .image 는 PNG/JPG/HEIC/TIFF/BMP 등을 포괄.
        panel.allowedContentTypes = [.gif, .png, .jpeg, .heic, .tiff, .bmp, .webP, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let rel = try AssetStore.shared.importFile(url)
                style.gifRelativePath = rel
            } catch {
                NSSound.beep()
            }
        }
    }
}

import SwiftUI

/// 다중 선택된 버튼들에 공통 속성을 한 번에 적용.
struct BulkEditSheet: View {
    @ObservedObject var vm: DeckViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var applyLabel = false
    @State private var label = ""

    @State private var applyBg = false
    @State private var bgHex = "#3B82F6"

    @State private var applyLabelColor = false
    @State private var labelColorHex = "#FFFFFF"

    @State private var applyLabelVisible = false
    @State private var labelVisible = true

    @State private var applyIcon = false
    @State private var iconName = "star.fill"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("일괄 편집 (\(vm.selectedButtonIDs.count)개)")
                .font(.title3.bold())

            Toggle(isOn: $applyLabel) {
                HStack {
                    Text("라벨").frame(width: 100, alignment: .leading)
                    TextField("새 라벨", text: $label)
                        .disabled(!applyLabel)
                }
            }
            Toggle(isOn: $applyLabelVisible) {
                HStack {
                    Text("라벨 표시").frame(width: 100, alignment: .leading)
                    Toggle("표시", isOn: $labelVisible)
                        .disabled(!applyLabelVisible)
                        .labelsHidden()
                }
            }
            Toggle(isOn: $applyLabelColor) {
                HStack {
                    Text("라벨 색").frame(width: 100, alignment: .leading)
                    TextField("#FFFFFF", text: $labelColorHex)
                        .disabled(!applyLabelColor)
                    swatch(HexColor.color(labelColorHex))
                }
            }
            Toggle(isOn: $applyBg) {
                HStack {
                    Text("배경색").frame(width: 100, alignment: .leading)
                    TextField("#3B82F6", text: $bgHex)
                        .disabled(!applyBg)
                    swatch(HexColor.color(bgHex))
                }
            }
            Toggle(isOn: $applyIcon) {
                HStack {
                    Text("SF Symbol").frame(width: 100, alignment: .leading)
                    TextField("star.fill", text: $iconName)
                        .disabled(!applyIcon)
                    Image(systemName: iconName)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("적용") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440, height: 360)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.3)))
    }

    private func apply() {
        if applyLabel { vm.applyBulk(.label(label)) }
        if applyLabelVisible { vm.applyBulk(.labelVisible(labelVisible)) }
        if applyLabelColor { vm.applyBulk(.labelColorHex(labelColorHex)) }
        if applyBg { vm.applyBulk(.backgroundColorHex(bgHex)) }
        if applyIcon { vm.applyBulk(.iconSFSymbol(iconName)) }
        dismiss()
    }
}

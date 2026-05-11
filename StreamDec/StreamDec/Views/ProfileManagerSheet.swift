import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProfileManagerSheet: View {
    @ObservedObject var vm: DeckViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @State private var renamingID: UUID?
    @State private var renameBuffer: String = ""
    @State private var showImportConflictPrompt: ImportPrompt?

    struct ImportPrompt: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("프로필 관리").font(.title3.bold())
                Spacer()
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            list
                .frame(minHeight: 220)

            Divider()

            HStack {
                TextField("새 프로필 이름", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("새로 만들기") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        vm.createProfile(name: name)
                        newName = ""
                    }
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Button {
                    importProfile()
                } label: {
                    Label("가져오기…", systemImage: "square.and.arrow.down")
                }
                Spacer()
                Button {
                    exportAll()
                } label: {
                    Label("전체 내보내기…", systemImage: "square.and.arrow.up.on.square")
                }
            }
        }
        .padding(18)
        .frame(width: 520, height: 460)
        .alert(item: $showImportConflictPrompt) { prompt in
            Alert(
                title: Text("프로필 충돌"),
                message: Text("이미 동일한 이름/ID 의 프로필이 있습니다. 어떻게 처리할까요?"),
                primaryButton: .default(Text("새 이름으로 추가")) {
                    _ = try? vm.importProfile(from: prompt.url, conflict: .renameNew)
                },
                secondaryButton: .destructive(Text("덮어쓰기")) {
                    _ = try? vm.importProfile(from: prompt.url, conflict: .overwrite)
                }
            )
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(vm.allProfiles, id: \.id) { p in
                    row(for: p)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.06)))
    }

    @ViewBuilder
    private func row(for p: Profile) -> some View {
        let active = (p.id == vm.profile.id)
        HStack {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(active ? Color.accentColor : .secondary)

            if renamingID == p.id {
                TextField("이름", text: $renameBuffer, onCommit: {
                    commitRename(p)
                })
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(p.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(p.buttons.count) 버튼")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Menu {
                Button("활성화") { vm.switchProfile(to: p.id) }
                    .disabled(active)
                Button("이름 변경") {
                    renamingID = p.id
                    renameBuffer = p.name
                }
                .disabled(!active) // 현재는 활성 프로필만 이름변경
                Button("복제") {
                    if !active { vm.switchProfile(to: p.id) }
                    vm.duplicateCurrentProfile()
                }
                Button("내보내기…") { exportSingle(p) }
                Divider()
                Button("삭제", role: .destructive) { vm.deleteProfile(p.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(active ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            vm.switchProfile(to: p.id)
        }
    }

    private func commitRename(_ p: Profile) {
        let name = renameBuffer.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            vm.renameCurrentProfile(name)
        }
        renamingID = nil
        renameBuffer = ""
    }

    // MARK: - Export / Import

    private func exportSingle(_ p: Profile) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [streamdecType, .json]
        panel.nameFieldStringValue = "\(p.name).streamdec"
        if panel.runModal() == .OK, let url = panel.url {
            try? vm.exportProfile(p.id, to: url)
        }
    }

    private func exportAll() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [streamdecType, .json]
        panel.nameFieldStringValue = "StreamDec-bundle.streamdec"
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
            try? vm.exportAllProfiles(to: url)
        }
    }

    private func importProfile() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [streamdecType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
            // 충돌 검사 (간이): JSON 디코드 → 동일 ID/이름 비교
            if let data = try? Data(contentsOf: url),
               let p = try? JSONDecoder.iso().decode(Profile.self, from: data),
               vm.allProfiles.contains(where: { $0.id == p.id || $0.name == p.name }) {
                showImportConflictPrompt = ImportPrompt(url: url)
            } else {
                _ = try? vm.importProfile(from: url, conflict: .renameNew)
            }
        }
    }

    private var streamdecType: UTType {
        UTType(exportedAs: "com.dohee.streamdec.profile", conformingTo: .json)
    }
}

private extension JSONDecoder {
    static func iso() -> JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }
}

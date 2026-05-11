import SwiftUI
import AppKit

/// Phase 3 검증용 최소 액션 등록 시트.
/// Phase 4-5 에서 정식 편집 UI 로 대체된다.
struct QuickActionAssignSheet: View {
    @ObservedObject var vm: DeckViewModel
    let buttonID: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var actionKind: Kind = .none
    @State private var label: String = ""

    // openApp
    @State private var bundleIdentifier: String = ""
    @State private var pickedAppURL: URL? = nil   // bundleIdentifier 없을 때 fallback
    @State private var focusIfRunning: Bool = true

    // openPath
    @State private var path: String = ""

    // openURL
    @State private var urlString: String = ""

    // shell
    @State private var shellScript: String = "echo hello from StreamDec"
    @State private var requireShellConfirm: Bool = true

    // applescript
    @State private var applescript: String = "display notification \"StreamDec\" with title \"Hello\""
    @State private var requireScriptConfirm: Bool = true

    enum Kind: String, CaseIterable, Identifiable {
        case none, openApp, openPath, openURL, runShell, runAppleScript
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .none: return "없음"
            case .openApp: return "앱 실행"
            case .openPath: return "파일/폴더 열기"
            case .openURL: return "링크 열기"
            case .runShell: return "쉘 스크립트"
            case .runAppleScript: return "AppleScript"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("버튼 액션 등록")
                .font(.title3.bold())

            HStack {
                Text("라벨")
                    .frame(width: 80, alignment: .leading)
                TextField("선택사항", text: $label)
            }

            HStack {
                Text("액션 종류")
                    .frame(width: 80, alignment: .leading)
                Picker("", selection: $actionKind) {
                    ForEach(Kind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
            }

            Divider()

            Group {
                switch actionKind {
                case .none:
                    Text("이 버튼은 아무 동작도 하지 않습니다.")
                        .foregroundStyle(.secondary)
                case .openApp:
                    openAppForm
                case .openPath:
                    openPathForm
                case .openURL:
                    openURLForm
                case .runShell:
                    shellForm
                case .runAppleScript:
                    appleScriptForm
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("저장") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440, height: 360)
        .onAppear(perform: load)
    }

    // MARK: - Forms

    private var openAppForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Bundle Identifier (예: com.apple.Safari)", text: $bundleIdentifier)
                Button("앱 선택…", action: pickApp)
            }
            if let url = pickedAppURL {
                HStack(spacing: 6) {
                    Image(systemName: "app.fill").foregroundStyle(.secondary)
                    Text(url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        pickedAppURL = nil
                    } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                }
            }
            Toggle("이미 실행 중이면 포커스만", isOn: $focusIfRunning)
        }
    }

    private var openPathForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("파일 또는 폴더 경로", text: $path)
                Button("경로 선택…", action: pickPath)
            }
        }
    }

    private var openURLForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(.roundedBorder)
            }
            Text("https:// 가 없으면 자동으로 추가됩니다. mailto: / slack:// 등 모든 스킴 지원.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var shellForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("쉘 스크립트")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $shellScript)
                .font(.system(.body, design: .monospaced))
                .frame(height: 110)
                .border(Color.secondary.opacity(0.3))
            Toggle("실행 전 확인", isOn: $requireShellConfirm)
        }
    }

    private var appleScriptForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AppleScript")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $applescript)
                .font(.system(.body, design: .monospaced))
                .frame(height: 110)
                .border(Color.secondary.opacity(0.3))
            Toggle("실행 전 확인", isOn: $requireScriptConfirm)
        }
    }

    // MARK: - Pickers

    private func pickApp() {
        // accessory app(LSUIElement) + 떠있는 nonactivating sheet 위에서
        // NSOpenPanel 이 뒤로 숨겨지지 않도록 강제 활성화 + 레벨 보강.
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "앱 선택"
        panel.prompt = "선택"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.level = .modalPanel

        guard panel.runModal() == .OK, let url = panel.url else { return }
        // bundleIdentifier 를 못 읽어도 URL 만으로 액션을 만들 수 있게 fallback.
        if let bid = Bundle(url: url)?.bundleIdentifier {
            bundleIdentifier = bid
        } else {
            bundleIdentifier = ""
        }
        pickedAppURL = url
    }

    private func pickPath() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "파일 또는 폴더 선택"
        panel.prompt = "선택"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    // MARK: - Persist

    private func load() {
        guard let btn = vm.profile.buttons.first(where: { $0.id == buttonID }) else { return }
        label = btn.style.label
        switch btn.action {
        case .none: actionKind = .none
        case .openApp(let p):
            actionKind = .openApp
            bundleIdentifier = p.bundleIdentifier ?? ""
            pickedAppURL = p.applicationURL
            focusIfRunning = p.focusIfRunning
        case .openPath(let p):
            actionKind = .openPath
            path = p.path
        case .openURL(let p):
            actionKind = .openURL
            urlString = p.urlString
        case .runShell(let p):
            actionKind = .runShell
            shellScript = p.script
            requireShellConfirm = p.requireConfirmation
        case .runAppleScript(let p):
            actionKind = .runAppleScript
            applescript = p.source
            requireScriptConfirm = p.requireConfirmation
        }
    }

    private func save() {
        let newAction: ButtonAction
        switch actionKind {
        case .none:
            newAction = .none
        case .openApp:
            newAction = .openApp(.init(
                bundleIdentifier: bundleIdentifier.isEmpty ? nil : bundleIdentifier,
                applicationURL: pickedAppURL,
                focusIfRunning: focusIfRunning
            ))
        case .openPath:
            newAction = .openPath(.init(
                path: path,
                openWithBundleIdentifier: nil,
                bookmarkData: nil
            ))
        case .openURL:
            newAction = .openURL(.init(
                urlString: urlString,
                openWithBundleIdentifier: nil
            ))
        case .runShell:
            newAction = .runShell(.init(
                script: shellScript,
                arguments: [],
                requireConfirmation: requireShellConfirm,
                allowlistID: nil
            ))
        case .runAppleScript:
            newAction = .runAppleScript(.init(
                source: applescript,
                requireConfirmation: requireScriptConfirm
            ))
        }
        vm.setAction(newAction, for: buttonID)
        vm.setLabel(label, for: buttonID)
        dismiss()
    }
}

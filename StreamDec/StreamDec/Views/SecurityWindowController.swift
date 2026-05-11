import AppKit
import SwiftUI

final class SecurityWindowController: NSWindowController {
    private static var current: SecurityWindowController?

    static func show() {
        if let c = current {
            c.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: SecurityRootView(onClose: {
            current?.close()
            current = nil
        }))
        let window = NSWindow(contentViewController: host)
        window.title = "권한 및 보안"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 480))
        window.center()
        let c = SecurityWindowController(window: window)
        current = c
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SecurityRootView: View {
    let onClose: () -> Void
    @State private var tab: Tab = .permissions

    enum Tab: Hashable { case permissions, allowlist, log }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("권한").tag(Tab.permissions)
                Text("허용 목록").tag(Tab.allowlist)
                Text("실행 기록").tag(Tab.log)
            }
            .pickerStyle(.segmented)
            .padding(12)

            Divider()

            Group {
                switch tab {
                case .permissions: PermissionsTab()
                case .allowlist: AllowlistTab()
                case .log: ExecutionLogTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            HStack {
                Spacer()
                Button("닫기") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
    }
}

// MARK: - Permissions

private struct PermissionsTab: View {
    @State private var ax: PermissionChecker.Status = .unknown
    @State private var auto: PermissionChecker.Status = .unknown
    @State private var fda: PermissionChecker.Status = .unknown

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                row(
                    title: "접근성 (Accessibility)",
                    description: "전역 단축키 및 일부 자동화에 필요합니다.",
                    status: ax,
                    settingsAction: { PermissionChecker.openSystemSettings(pane: .accessibility) }
                )
                row(
                    title: "자동화 (Automation)",
                    description: "AppleScript로 다른 앱을 제어할 때 macOS가 권한을 요구합니다. 액션 실행 시점에 요청됩니다.",
                    status: auto,
                    settingsAction: { PermissionChecker.openSystemSettings(pane: .automation) }
                )
                row(
                    title: "전체 디스크 접근 (Full Disk Access)",
                    description: "보호된 영역(예: ~/Library/Mail)을 여는 액션을 사용한다면 필요합니다.",
                    status: fda,
                    settingsAction: { PermissionChecker.openSystemSettings(pane: .fullDiskAccess) }
                )
                HStack {
                    Button("다시 점검") { refresh() }
                    Spacer()
                }
            }
            .padding(16)
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        ax = PermissionChecker.accessibilityStatus()
        auto = PermissionChecker.automationStatus()
        fda = PermissionChecker.fullDiskAccessStatus()
    }

    private func row(title: String, description: String, status: PermissionChecker.Status, settingsAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbolName)
                .font(.title2)
                .foregroundStyle(color(for: status))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.callout).foregroundStyle(.secondary)
                Text("상태: \(status.label)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("시스템 설정 열기") { settingsAction() }
                .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
    }

    private func color(for s: PermissionChecker.Status) -> Color {
        switch s {
        case .granted: return .green
        case .denied: return .red
        case .unknown: return .orange
        }
    }
}

// MARK: - Allowlist

private struct AllowlistTab: View {
    @ObservedObject private var store = SecurityStore.shared
    @State private var newKind: AllowedScript.Kind = .command
    @State private var newValue: String = ""
    @State private var newNote: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("스크립트 실행 전 확인 다이얼로그 항상 표시", isOn: Binding(
                get: { store.settings.confirmBeforeScript },
                set: store.setConfirmBeforeScript
            ))
            Text("허용 목록이 비어 있으면 모든 액션이 허용됩니다. 항목을 추가하면 그 항목들만 실행 가능합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            list

            Divider()

            HStack(spacing: 6) {
                Picker("종류", selection: $newKind) {
                    Text("명령 prefix").tag(AllowedScript.Kind.command)
                    Text("경로 prefix").tag(AllowedScript.Kind.path)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                TextField(newKind == .command ? "예: /usr/local/bin/my-tool" : "예: /Users/me/Projects", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                TextField("메모", text: $newNote)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button("추가") {
                    let v = newValue.trimmingCharacters(in: .whitespaces)
                    if !v.isEmpty {
                        store.addAllowed(.init(kind: newKind, value: v, note: newNote))
                        newValue = ""; newNote = ""
                    }
                }
                .disabled(newValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(store.settings.allowedScripts) { entry in
                    HStack {
                        Image(systemName: entry.kind == .command ? "terminal" : "folder")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(entry.value).font(.system(.body, design: .monospaced))
                            if !entry.note.isEmpty {
                                Text(entry.note).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.removeAllowed(entry.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.06)))
                }
                if store.settings.allowedScripts.isEmpty {
                    Text("등록된 항목 없음 (모든 액션 허용 상태)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 180)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
    }
}

// MARK: - Execution log

private struct ExecutionLogTab: View {
    @ObservedObject private var store = SecurityStore.shared

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 실행 기록 (\(store.records.count)건)").font(.headline)
                Spacer()
                Button("기록 비우기", role: .destructive) { store.clearRecords() }
                    .disabled(store.records.isEmpty)
            }
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.records) { rec in
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: rec.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(rec.success ? .green : .red)
                            Text(formatter.string(from: rec.timestamp))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(rec.actionDisplayName).font(.callout)
                            if let label = rec.buttonLabel, !label.isEmpty {
                                Text("· \(label)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(rec.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 220, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.05)))
                    }
                    if store.records.isEmpty {
                        Text("기록 없음")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                    }
                }
            }
        }
        .padding(16)
    }
}

import SwiftUI

struct DeckRootView: View {
    @StateObject private var vm = DeckViewModel.shared
    @State private var editingButtonID: UUID?
    @State private var stylingButtonID: UUID?
    @State private var showBulkSheet = false
    @State private var showProfileSheet = false
    @State private var confirmDelete = false
    private let spacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 6) {
            if vm.isEditing { editorToolbar }
            gridView
        }
        .padding(8)
        .background(chassisBackground)
        .contextMenu {
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("StreamDec 종료", systemImage: "power")
            }
        }
        .sheet(item: Binding(
            get: { editingButtonID.map(IdentifiedID.init) },
            set: { editingButtonID = $0?.id }
        )) { wrapper in
            QuickActionAssignSheet(vm: vm, buttonID: wrapper.id)
        }
        .sheet(item: Binding(
            get: { stylingButtonID.map(IdentifiedID.init) },
            set: { stylingButtonID = $0?.id }
        )) { wrapper in
            StyleEditorSheet(vm: vm, buttonID: wrapper.id)
        }
        .sheet(isPresented: $showBulkSheet) {
            BulkEditSheet(vm: vm)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileManagerSheet(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openProfileManager)) { _ in
            showProfileSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBulkEditor)) { _ in
            if !vm.selectedButtonIDs.isEmpty {
                showBulkSheet = true
            }
        }
        .alert("선택한 \(vm.selectedButtonIDs.count)개 버튼을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) { vm.deleteSelected() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제된 버튼은 '복구' 메뉴로 되돌릴 수 있습니다.")
        }
    }

    // MARK: - Chassis & Header

    /// Stream Deck 풍 흰색 케이스. 반투명(약 50%) 으로 배경이 살짝 비침.
    private var chassisBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.55),
                        Color(red: 0.90, green: 0.90, blue: 0.92).opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }


    // MARK: - Editor toolbar

    private var editorToolbar: some View {
        HStack(spacing: 6) {
            Button {
                vm.addEmptyButton()
            } label: {
                Label("추가", systemImage: "plus")
            }
            Button {
                vm.duplicateSelected()
            } label: {
                Label("복제", systemImage: "doc.on.doc")
            }
            .disabled(vm.selectedButtonIDs.isEmpty)
            Button {
                confirmDelete = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
            .disabled(vm.selectedButtonIDs.isEmpty)
            Button {
                showBulkSheet = true
            } label: {
                Label("일괄편집", systemImage: "slider.horizontal.3")
            }
            .disabled(vm.selectedButtonIDs.isEmpty)
            Button {
                vm.restoreLastDeleted()
            } label: {
                Label("복구", systemImage: "arrow.uturn.backward")
            }
            .disabled(vm.recentlyDeleted.isEmpty)

            Spacer()
            if !vm.selectedButtonIDs.isEmpty {
                Text("\(vm.selectedButtonIDs.count)개 선택")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 4)
    }

    // MARK: - Grid (반응형: 가로 폭에 맞춰 정사각형 버튼 크기 자동 계산)

    private var gridView: some View {
        let cols = vm.profile.layout.columns
        let rows = vm.profile.layout.rows
        let aspect = CGFloat(cols) / CGFloat(rows)

        return GeometryReader { geo in
            let availableWidth = geo.size.width
            let totalHSpacing = spacing * CGFloat(max(cols - 1, 0))
            let side = max(36, (availableWidth - totalHSpacing) / CGFloat(cols))
            let gridHeight = CGFloat(rows) * side + spacing * CGFloat(max(rows - 1, 0))

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { c in
                            cell(row: r, column: c, side: side)
                        }
                    }
                }
            }
            .frame(width: availableWidth, height: gridHeight, alignment: .top)
        }
        // 그리드 종횡비 = cols : rows. SwiftUI 가 폭에 맞춰 높이를 정해줌.
        .aspectRatio(aspect, contentMode: .fit)
    }

    @ViewBuilder
    private func cell(row r: Int, column c: Int, side: CGFloat) -> some View {
        if let btn = vm.button(row: r, column: c) {
            DeckButtonView(
                button: btn,
                cellSide: side,
                isRunning: vm.runningButtonIDs.contains(btn.id),
                isEditing: vm.isEditing,
                isSelected: vm.selectedButtonIDs.contains(btn.id),
                isDragging: vm.draggingButtonID == btn.id,
                onTap: {
                    let modifiers = NSEvent.modifierFlags
                    let multi = modifiers.contains(.shift) || modifiers.contains(.command)
                    vm.handleClick(buttonID: btn.id, shiftOrCmd: multi)
                }
            )
            .contextMenu { buttonContextMenu(for: btn) }
            .onDrag {
                vm.draggingButtonID = btn.id
                return NSItemProvider(object: btn.id.uuidString as NSString)
            }
            .onDrop(of: ["public.text"], delegate: DropOnCellDelegate(
                vm: vm, targetRow: r, targetColumn: c
            ))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
                .frame(width: side, height: side)
                .onDrop(of: ["public.text"], delegate: DropOnCellDelegate(
                    vm: vm, targetRow: r, targetColumn: c
                ))
        }
    }

    @ViewBuilder
    private func buttonContextMenu(for btn: DeckButton) -> some View {
        Button("액션 등록…") { editingButtonID = btn.id }
        Button("스타일 편집…") { stylingButtonID = btn.id }
        if case .none = btn.action {} else {
            Button("액션 제거") { vm.setAction(.none, for: btn.id) }
        }
        Button("스타일 초기화") { vm.resetStyle(for: btn.id) }
        Divider()
        Button("복제") {
            vm.selectedButtonIDs = [btn.id]
            vm.duplicateSelected()
        }
        Button("삭제", role: .destructive) {
            vm.selectedButtonIDs = [btn.id]
            confirmDelete = true
        }
    }

    private struct IdentifiedID: Identifiable {
        let id: UUID
    }
}

// MARK: - Drop delegate

private struct DropOnCellDelegate: DropDelegate {
    let vm: DeckViewModel
    let targetRow: Int
    let targetColumn: Int

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: ["public.text"]).first else { return false }
        item.loadObject(ofClass: NSString.self) { object, _ in
            guard let s = object as? String, let uuid = UUID(uuidString: s) else { return }
            Task { @MainActor in
                vm.move(buttonID: uuid, to: targetRow, column: targetColumn)
                vm.draggingButtonID = nil
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {}
    func dropExited(info: DropInfo) {
        Task { @MainActor in
            // 드래그가 다른 곳으로 빠지면 시각효과 해제
        }
    }

    func validateDrop(info: DropInfo) -> Bool { true }
}

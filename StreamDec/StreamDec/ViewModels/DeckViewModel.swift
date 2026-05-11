import Foundation
import SwiftUI
import Combine
import os

/// 현재 활성 프로필을 노출하고, 버튼 클릭 등 UI 이벤트를 처리한다.
@MainActor
final class DeckViewModel: ObservableObject {
    static let shared = DeckViewModel()

    private let logger = Logger(subsystem: "com.dohee.streamdec", category: "DeckViewModel")
    private let store: ProfileStore

    @Published var profile: Profile
    /// 현재 저장된 모든 프로필 목록(메타 표시용).
    @Published var allProfiles: [Profile] = []
    /// 액션 실행 중인 버튼 ID 집합. Phase 3+ 에서 사용.
    @Published var runningButtonIDs: Set<UUID> = []
    /// 편집 모드 토글. true 면 클릭 = 선택, false 면 클릭 = 액션 실행.
    @Published var isEditing: Bool = false
    /// 편집 모드에서의 다중 선택.
    @Published var selectedButtonIDs: Set<UUID> = []
    /// 최근 삭제된 버튼들. 복구용. (최대 20개)
    @Published var recentlyDeleted: [DeckButton] = []
    /// 드래그 중인 버튼 ID. 그리드 스냅 시각화에 활용.
    @Published var draggingButtonID: UUID?

    /// 사용자가 명시적으로 레이아웃/크기를 바꿨을 때 패널을 그 크기에 맞게 즉시 리사이즈하라는 신호.
    /// AppDelegate 가 구독하여 panel.setFrame + minSize 갱신.
    let resizeToLayoutSignal = PassthroughSubject<Void, Never>()

    private init(store: ProfileStore = .shared) {
        self.store = store
        self.profile = store.bootstrapDefaultIfNeeded()
        self.allProfiles = store.listProfiles()
    }

    func reloadProfiles() {
        allProfiles = store.listProfiles()
    }

    // MARK: - Lookup

    func button(row: Int, column: Int) -> DeckButton? {
        profile.buttons.first { $0.row == row && $0.column == column }
    }

    // MARK: - Layout

    func setLayoutPreset(_ preset: DeckLayout.Preset) {
        var p = profile
        p.layout.preset = preset
        reconcileButtonsToLayout(&p)
        persist(p)
        resizeToLayoutSignal.send()
    }

    func setDeckSize(_ size: DeckSize) {
        var p = profile
        p.layout.size = size
        persist(p)
        resizeToLayoutSignal.send()
    }

    func setOrientation(_ orientation: DeckOrientation) {
        var p = profile
        p.layout.orientation = orientation
        persist(p)
    }

    // MARK: - Click

    /// 버튼 클릭 → 편집 모드면 선택 토글, 아니면 ActionRunner 로 실행.
    func handleClick(buttonID: UUID, shiftOrCmd: Bool = false) {
        guard let btn = profile.buttons.first(where: { $0.id == buttonID }) else { return }
        if isEditing {
            toggleSelection(btn.id, exclusive: !shiftOrCmd)
            return
        }
        logger.info("Click button id=\(btn.id.uuidString, privacy: .public) action=\(btn.action.displayName, privacy: .public)")

        runningButtonIDs.insert(btn.id)
        Task { [weak self] in
            let label = btn.style.label.isEmpty ? nil : btn.style.label
            _ = await ActionRunner.shared.run(btn.action, buttonLabel: label)
            await MainActor.run { [weak self] in
                _ = self?.runningButtonIDs.remove(btn.id)
            }
        }
    }

    // MARK: - Button mutation (Phase 3에서 임시 등록 UI를 위해 일부 노출)

    func setAction(_ action: ButtonAction, for buttonID: UUID) {
        var p = profile
        guard let idx = p.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
        p.buttons[idx].action = action
        persist(p)
    }

    func setLabel(_ label: String, for buttonID: UUID) {
        var p = profile
        guard let idx = p.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
        p.buttons[idx].style.label = label
        persist(p)
    }

    func setLabelVisible(_ visible: Bool, for buttonID: UUID) {
        var p = profile
        guard let idx = p.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
        p.buttons[idx].style.labelVisible = visible
        persist(p)
    }

    /// 단일 버튼의 전체 스타일을 교체.
    func setStyle(_ style: DeckButtonStyle, for buttonID: UUID) {
        var p = profile
        guard let idx = p.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
        p.buttons[idx].style = style
        persist(p)
    }

    /// 단일 버튼의 스타일을 기본값으로 복원.
    func resetStyle(for buttonID: UUID) {
        setStyle(.default, for: buttonID)
    }

    // MARK: - Window settings

    func setAlwaysOnTop(_ on: Bool) {
        var p = profile; p.windowSettings.alwaysOnTop = on; persist(p)
    }

    func setOpacity(_ value: Double) {
        var p = profile
        p.windowSettings.opacity = max(0.2, min(1.0, value))
        persist(p)
    }

    func setClickThrough(_ on: Bool) {
        var p = profile; p.windowSettings.clickThrough = on; persist(p)
    }

    func setLocked(_ on: Bool) {
        var p = profile; p.windowSettings.locked = on; persist(p)
    }

    func saveFrame(_ frame: CGRect) {
        var p = profile
        p.windowSettings.frameX = Double(frame.origin.x)
        p.windowSettings.frameY = Double(frame.origin.y)
        p.windowSettings.frameWidth = Double(frame.size.width)
        p.windowSettings.frameHeight = Double(frame.size.height)
        persist(p)
    }

    func setHotkey(_ spec: HotkeySpec?) {
        var p = profile; p.windowSettings.toggleHotkey = spec; persist(p)
    }

    // MARK: - Edit mode

    func toggleEditMode() {
        isEditing.toggle()
        if !isEditing { selectedButtonIDs.removeAll() }
    }

    func toggleSelection(_ id: UUID, exclusive: Bool) {
        if exclusive {
            if selectedButtonIDs == [id] {
                selectedButtonIDs.removeAll()
            } else {
                selectedButtonIDs = [id]
            }
        } else {
            if selectedButtonIDs.contains(id) {
                selectedButtonIDs.remove(id)
            } else {
                selectedButtonIDs.insert(id)
            }
        }
    }

    func selectAll() {
        selectedButtonIDs = Set(profile.buttons.map(\.id))
    }

    func clearSelection() {
        selectedButtonIDs.removeAll()
    }

    // MARK: Add / Delete / Duplicate

    /// 빈 슬롯 중 가장 앞쪽(좌상단)에 새 버튼 추가. 없으면 무시.
    @discardableResult
    func addEmptyButton() -> UUID? {
        var p = profile
        let rows = p.layout.rows
        let cols = p.layout.columns
        let occupied = Set(p.buttons.map { "\($0.row),\($0.column)" })
        for r in 0..<rows {
            for c in 0..<cols where !occupied.contains("\(r),\(c)") {
                let new = DeckButton(row: r, column: c)
                p.buttons.append(new)
                persist(p)
                return new.id
            }
        }
        return nil // 빈 슬롯 없음
    }

    func deleteSelected() {
        guard !selectedButtonIDs.isEmpty else { return }
        var p = profile
        let removed = p.buttons.filter { selectedButtonIDs.contains($0.id) }
        p.buttons.removeAll { selectedButtonIDs.contains($0.id) }
        // 휴지통에 적재 (최신순)
        recentlyDeleted.insert(contentsOf: removed, at: 0)
        if recentlyDeleted.count > 20 {
            recentlyDeleted.removeLast(recentlyDeleted.count - 20)
        }
        selectedButtonIDs.removeAll()
        persist(p)
    }

    func restoreLastDeleted() {
        guard !recentlyDeleted.isEmpty else { return }
        let restored = recentlyDeleted.removeFirst()
        var p = profile
        // 원래 좌표가 비어있으면 거기, 아니면 빈 슬롯으로 재배치.
        let occupied = Set(p.buttons.map { "\($0.row),\($0.column)" })
        var placed = restored
        if occupied.contains("\(restored.row),\(restored.column)") {
            if let slot = findFirstFreeSlot(in: p) {
                placed.row = slot.row
                placed.column = slot.column
            } else {
                // 자리 없음 → 휴지통에 되돌리고 종료
                recentlyDeleted.insert(restored, at: 0)
                return
            }
        }
        p.buttons.append(placed)
        persist(p)
    }

    /// 선택된 버튼들을 복제 (시각 스타일 + 액션 모두 포함). 빈 슬롯에 차례로 배치.
    func duplicateSelected() {
        guard !selectedButtonIDs.isEmpty else { return }
        var p = profile
        let originals = p.buttons.filter { selectedButtonIDs.contains($0.id) }
        var newIDs: Set<UUID> = []
        for orig in originals {
            guard let slot = findFirstFreeSlot(in: p) else { break }
            var copy = orig
            copy.id = UUID()
            copy.row = slot.row
            copy.column = slot.column
            p.buttons.append(copy)
            newIDs.insert(copy.id)
        }
        selectedButtonIDs = newIDs
        persist(p)
    }

    // MARK: Move / Swap

    /// 버튼을 (row, column) 으로 이동. 해당 좌표에 다른 버튼이 있으면 swap.
    func move(buttonID: UUID, to row: Int, column: Int) {
        let rows = profile.layout.rows
        let cols = profile.layout.columns
        guard row >= 0, row < rows, column >= 0, column < cols else { return }
        var p = profile
        guard let idx = p.buttons.firstIndex(where: { $0.id == buttonID }) else { return }
        if let otherIdx = p.buttons.firstIndex(where: { $0.row == row && $0.column == column && $0.id != buttonID }) {
            // swap
            let prevRow = p.buttons[idx].row
            let prevCol = p.buttons[idx].column
            p.buttons[idx].row = row
            p.buttons[idx].column = column
            p.buttons[otherIdx].row = prevRow
            p.buttons[otherIdx].column = prevCol
        } else {
            p.buttons[idx].row = row
            p.buttons[idx].column = column
        }
        persist(p)
    }

    // MARK: Bulk edit

    enum BulkProperty {
        case label(String)
        case backgroundColorHex(String)
        case labelColorHex(String)
        case labelVisible(Bool)
        case iconSFSymbol(String)
    }

    func applyBulk(_ property: BulkProperty) {
        guard !selectedButtonIDs.isEmpty else { return }
        var p = profile
        for idx in p.buttons.indices where selectedButtonIDs.contains(p.buttons[idx].id) {
            switch property {
            case .label(let v): p.buttons[idx].style.label = v
            case .backgroundColorHex(let v): p.buttons[idx].style.backgroundColorHex = v
            case .labelColorHex(let v): p.buttons[idx].style.labelColorHex = v
            case .labelVisible(let v): p.buttons[idx].style.labelVisible = v
            case .iconSFSymbol(let v): p.buttons[idx].style.iconSource = .sfSymbol(name: v)
            }
        }
        persist(p)
    }

    // MARK: - Profile management

    enum ImportConflict {
        case overwrite, renameNew
    }

    /// 활성 프로필 전환.
    func switchProfile(to id: UUID) {
        guard let target = allProfiles.first(where: { $0.id == id }) else { return }
        profile = target
        store.saveState(.init(activeProfileID: id))
        logger.info("Switched profile to \(target.name, privacy: .public)")
    }

    /// 새 프로필 생성 후 활성화.
    @discardableResult
    func createProfile(name: String) -> Profile {
        let p = Profile(name: name, layout: .default, buttons: [])
        try? store.save(p)
        store.saveState(.init(activeProfileID: p.id))
        profile = p
        reloadProfiles()
        return p
    }

    /// 프로필 이름 변경(현재 프로필).
    func renameCurrentProfile(_ newName: String) {
        var p = profile
        p.name = newName
        persist(p)
        reloadProfiles()
    }

    /// 프로필 복제. 새 ID + " (복제)" 이름. 자동 활성화.
    func duplicateCurrentProfile() {
        var copy = profile
        copy.id = UUID()
        copy.name = profile.name + " (복제)"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        try? store.save(copy)
        store.saveState(.init(activeProfileID: copy.id))
        profile = copy
        reloadProfiles()
    }

    /// 프로필 삭제. 마지막 프로필이면 새 기본 프로필을 만들어 활성화.
    func deleteProfile(_ id: UUID) {
        try? store.delete(profileID: id)
        reloadProfiles()
        if profile.id == id {
            if let first = allProfiles.first {
                switchProfile(to: first.id)
            } else {
                let def = createProfile(name: "기본")
                switchProfile(to: def.id)
            }
        }
    }

    /// 단일 프로필을 JSON 파일로 내보내기.
    func exportProfile(_ id: UUID, to url: URL) throws {
        guard let p = allProfiles.first(where: { $0.id == id }) ?? (profile.id == id ? profile : nil) else {
            throw NSError(domain: "StreamDec", code: 404, userInfo: [NSLocalizedDescriptionKey: "프로필을 찾을 수 없습니다."])
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(p)
        try data.write(to: url, options: .atomic)
    }

    /// 전체 프로필을 하나의 번들 JSON 으로 내보내기.
    func exportAllProfiles(to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        struct Bundle: Codable { let version: Int; let profiles: [Profile] }
        let bundle = Bundle(version: 1, profiles: allProfiles)
        let data = try enc.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    /// 파일에서 프로필 가져오기. 충돌 시 정책에 따라 처리.
    func importProfile(from url: URL, conflict: ImportConflict) throws -> Profile {
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let imported = try dec.decode(Profile.self, from: data)

        var final = imported
        // ID/이름 충돌 정책
        let nameConflict = allProfiles.contains { $0.name == imported.name }
        let idConflict = allProfiles.contains { $0.id == imported.id }
        switch conflict {
        case .overwrite:
            // ID 유지(있으면 덮어쓰기) + 이름 유지
            break
        case .renameNew:
            if idConflict { final.id = UUID() }
            if nameConflict { final.name = imported.name + " (가져옴)" }
            final.createdAt = Date()
        }
        final.updatedAt = Date()
        try store.save(final)
        reloadProfiles()
        return final
    }

    // MARK: helpers

    private func findFirstFreeSlot(in p: Profile) -> (row: Int, column: Int)? {
        let rows = p.layout.rows
        let cols = p.layout.columns
        let occupied = Set(p.buttons.map { "\($0.row),\($0.column)" })
        for r in 0..<rows {
            for c in 0..<cols where !occupied.contains("\(r),\(c)") {
                return (r, c)
            }
        }
        return nil
    }

    // MARK: - Internal

    /// 레이아웃이 변경되면 누락 슬롯에 빈 버튼을 채우고, 범위 밖 버튼은 잘라낸다.
    private func reconcileButtonsToLayout(_ p: inout Profile) {
        let rows = p.layout.rows
        let cols = p.layout.columns
        // 1) 범위 밖 제거
        p.buttons.removeAll { $0.row >= rows || $0.column >= cols }
        // 2) 빈 슬롯 채우기
        let occupied = Set(p.buttons.map { "\($0.row),\($0.column)" })
        for r in 0..<rows {
            for c in 0..<cols where !occupied.contains("\(r),\(c)") {
                p.buttons.append(DeckButton(row: r, column: c))
            }
        }
    }

    private func persist(_ updated: Profile) {
        profile = updated
        do {
            try store.save(updated)
            // allProfiles 안의 동일 ID 항목도 갱신
            if let idx = allProfiles.firstIndex(where: { $0.id == updated.id }) {
                allProfiles[idx] = updated
            } else {
                allProfiles.append(updated)
            }
        } catch {
            logger.error("Failed to save profile: \(error.localizedDescription, privacy: .public)")
        }
    }
}

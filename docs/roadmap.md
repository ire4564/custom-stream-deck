# StreamDec 개발 로드맵

각 Phase는 독립적으로 빌드/실행 가능한 상태로 마무리합니다.
완료 기준(DoD: Definition of Done)을 명시합니다.

---

## Phase 0 — 프로젝트 초기 세팅 ⬜
- Swift Package(SPM) 기반 macOS 앱 스캐폴드 생성
- 디렉토리: `Models/`, `Views/`, `ViewModels/`, `Services/`, `Resources/`
- `StreamDecApp.swift`(@main) + `AppDelegate.swift`
- `LSUIElement=true`, 메뉴바 아이콘 표시
- 빈 floating `NSPanel` 표시 (3x3 빈 그리드 placeholder)
- **DoD**: `swift run` 또는 Xcode 빌드 → 메뉴바 아이콘 + 떠 있는 빈 패널 확인

## Phase 1 — 데이터 모델 & 영속화 ⬜
- `Profile`, `DeckLayout`, `DeckSize`, `DeckOrientation`, `DeckButton`, `ButtonAction`, `ButtonStyle` 모델 (`Codable`)
- `ProfileStore` (Application Support 디렉토리 JSON 저장/로드)
- 기본 프로필 자동 생성
- **DoD**: 앱 재시작 후 프로필 유지

## Phase 2 — 메인 덱 UI ⬜
- 프리셋 레이아웃(2x2/3x3/4x2/5x3) `LazyVGrid`로 렌더
- 덱 사이즈(mini/compact/normal/large) 반영
- 가로/세로 형태 전환
- 빈 버튼 클릭 시 placeholder 동작
- **DoD**: 레이아웃을 바꿔 가며 시각적으로 확인 가능

## Phase 3 — 버튼 액션 실행 ⬜
- `ActionRunner` 서비스
  - 앱 실행: `NSWorkspace.shared.openApplication`
  - 파일/폴더 열기: `NSWorkspace.shared.open`
  - 쉘 스크립트: `Process` + `arguments`
  - AppleScript: `NSAppleScript`
- 실행 전 확인 옵션
- **DoD**: 각 액션 타입이 정상 트리거됨

## Phase 4 — 버튼 편집 모드 ⬜
- 편집 모드 토글
- 버튼 추가/삭제/복제
- 드래그 이동 + 그리드 스냅
- 다중 선택 (Shift/Cmd) + 일괄 편집 시트
- 삭제 확인 + 최근 삭제 복구
- **DoD**: 편집/저장 사이클 동작

## Phase 5 — 시각 커스터마이징 ⬜
- 아이콘: 파일 업로드 / SF Symbols 라이브러리
- 라벨: 텍스트/폰트크기/색상/정렬
- 배경: 팔레트/HEX/투명/그라데이션(선택)
- GIF 표시 + 우선순위
- 즉시 미리보기 / 되돌리기
- **DoD**: 버튼별 다른 스타일 저장·복원

## Phase 6 — 앱 표시·동작 설정 ⬜
- 항상 위 토글 (`NSWindow.level`)
- 투명도 슬라이더 + 프리셋
- 클릭 통과 (`ignoresMouseEvents`) + 안전 해제(메뉴바/단축키)
- 위치/크기 잠금
- 전역 단축키 (표시/숨김 토글)
- **DoD**: 메뉴바에서 모든 토글 동작

## Phase 7 — 프로필 관리 ⬜
- 프로필 목록 / 전환 UI
- 복제 / 이름 변경
- 내보내기 / 가져오기 (`.streamdec` JSON)
- 가져오기 충돌 처리(덮어쓰기/새이름)
- **DoD**: 프로필 파일 라운드트립

## Phase 8 — 권한 & 보안 ⬜
- 권한 상태 점검 (Automation, Full Disk Access)
- `x-apple.systempreferences:` 딥링크
- 스크립트 허용 목록(화이트리스트) CRUD
- 실행 기록 뷰
- **DoD**: 권한 없을 때 친절한 안내 동작

## Phase 9 — 폴리시 & 배포 ⬜
- 호버 애니메이션, 실행 중 진행 상태(스피너)
- 환경설정 화면 다듬기
- Developer ID 서명 + notarization 스크립트
- README / 사용자 가이드
- **DoD**: `.app` 더블클릭으로 실행

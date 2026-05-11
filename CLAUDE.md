# StreamDec — 커스텀 가능한 가상 스트림덱 (macOS)

이 파일은 Claude Code가 본 프로젝트에서 작업할 때 따라야 할 규칙을 정의합니다.

## 1. 프로젝트 개요
- **제품**: macOS 데스크톱 위에 떠 있는 시각형 액션 런처(가상 스트림덱)
- **타겟 OS**: macOS 13(Ventura) 이상
- **언어 / 프레임워크**: Swift 5.9+, SwiftUI (필요시 AppKit 보강)
- **번들 ID**: `com.dohee.streamdec`
- **배포 방식**: 로컬 개발 빌드(.app), 추후 Developer ID 서명 → notarization

전체 기능 명세는 `docs/spec.md`, 유저플로우는 `docs/userflow.md`를 참고합니다.

## 2. 디렉토리 구조
```
streamDec/
├── CLAUDE.md                    # (이 파일) 작업 규칙
├── docs/
│   ├── spec.md                  # 기능 명세서
│   ├── userflow.md              # 유저플로우 (mermaid)
│   └── roadmap.md               # 단계별 개발 로드맵
└── StreamDec/                   # Xcode 프로젝트 루트
    └── StreamDec/
        ├── StreamDecApp.swift   # @main 진입점
        ├── AppDelegate.swift    # NSApplicationDelegate (창/단축키/메뉴바)
        ├── Models/              # Profile, DeckLayout, DeckButton, ButtonAction 등
        ├── Views/               # DeckWindowView, ButtonView, Settings 화면
        ├── ViewModels/          # DeckViewModel, EditorViewModel 등
        ├── Services/            # ProfileStore, ActionRunner, PermissionChecker, HotkeyManager
        └── Resources/           # 기본 아이콘, Assets.xcassets
```

## 3. 아키텍처 원칙
- **MVVM 기반 SwiftUI**: 단방향 데이터 흐름. View는 `@StateObject` / `@ObservedObject`로 ViewModel 구독.
- **Service 레이어 분리**: 파일 I/O, 단축키, 권한 체크, 액션 실행 등은 모두 `Services/`로 분리.
- **모델 영속화**: `Codable` + JSON. 프로필은 `~/Library/Application Support/StreamDec/profiles/` 아래 저장.
- **창 운영**: 데스크톱 위에 떠 있는 패널 → `NSPanel` (`.nonactivatingPanel`, `.hudWindow` 또는 borderless) + `level = .floating`.
- **접근성/자동화 권한**: 필요 시점에만 요청. 단축키는 `NSEvent.addGlobalMonitor` + `addLocalMonitor`. 전역 단축키는 `MASShortcut` 대신 자체 구현(외부 의존 최소화).

## 4. 코딩 규칙
- **Swift Concurrency 우선**: 비동기 작업은 `async/await`. 콜백 API는 wrapping.
- **Force unwrap 금지**: `!` 대신 `guard let`/`if let`.
- **이름 규칙**: 타입 PascalCase, 변수/함수 camelCase, 파일명은 타입명과 일치.
- **외부 라이브러리**: 가능한 한 의존성 없이 표준 프레임워크만 사용. 꼭 필요하면 Swift Package Manager.
- **로깅**: `os.Logger` 사용. `print` 금지(디버그 임시 제외).
- **주석**: 자명하지 않은 로직만. doc comment(`///`)는 public API에만.
- **테스트**: Service 레이어와 ViewModel은 단위 테스트 작성(가능한 범위).

## 5. 보안 / 권한 정책
- 스크립트 실행은 기본 OFF. 사용자가 명시적으로 허용 목록(whitelist)에 등록한 항목만 실행.
- `Process`로 쉘 스크립트 실행 시: 사용자 입력은 절대 그대로 셸에 넘기지 않음. `arguments` 배열로 분리.
- 파일/폴더 접근은 사용자가 `NSOpenPanel`로 선택한 경로만. Security-Scoped Bookmark로 영속화.
- AppleScript 실행 전 확인 다이얼로그 옵션 지원.
- 모든 액션 실행 기록은 로컬에만 저장(외부 전송 금지).

## 6. 빌드 / 실행
- Xcode 15+로 `StreamDec/StreamDec.xcodeproj` 열기.
- Run scheme: `StreamDec` (Debug).
- Entitlements: `com.apple.security.app-sandbox = false` (스크립트 실행/전역 단축키 위해 비활성).
- Info.plist 필수 키:
  - `LSUIElement` — `true` (Dock 아이콘 숨김, 메뉴바 앱 형태)
  - `NSAppleEventsUsageDescription`
  - `NSDesktopFolderUsageDescription` / `NSDocumentsFolderUsageDescription` (필요 시)

## 7. 작업 진행 규칙 (개발 단계)
개발은 `docs/roadmap.md`의 단계 순서대로 진행합니다. 각 단계가 끝나면 사용자에게 보고하고 다음 단계로 진입합니다.

1. **Phase 0 — 프로젝트 초기 세팅**: Xcode 프로젝트 생성, 폴더 구조, Info.plist, AppDelegate, 메뉴바 아이콘, 빈 패널 표시.
2. **Phase 1 — 데이터 모델 & 영속화**: `Profile` / `DeckLayout` / `DeckButton` / `ButtonAction` 모델, JSON 저장소(`ProfileStore`).
3. **Phase 2 — 메인 덱 UI**: 프리셋 레이아웃(2x2/3x3/4x2/5x3) 그리드 렌더, 빈 버튼 표시.
4. **Phase 3 — 버튼 액션 실행**: 앱 실행, 파일/폴더 열기, 쉘/AppleScript 실행 (`ActionRunner`).
5. **Phase 4 — 버튼 편집 모드**: 추가/삭제/복제/이동(드래그+그리드 스냅), 다중 선택 일괄 편집.
6. **Phase 5 — 시각 커스터마이징**: 아이콘 업로드/라이브러리, 라벨, 배경색(팔레트/HEX), GIF.
7. **Phase 6 — 앱 표시·동작 설정**: 항상 위, 투명도, 클릭 통과, 위치/크기 잠금, 전역 단축키.
8. **Phase 7 — 프로필 관리**: 다중 프로필, 전환, 복제, 가져오기/내보내기.
9. **Phase 8 — 권한 & 보안**: 권한 점검 UI, 시스템 설정 딥링크, 스크립트 허용 목록, 실행 기록.
10. **Phase 9 — 폴리시 & 배포**: 호버/실행 중 애니메이션, 환경설정 UI 다듬기, 서명/빌드 스크립트.

## 8. Claude Code에게
- 현재 phase가 무엇인지 항상 확인하고, 해당 phase의 범위를 벗어나는 변경은 하지 않습니다.
- 코드 변경 후에는 빌드 가능 여부를 사용자에게 알리고, Xcode가 필요한 단계라면 그 사실을 명시합니다.
- 새 파일은 위 디렉토리 구조에 맞춰 생성합니다.
- 사용자에게는 한국어로 보고합니다.

# StreamDec

macOS용 커스텀 가능한 가상 스트림덱. 데스크톱 위에 떠 있는 시각형 액션 런처.

## 주요 기능

| 카테고리 | 내용 |
|---|---|
| **레이아웃** | 2×2 / 3×3 / 4×2 / 5×3 프리셋, Mini/Compact/Normal/Large 4단계 사이즈 |
| **버튼 액션** | 앱 실행, 파일/폴더 열기, 쉘 스크립트, AppleScript |
| **시각 커스터마이징** | SF Symbol·파일 아이콘, GIF, 라벨 폰트·색·정렬, 단색·그라데이션·투명 배경 |
| **편집 모드** | 추가/삭제/복제, 드래그 이동(스왑), 다중 선택 + 일괄편집, 삭제 복구 |
| **창 동작** | 항상 위, 투명도(20·40·60·80·100%), 클릭 통과, 위치·크기 잠금 |
| **전역 단축키** | 캡처 UI로 임의 조합 등록 (덱 표시/숨김) |
| **프로필** | 다중 프로필, 메뉴/헤더에서 빠른 전환, `.streamdec` 가져오기·내보내기 (충돌 시 덮어쓰기 / 새 이름 선택) |
| **보안** | 권한 점검 + 시스템 설정 딥링크(접근성·자동화·전체 디스크), 스크립트 허용 목록(prefix), 실행 전 확인, 최근 200건 실행 기록 |

## 빌드 & 실행

### Debug (SPM)
```bash
cd StreamDec
swift build
./scripts/make_app.sh debug
open build/StreamDec.app
```

### Release
```bash
cd StreamDec
./scripts/release.sh
# build/StreamDec.app + build/StreamDec-<version>.zip 생성
cp -R build/StreamDec.app /Applications/
```

## 사용

- **메뉴바 아이콘** (`square.grid.3x3.square`)
  - 덱 보이기/숨기기 (⌘D)
  - 항상 위 / 클릭 통과 / 위치·크기 잠금 토글
  - 투명도 프리셋
  - 프로필 전환 / 프로필 관리…
  - 단축키 설정…
  - 권한 및 보안…
- **헤더 좌측 프로필명** → 다른 프로필 전환 / 프로필 관리
- **헤더 우측** → 레이아웃 메뉴 / 사이즈 메뉴 / 슬라이더(표시·동작) / 편집모드 토글(✏️)
- **버튼 클릭** → 등록된 액션 실행 (실행 중에는 펄스 효과)
- **버튼 우클릭** → 액션 등록 / 스타일 편집 / 복제 / 삭제 등
- **편집 모드** → 추가/삭제/복제, 드래그 이동(스왑), 다중 선택 후 일괄편집

## 파일 위치

```
~/Library/Application Support/StreamDec/
├── state.json                 # 활성 프로필 ID
├── profiles/<uuid>.json       # 프로필별 JSON (레이아웃·버튼·창설정)
├── assets/                    # 사용자가 업로드한 아이콘·GIF
├── security.json              # 허용 목록·확인 옵션
└── execution_log.json         # 최근 실행 기록
```

## 문서
- `CLAUDE.md` — Claude Code 작업 규칙
- `docs/spec.md` — 기능 명세
- `docs/userflow.md` — 유저플로우
- `docs/roadmap.md` — Phase별 개발 로드맵

## 알려진 제약
- macOS 13.0+ 만 지원
- `.app` 번들은 ad-hoc 서명으로 배포됨. Gatekeeper 우회 필요 시 처음 실행 시 "마우스 우클릭 → 열기" 사용
- Developer ID 서명 / Notarization 은 별도 절차 필요

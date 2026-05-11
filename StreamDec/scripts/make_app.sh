#!/bin/bash
# StreamDec SPM 산출물을 .app 번들로 포장하는 스크립트
# 사용: ./scripts/make_app.sh [debug|release]

set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="StreamDec"
APP_BUNDLE="$ROOT/build/${APP_NAME}.app"

echo "▶ swift build ($CONFIG)"
cd "$ROOT"
swift build -c "$CONFIG"

BIN_PATH=$(swift build -c "$CONFIG" --show-bin-path)
EXEC="$BIN_PATH/$APP_NAME"

if [[ ! -x "$EXEC" ]]; then
    echo "✗ 실행 파일을 찾을 수 없음: $EXEC"
    exit 1
fi

echo "▶ .app 번들 구성 → $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXEC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/StreamDec/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# 리소스(Assets) 복사 (없으면 무시)
if [[ -d "$BIN_PATH/StreamDec_StreamDec.bundle" ]]; then
    cp -R "$BIN_PATH/StreamDec_StreamDec.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

echo "✓ 완성: $APP_BUNDLE"
echo "  실행: open \"$APP_BUNDLE\""

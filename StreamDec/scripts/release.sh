#!/bin/bash
# StreamDec 릴리즈 빌드 + .app 번들 + zip 패키징.
# 사용: ./scripts/release.sh
# 출력: build/StreamDec.app, build/StreamDec-x.y.z.zip

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="StreamDec"
PLIST="$ROOT/StreamDec/Resources/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "0.0.0")
APP_BUNDLE="$ROOT/build/${APP_NAME}.app"
ZIP_PATH="$ROOT/build/${APP_NAME}-${VERSION}.zip"

echo "▶ Release build (v$VERSION)"
cd "$ROOT"
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)
EXEC="$BIN_PATH/$APP_NAME"

echo "▶ App bundle → $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXEC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PLIST" "$APP_BUNDLE/Contents/Info.plist"

if [[ -d "$BIN_PATH/StreamDec_StreamDec.bundle" ]]; then
    cp -R "$BIN_PATH/StreamDec_StreamDec.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

# Ad-hoc 코드 서명 (개발자 ID 서명은 별도 단계)
codesign --force --sign - --timestamp=none "$APP_BUNDLE" || true

echo "▶ Zip → $ZIP_PATH"
rm -f "$ZIP_PATH"
( cd "$ROOT/build" && /usr/bin/ditto -c -k --keepParent "${APP_NAME}.app" "${APP_NAME}-${VERSION}.zip" )

echo "✓ 완료"
echo "  App:  $APP_BUNDLE"
echo "  Zip:  $ZIP_PATH"
echo "  설치: cp -R $APP_BUNDLE /Applications/"

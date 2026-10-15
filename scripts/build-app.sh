#!/bin/sh
# Builds "Get Caffeinated.app" into ./build (ad-hoc signed, for local use).
set -eu

cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/GetCaffeinated"

APP="build/Get Caffeinated.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/GetCaffeinated"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Icons/*.svg "$APP/Contents/Resources/"
cp Resources/Icons/LICENSE "$APP/Contents/Resources/Phosphor-LICENSE.txt"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

echo "Built $APP"

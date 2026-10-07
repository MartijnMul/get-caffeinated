#!/bin/sh
# Builds Caffeinated.app into ./build (ad-hoc signed, for local use).
set -eu

cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Caffeinated"

APP="build/Caffeinated.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Caffeinated"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Icons/*.svg "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

echo "Built $APP"

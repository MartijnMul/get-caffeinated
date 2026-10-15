#!/bin/sh
# Builds "Get Caffeinated.app" into ./build (ad-hoc signed, for local use).
# With --universal it builds for both Apple silicon and Intel, as a release
# needs; without, only for this Mac, which is faster.
set -eu

cd "$(dirname "$0")/.."

ARCHS=""
if [ "${1:-}" = "--universal" ]; then
    ARCHS="--arch arm64 --arch x86_64"
fi

# shellcheck disable=SC2086 # ARCHS is meant to split into separate flags
swift build -c release $ARCHS
# shellcheck disable=SC2086
BIN="$(swift build -c release $ARCHS --show-bin-path)/GetCaffeinated"

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

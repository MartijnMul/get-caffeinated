#!/bin/sh
# Builds "Get Caffeinated.app" into ./build, for local use.
# With --universal it builds for both Apple silicon and Intel, as a release
# needs; without, only for this Mac, which is faster.
#
# It signs with the first "Developer ID Application" certificate in the
# keychain (or SIGN_IDENTITY; "-" forces ad-hoc), and ad-hoc without one.
# "Awake with lid closed" needs a certificate: its helper daemon only talks to
# an app signed by the same team, so an ad-hoc build hides that option.
set -eu

cd "$(dirname "$0")/.."

ARCHS=""
if [ "${1:-}" = "--universal" ]; then
    ARCHS="--arch arm64 --arch x86_64"
fi

# The certificate goes by its SHA-1 hash: codesign fails to match a name with
# an accent in it, such as "Mullié" (decision 39).
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*) \([0-9A-F]\{40\}\) "Developer ID Application: .*"/\1/p' \
    | head -n 1)}"
IDENTITY="${IDENTITY:--}"

# shellcheck disable=SC2086 # ARCHS is meant to split into separate flags
swift build -c release $ARCHS
# shellcheck disable=SC2086
BIN_DIR="$(swift build -c release $ARCHS --show-bin-path)"

HELPER_LABEL="io.github.martijnmul.getcaffeinated.helper"
APP="build/Get Caffeinated.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"
cp "$BIN_DIR/GetCaffeinated" "$APP/Contents/MacOS/GetCaffeinated"
cp "$BIN_DIR/GetCaffeinatedHelper" "$APP/Contents/MacOS/GetCaffeinatedHelper"
cp "Resources/$HELPER_LABEL.plist" "$APP/Contents/Library/LaunchDaemons/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Icons/*.svg "$APP/Contents/Resources/"
cp Resources/Icons/LICENSE "$APP/Contents/Resources/Phosphor-LICENSE.txt"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# The helper first, with its own identifier: the app's signature seals it,
# and the app checks that identifier before it talks to the daemon.
codesign --force --options runtime --sign "$IDENTITY" \
    --identifier "$HELPER_LABEL" "$APP/Contents/MacOS/GetCaffeinatedHelper"
codesign --force --options runtime --sign "$IDENTITY" "$APP"

if [ "$IDENTITY" = "-" ]; then
    echo "Built $APP (ad-hoc signed: no Awake with lid closed)"
else
    echo "Built $APP (signed with $IDENTITY)"
fi

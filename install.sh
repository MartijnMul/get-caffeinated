#!/bin/sh
# Installs Get Caffeinated from the latest GitHub release:
#
#   curl -fsSL https://raw.githubusercontent.com/MartijnMul/get-caffeinated/main/install.sh | sh
#
# It downloads the disk image, copies the app to /Applications (replacing an
# older copy), and opens it. Nothing else. A download through curl is not
# marked as coming from the internet, so macOS does not ask to confirm the
# app, as it does for a disk image downloaded in a browser.
set -eu

URL="https://github.com/MartijnMul/get-caffeinated/releases/latest/download/Get-Caffeinated.dmg"
APP="/Applications/Get Caffeinated.app"

TMP="$(mktemp -d)"
cleanup() {
    hdiutil detach -quiet "$TMP/mount" 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Get Caffeinated..."
curl -fL --progress-bar -o "$TMP/Get-Caffeinated.dmg" "$URL"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$TMP/mount" "$TMP/Get-Caffeinated.dmg"

if pgrep -x GetCaffeinated >/dev/null; then
    osascript -e 'quit app "Get Caffeinated"'
    sleep 1
fi

rm -rf "$APP"
ditto "$TMP/mount/Get Caffeinated.app" "$APP"
open "$APP"

echo "Installed in /Applications. Look for the coffee bean in the menu bar."

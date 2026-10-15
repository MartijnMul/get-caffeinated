#!/bin/sh
# Packs a release disk image for GitHub Releases: a universal, ad-hoc signed
# app next to a shortcut to Applications. The name carries no version, so
# releases/latest/download/Get-Caffeinated.dmg always points at the newest
# one, which install.sh relies on. Downloaded in a browser, macOS asks to
# confirm the app once on first launch (see "Install" in the README).
set -eu

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="build/Get-Caffeinated.dmg"
STAGING="build/dmg"

./scripts/build-app.sh --universal
codesign --verify --strict "build/Get Caffeinated.app"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "build/Get Caffeinated.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "Get Caffeinated" -srcfolder "$STAGING" \
    -fs HFS+ -format UDZO "$DMG"
rm -rf "$STAGING"

echo "Packed $DMG, version $VERSION: attach it to release v$VERSION"
shasum -a 256 "$DMG"

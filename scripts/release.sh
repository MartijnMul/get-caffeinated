#!/bin/sh
# Packs a release disk image for GitHub Releases: a universal, ad-hoc signed
# app next to a shortcut to Applications, named after the version in
# Info.plist. The app is not notarised, so macOS asks to confirm it once on
# first launch (see "Install" in the README).
set -eu

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="build/Get-Caffeinated-$VERSION.dmg"
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

echo "Packed $DMG"
shasum -a 256 "$DMG"

#!/bin/sh
# Packs a release disk image for GitHub Releases: a universal app next to a
# shortcut to Applications. The name carries no version, so
# releases/latest/download/Get-Caffeinated.dmg always points at the newest
# one, which install.sh relies on.
#
# With a "Developer ID Application" certificate in the keychain, the app and
# the disk image are signed with it and notarised by Apple, so macOS opens the
# app after a single confirmation. Notarising needs credentials stored once
# with:
#
#   xcrun notarytool store-credentials notary
#
# Without the certificate the app stays ad-hoc signed, and macOS asks to
# confirm it under Privacy & Security on first launch (see "Install" in the
# README). SIGN_IDENTITY picks a certificate when there are several, and
# NOTARY_PROFILE a keychain profile other than "notary".
set -eu

cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
APP="build/Get Caffeinated.app"
DMG="build/Get-Caffeinated.dmg"
STAGING="build/dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
# The certificate goes by its SHA-1 hash: codesign fails to match a name with
# an accent in it, such as "Mullié".
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*) \([0-9A-F]\{40\}\) "Developer ID Application: .*"/\1/p' \
    | head -n 1)}"

./scripts/build-app.sh --universal

if [ -n "$IDENTITY" ]; then
    echo "Signing with $IDENTITY"
    # The hardened runtime and a secure timestamp are what notarisation asks
    # for; the app needs no entitlements on top.
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "Get Caffeinated" -srcfolder "$STAGING" \
    -fs HFS+ -format UDZO "$DMG"
rm -rf "$STAGING"

if [ -n "$IDENTITY" ]; then
    codesign --timestamp --sign "$IDENTITY" "$DMG"
    # Notarising the disk image covers the app inside it too. The ticket is
    # stapled to the disk image, so it opens without a lookup at Apple.
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
else
    echo "No Developer ID certificate found: the app is ad-hoc signed, not notarised"
fi

echo "Packed $DMG, version $VERSION: attach it to release v$VERSION"
shasum -a 256 "$DMG"

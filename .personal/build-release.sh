#!/bin/bash
# Builds, signs, verifies and packages the release in dist/. Needs VERSION, P12_BASE64, P12_PASSWORD,
# GH_TOKEN and GITHUB_REPOSITORY; refuses to ship under a signing identity other than the last one.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
W="$RUNNER_TEMP/release"
rm -rf "$W" dist && mkdir -p "$W" dist
KEYCHAIN="$W/signing.keychain-db"
KPW="$(openssl rand -base64 24)"
[ -n "${P12_BASE64:-}" ] || { echo "::error::the SIGNING_P12_BASE64 secret is not set (see .personal/SIGNING.md)"; exit 1; }
echo "$P12_BASE64" | base64 --decode > "$W/cert.p12"
security create-keychain -p "$KPW" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KPW" "$KEYCHAIN"
security import "$W/cert.p12" -k "$KEYCHAIN" -P "$P12_PASSWORD" -A -T /usr/bin/codesign > /dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KPW" "$KEYCHAIN" > /dev/null
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | sed 's/"//g')
/usr/bin/openssl pkcs12 -in "$W/cert.p12" -passin env:P12_PASSWORD -nokeys -clcerts 2> /dev/null \
  | /usr/bin/openssl x509 -outform der > "$W/identity.der"
rm -f "$W/cert.p12"
identity_sha="$(shasum -a 256 < "$W/identity.der" | cut -d' ' -f1)"

xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
  -derivedDataPath "$W/dd" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Tinycast Self-Signed" OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
  PRODUCT_NAME="Tinycast" TINYCAST_BUNDLE_IDENTIFIER="com.tinycast.app" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" build > "$W/build.log" 2>&1 \
  || { grep -E ': error: ' "$W/build.log" | head -40; tail -40 "$W/build.log"; exit 1; }
APP="$W/dd/Build/Products/Release/Tinycast.app"

# Apple silicon only, every shipped binary included: a thin helper in a mismatched app fails quietly.
while IFS= read -r binary; do
  slices="$(lipo -archs "$binary" 2> /dev/null || true)"
  [ -z "$slices" ] || [ "$slices" = arm64 ] || { echo "::error::${binary#$APP/}: $slices"; exit 1; }
done < <(find "$APP/Contents/MacOS" "$APP/Contents/Helpers" -type f -perm -u+x)
./Scripts/verify-signature.sh "$APP"
codesign -dvvv "$APP" 2>&1 | grep -qx "Authority=Tinycast Self-Signed" || { echo "::error::not signed by Tinycast Self-Signed"; exit 1; }
leaf_of() { # bundle -> sha256 of its leaf certificate
  local out; out="$(mktemp -d)"
  (cd "$out" && codesign -d --extract-certificates "$1" > /dev/null 2>&1)
  shasum -a 256 < "$out/codesign0" | cut -d' ' -f1
}
app_sha="$(leaf_of "$APP")"
[ "$app_sha" = "$identity_sha" ] || { echo "::error::the app is not signed with the SIGNING_P12 identity"; exit 1; }
# Installed copies update only to their own leaf, so a changed identity would strand every one.
previous="$(gh release list -R "$GITHUB_REPOSITORY" --limit 50 --json tagName,isDraft \
  -q '[.[] | select(.isDraft == false) | .tagName][0] // empty')"
if [ -n "$previous" ] && [ "${PERSONAL_DRY_RUN:-}" != 1 ]; then
  gh release download "$previous" -R "$GITHUB_REPOSITORY" --pattern 'Tinycast-*.zip' --dir "$W/previous"
  ditto -x -k "$W"/previous/*.zip "$W/previous/app"
  previous_sha="$(leaf_of "$W/previous/app/Tinycast.app")"
  [ "$previous_sha" = "$app_sha" ] || { echo "::error::$previous was signed with another certificate"; exit 1; }
  echo "same signing certificate as $previous"
fi
echo "$app_sha" > dist/signing-certificate.sha256

DMG="dist/Tinycast-$VERSION.dmg"
ZIP="dist/Tinycast-$VERSION.zip"
STAGE="$W/stage"
mkdir -p "$STAGE" && cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
diskutil image create from "$STAGE" --format UDZO --volumeName "Tinycast" "$DMG"
# Only `ditto` keeps the seal and symlinks the updater's signature check needs.
ditto -c -k --keepParent --sequesterRsrc "$APP" "$ZIP"

# Check what was packed, as the updater and a person dragging from the DMG will receive it.
ditto -x -k "$ZIP" "$W/unzipped"
UNZIPPED="$W/unzipped/Tinycast.app"
codesign --verify --deep --strict "$UNZIPPED"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$UNZIPPED/Contents/Info.plist")" = com.tinycast.app ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$UNZIPPED/Contents/Info.plist")" = "$VERSION" ]
[ "$(leaf_of "$UNZIPPED")" = "$app_sha" ]
hdiutil verify "$DMG" > /dev/null
MOUNT="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" > /dev/null
codesign --verify --deep --strict "$MOUNT/Tinycast.app"
hdiutil detach "$MOUNT" > /dev/null
# The signed app itself: it starts, and seals what an official install left in the clear.
.personal/tests/keychain-sandbox.sh .personal/tests/app-smoke.sh "$UNZIPPED"
(cd dist && shasum -a 256 "Tinycast-$VERSION.dmg" "Tinycast-$VERSION.zip" > "Tinycast-$VERSION.sha256")
ls -l dist

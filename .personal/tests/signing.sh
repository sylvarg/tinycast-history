#!/bin/bash
# Real signatures, on macOS only: Keychain access survives a re-signed update, another identity is
# refused, and the updater trusts only a bundle carrying the running app's own leaf certificate.
# Uses a throwaway keychain and two throwaway identities; restores the user's keychain list.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
W="${RUNNER_TEMP:-$(mktemp -d)}/signing-checks"
rm -rf "$W" && mkdir -p "$W/data"
KC="$W/probe.keychain-db"
KPW="$(openssl rand -hex 16)"
ORIGINAL_LIST=$(security list-keychains -d user | sed 's/"//g' | xargs)
ORIGINAL_DEFAULT=$(security default-keychain -d user | sed 's/"//g' | xargs)
restore() {
  security list-keychains -d user -s $ORIGINAL_LIST
  [ -n "$ORIGINAL_DEFAULT" ] && security default-keychain -d user -s "$ORIGINAL_DEFAULT"
  security delete-keychain "$KC" 2> /dev/null || true
}
trap restore EXIT
security create-keychain -p "$KPW" "$KC"
security set-keychain-settings -lut 3600 "$KC"
security unlock-keychain -p "$KPW" "$KC"
security list-keychains -d user -s "$KC" $ORIGINAL_LIST
security default-keychain -d user -s "$KC"

for id in A B; do
  # LibreSSL's PKCS#12 defaults are the ones `security import` reads.
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 2 -keyout "$W/$id.key" -out "$W/$id.pem" \
    -subj "/CN=Tinycast Probe $id" -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" -addext "extendedKeyUsage=critical,codeSigning" 2> /dev/null
  /usr/bin/openssl pkcs12 -export -inkey "$W/$id.key" -in "$W/$id.pem" -name "Tinycast Probe $id" \
    -out "$W/$id.p12" -passout pass:probe
  security import "$W/$id.p12" -k "$KC" -P probe -A -T /usr/bin/codesign > /dev/null || exit 1
done
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KPW" "$KC" > /dev/null

P=Tinycast/Platform
SOURCES=(Tinycast/Features/Updates/Service/BundleSignature.swift $P/SealedEnvelope.swift $P/SealedFile.swift
  $P/KeychainSecretStore.swift $P/AppPaths.swift Tests/personal-signature-probe.swift)
swiftc -swift-version 6 -Onone "${SOURCES[@]}" -o "$W/probe-v1" || exit 1
swiftc -swift-version 6 -O "${SOURCES[@]}" -o "$W/probe-v2" || exit 1
cp "$W/probe-v1" "$W/probe-foreign"
sign() { perl -e 'alarm shift; exec @ARGV' 60 codesign -f -s "Tinycast Probe $1" -i com.tinycast.probe --keychain "$KC" "$2" 2>&1 | grep -v "replacing existing signature" || true; }
sign A "$W/probe-v1"
sign A "$W/probe-v2"
sign B "$W/probe-foreign"
cmp -s "$W/probe-v1" "$W/probe-v2" && { echo "FAIL the update build must differ from the first"; exit 1; }

status=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; status=1; }
probe() { perl -e 'alarm shift; exec @ARGV' 30 "$@" 2>&1; }

[ "$(probe "$W/probe-v1" keychain write "$W/data")" = written ] && pass "creates its key and sealed file" \
  || fail "creates its key and sealed file"
[ "$(probe "$W/probe-v2" keychain read "$W/data")" = probe-secret ] \
  && pass "a re-signed update with the same identity reads the key without a prompt" \
  || fail "a re-signed update with the same identity reads the key without a prompt"
foreign="$(probe "$W/probe-foreign" keychain read "$W/data")"
case "$foreign" in
  *probe-secret*) fail "another identity read the key: $foreign" ;;
  *) pass "another identity is refused the key (${foreign:-killed waiting for a prompt})" ;;
esac
grep -qa probe-secret "$W/data/probe.enc" && fail "the sealed file holds plaintext" || pass "the file on disk is sealed"
[ "$(probe "$W/probe-v1" keychain erase "$W/data")" = erased ] && [ ! -e "$W/data/probe.enc" ] \
  && pass "erasing removes the file and the key" || fail "erasing removes the file and the key"
[ "$(probe "$W/probe-v1" keychain read "$W/data")" = absent ] && pass "after erase nothing is left" \
  || fail "after erase nothing is left"

bundle() { # name identity
  local app="$W/$1.app"
  mkdir -p "$app/Contents/MacOS"
  cp /usr/bin/true "$app/Contents/MacOS/Tinycast"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.tinycast.app" \
    -c "Add :CFBundleExecutable string Tinycast" -c "Add :CFBundleShortVersionString string 0.12.1-h.1" \
    "$app/Contents/Info.plist" > /dev/null
  codesign -f -s "Tinycast Probe $2" --keychain "$KC" "$app" 2> /dev/null
}
bundle Ours A
bundle Foreign B
[ "$(probe "$W/probe-v1" trust "$W/Ours.app")" = trusted ] && pass "the updater trusts its own signature" \
  || fail "the updater trusts its own signature"
[ "$(probe "$W/probe-v1" trust "$W/Foreign.app")" = refused ] && pass "the updater refuses a foreign signature" \
  || fail "the updater refuses a foreign signature"
[ "$(probe "$W/probe-v1" trust /System/Applications/Calculator.app)" = refused ] \
  && pass "the updater refuses an Apple-chained bundle that is not this edition" \
  || fail "the updater refuses an Apple-chained bundle that is not this edition"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 9.9.9" "$W/Ours.app/Contents/Info.plist"
[ "$(probe "$W/probe-v1" trust "$W/Ours.app")" = refused ] && pass "the updater refuses a tampered bundle" \
  || fail "the updater refuses a tampered bundle"
exit $status

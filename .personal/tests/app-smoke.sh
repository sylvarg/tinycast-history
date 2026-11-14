#!/bin/bash
# The built app itself, on a throwaway keychain: it starts, seals the plain calculator history and
# ranking an official install left behind (under the old bundle id), deletes them, and leaves no
# synthetic input readable.
# usage: app-smoke.sh <Tinycast.app>   (macOS; run inside keychain-sandbox.sh)
set -uo pipefail
APP="$1"
BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
EXEC="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
SUPPORT="$HOME/Library/Application Support/$BUNDLE"
MARKER="SMOKE-MARKER-$(openssl rand -hex 4)"
status=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; status=1; }
# Seeded where a copy from before the official 0.12.15 bundle id move kept them, when there is one.
SEED="$SUPPORT"
case "$BUNDLE" in
  com.abueammar.tinycast*) SEED="$HOME/Library/Application Support/com.tinycast.app${BUNDLE#com.abueammar.tinycast}" ;;
esac
for folder in "$SUPPORT" "$SEED"; do
  [ ! -e "$folder" ] || { echo "FAIL  $folder already exists; refusing to touch real data"; exit 1; }
done
mkdir -p "$SEED"
cleanup() {
  pkill -9 -f "$APP/Contents/MacOS/$EXEC" 2> /dev/null
  rm -rf "$SUPPORT" "$SEED"
}
trap cleanup EXIT
now=$(date +%s)
printf '[{"id":"6F1C2A44-0E5B-4C8E-9B1D-3A2F5E6D7C80","expression":"%s * 2","result":"4","createdAt":%s}]' \
  "$MARKER" "$((now - 978307200))" > "$SEED/calculator-history.json"
printf '{"app:/Applications/Safari.app":{"anchor":%s,"openedAt":%s,"searchTerms":["%s"]}}' \
  "$((now - 978307200 + 86400))" "$((now - 978307200))" "$(echo "$MARKER" | tr 'A-Z' 'a-z')" \
  > "$SEED/launcher-ranking.json"

"$APP/Contents/MacOS/$EXEC" > "${RUNNER_TEMP:-/tmp}/app-smoke.log" 2>&1 &
pid=$!
for _ in $(seq 60); do
  [ -e "$SUPPORT/calculator-history.enc" ] && [ -e "$SUPPORT/launcher-ranking.enc" ] \
    && [ ! -e "$SUPPORT/calculator-history.json" ] && [ ! -e "$SUPPORT/launcher-ranking.json" ] && break
  sleep 1
done
if [ "$SEED" != "$SUPPORT" ]; then
  [ ! -e "$SEED" ] && pass "what ${SEED##*/} left is moved to $BUNDLE" || fail "${SEED##*/} was not moved: $(ls "$SEED")"
fi
kill -0 "$pid" 2> /dev/null && pass "the app starts and keeps running" || fail "the app exited: $(tail -5 "${RUNNER_TEMP:-/tmp}/app-smoke.log")"
[ -e "$SUPPORT/calculator-history.enc" ] && [ ! -e "$SUPPORT/calculator-history.json" ] \
  && pass "the plain calculator history is sealed and removed" || fail "calculator history not migrated: $(ls "$SUPPORT")"
[ -e "$SUPPORT/launcher-ranking.enc" ] && [ ! -e "$SUPPORT/launcher-ranking.json" ] \
  && pass "the plain ranking is sealed and removed" || fail "ranking not migrated: $(ls "$SUPPORT")"
if grep -rqai "smoke-marker" "$SUPPORT"; then fail "a synthetic input is readable on disk"; else pass "nothing readable on disk"; fi
for file in "$SUPPORT"/*.enc; do
  [ "$(stat -f %Lp "$file")" = 600 ] || fail "${file##*/} is not private"
  [ "$(head -c 4 "$file")" = TCSE ] || fail "${file##*/} is not a sealed envelope"
done
security find-generic-password -s "$BUNDLE.sealed-storage-keys" > /dev/null 2>&1 \
  && pass "the keys are in the user's keychain" || fail "no key in the keychain"
exit $status

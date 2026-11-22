#!/bin/bash
# The personal edition's own checks, all blocking: a harness that fails, crashes, hangs, does not
# compile or is missing fails the run. Usage: .personal/tests/run.sh [harness-name]
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
BIN="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/personal-tests"
mkdir -p "$BIN"
only="${1:-}"
failed=()
ran=0

L=Tinycast/Features/Launcher/Model
LH=Tinycast/Features/LauncherHistory
P=Tinycast/Platform

harness() {
  local name=$1; shift
  [ -z "$only" ] || [ "$only" = "$name" ] || return 0
  ran=$((ran + 1))
  if [ ! -f "Tests/$name.swift" ]; then echo "FAIL  $name: harness missing"; failed+=("$name"); return; fi
  if ! swiftc -swift-version 6 -Onone "$@" "Tests/$name.swift" -o "$BIN/$name" > "$BIN/$name.compile.log" 2>&1; then
    echo "FAIL  $name: did not compile"; cat "$BIN/$name.compile.log"; failed+=("$name"); return
  fi
  # macOS ships no `timeout`; perl's alarm kills a wedged harness, which then counts as failed.
  perl -e 'alarm shift; exec @ARGV' 180 "$BIN/$name" > "$BIN/$name.log" 2>&1
  local status=$?
  if [ $status -ne 0 ] || ! grep -qE '^[0-9]+ passed, 0 failed$' "$BIN/$name.log"; then
    echo "FAIL  $name (exit $status)"; cat "$BIN/$name.log"; failed+=("$name"); return
  fi
  echo "ok    $name: $(tail -n1 "$BIN/$name.log")"
}

check() {
  local name=$1; shift
  [ -z "$only" ] || [ "$only" = "$name" ] || return 0
  ran=$((ran + 1))
  if out=$("$@" 2>&1); then echo "ok    $name"; else echo "FAIL  $name"; echo "$out"; failed+=("$name"); fi
}

harness launcher-history-test $LH/Model/*.swift
harness sealed-storage-test $P/SealedEnvelope.swift $P/SealedFile.swift $P/KeychainSecretStore.swift \
  $P/AppPaths.swift $P/Memo.swift $LH/Model/LauncherHistory.swift \
  $L/SearchRelevance.swift $L/ScriptRomanization.swift $L/LauncherMatch.swift $L/LauncherRankingStore.swift \
  Tinycast/Features/Calculator/Service/CalculatorHistoryStore.swift
harness personal-edition-test Tinycast/Features/Updates/Model/*.swift

check model-purity bash -c '! grep -rln "import AppKit\|import SwiftUI\|import Cocoa" Tinycast/Features/*/Model/'
check strings python3 .personal/tests/check-strings.py
check house-style .personal/tools/style.sh "$(cat .personal/UPSTREAM)"
check backup-privacy bash -c '
  f=Tinycast/Features/Backup/Service/BackupComposer.swift
  ! grep -q "learning\[\.calculator\]" "$f" && grep -q "searchTerms: \[\]" "$f"'
check hooks .personal/tests/check-hooks.sh

if [ -n "$only" ] && [ "$ran" -eq 0 ]; then echo "FAIL  no check named $only"; exit 1; fi
if [ ${#failed[@]} -gt 0 ]; then echo "FAILED: ${failed[*]}"; exit 1; fi
echo "personal checks: $ran passed"

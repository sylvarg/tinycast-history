#!/bin/bash
# Build + tests, as the sync, the release and the branch CI run them. Every personal check is
# blocking. An upstream harness may fail only if it also fails on the pristine upstream commit.
# Usage: .personal/gate.sh <upstream-sha> [--release]
set -uo pipefail
UP="${1:?upstream sha}"
cd "$(git rev-parse --show-toplevel)" || exit 2
TMP="${RUNNER_TEMP:-$(mktemp -d)}"
failures=()

step() { echo "::group::$1"; }
done_step() { echo "::endgroup::"; }

step "xcodegen"
xcodegen generate --quiet || { echo "::error::xcodegen failed"; exit 1; }
done_step

step "Debug build"
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug \
  -derivedDataPath "$TMP/gate-dd" CODE_SIGNING_ALLOWED=NO build > "$TMP/gate-build.log" 2>&1
build=$?
done_step
# Upstream builds without a single warning in its own sources, so any warning here is new.
warnings=$(grep -E '^/.*/Tinycast/.*: warning: ' "$TMP/gate-build.log" | sort -u)
# The block's cause: the failed checks, plus the first errors with paths and lines stripped.
report() { # failed-checks details-file
  local errors
  errors=$(sed -E 's#^/[^:]*/##; s#:[0-9]+:[0-9]+:#:#' "$2" 2> /dev/null | head -5)
  printf '%s %s' "$1" "$(printf '%s' "$errors" | shasum | cut -c1-12)" > "$TMP/gate-cause.txt"
  { echo "Failed checks: \`$1\`"; echo; echo '```'; head -80 "$2" 2> /dev/null; echo '```'; } > "$TMP/gate-report.md"
}

if [ $build -ne 0 ]; then
  grep -E ': error: ' "$TMP/gate-build.log" | sort -u | head -60 | tee "$TMP/gate-errors.txt"
  tail -40 "$TMP/gate-build.log"
  report build "$TMP/gate-errors.txt"
  echo "::error::the Debug build failed"
  exit 1
fi
if [ -n "$warnings" ]; then echo "$warnings"; echo "::error::the build has warnings"; failures+=(warnings); fi

step "Lint"
./Scripts/lint.sh 2>&1 | tee "$TMP/gate-lint.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || failures+=(lint)
# Upstream tolerates lint warnings; none may point at a file this edition adds or changes.
ours=$(git diff --name-only "$UP" -- '*.swift'; git ls-files --others --exclude-standard -- '*.swift')
for file in $ours; do
  grep -F "/$file:" "$TMP/gate-lint.log" | grep -F "warning:" && failures+=("lint-warning:$file")
done
done_step

step "Personal checks"
.personal/tests/keychain-sandbox.sh .personal/tests/run.sh 2>&1 | tee "$TMP/gate-personal.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || failures+=(personal-checks)
done_step

step "Signing and Keychain checks"
.personal/tests/signing.sh 2>&1 | tee "$TMP/gate-signing.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || failures+=(signing-checks)
done_step

step "Upstream harnesses"
./Scripts/run-tests.sh > "$TMP/gate-tests.log" 2>&1
upstream=$?
done_step
cat "$TMP/gate-tests.log" | tail -60
failed=$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/gate-tests.log" | sed -n 's/.*harness(es) failed in [0-9]*s: //p')
if [ $upstream -ne 0 ] && [ -z "$failed" ]; then
  echo "::error::run-tests.sh failed without naming a harness"; failures+=(upstream-runner)
fi
regressions=()
if [ -n "$failed" ]; then
  wt="$TMP/gate-upstream"
  git worktree add --force --detach "$wt" "$UP" > /dev/null || exit 2
  for t in $failed; do
    # Upstream's timing-based harnesses miss on a loaded runner: blame this edition only for a
    # harness that fails every retry here and passes every run on the pristine upstream commit.
    ours=0
    for _ in 1 2 3; do ./Scripts/run-tests.sh "$t" > /dev/null 2>&1 && { ours=1; break; }; done
    if [ $ours = 1 ]; then echo "::warning::$t is flaky: failed in the full run, passed on a retry"; continue; fi
    pristine=1
    for _ in 1 2 3; do (cd "$wt" && ./Scripts/run-tests.sh "$t" > /dev/null 2>&1) || { pristine=0; break; }; done
    if [ $pristine = 1 ]; then regressions+=("$t"); else
      echo "::warning::$t fails on pristine upstream ${UP:0:7} too — upstream's, not this edition's"
    fi
  done
  git worktree remove --force "$wt"
fi
[ ${#regressions[@]} -eq 0 ] || { echo "::error::upstream harnesses broken: ${regressions[*]}"; failures+=(upstream-regressions); }

if [ ${#failures[@]} -gt 0 ]; then
  { echo "$warnings"; grep -hE '^FAIL|error' "$TMP/gate-lint.log" "$TMP/gate-personal.log" "$TMP/gate-signing.log" 2> /dev/null
    printf '%s\n' "${regressions[@]:-}"; } > "$TMP/gate-errors.txt"
  report "${failures[*]}" "$TMP/gate-errors.txt"
  echo "::error::gate failed: ${failures[*]}"
  exit 1
fi
echo "gate passed"

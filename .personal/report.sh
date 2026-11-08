#!/bin/bash
# The automation's blocked state, without issues: one file per kind (sync, release) on the
# `personal-status` branch, and the details in the run's summary.
#   report.sh blocked <kind> <title>                   exit 0 when exactly this block is recorded
#   report.sh open <kind> <title> [<details.md> [<cause>]]   record it; exit 1 only for a new cause,
#                                                      so GitHub's failed-run email arrives once per cause
#   report.sh close <kind>                             clear it once a run goes through
# Needs GH_TOKEN with contents: write, and GITHUB_REPOSITORY.
set -euo pipefail
action="$1" kind="$2"
BRANCH=personal-status
run="${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/runs/${GITHUB_RUN_ID:-0}"
remote="${PERSONAL_STATUS_REMOTE:-https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git -C "$work" init -q
if git -C "$work" fetch -q --depth 1 "$remote" "refs/heads/$BRANCH" 2> /dev/null; then
  git -C "$work" checkout -q FETCH_HEAD
else
  git -C "$work" symbolic-ref HEAD "refs/heads/$BRANCH"
fi
file="$work/$kind.md"
recorded_title="$(sed -n '1s/^# //p' "$file" 2> /dev/null || true)"
recorded_cause="$(sed -n 's/^<!-- cause: \(.*\) -->$/\1/p' "$file" 2> /dev/null || true)"

publish() {
  git -C "$work" add -A
  git -C "$work" diff --cached --quiet && return 0
  git -C "$work" -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" commit -qm "$1"
  git -C "$work" push -q "$remote" "HEAD:refs/heads/$BRANCH"
}

case "$action" in
  blocked)
    [ -n "$recorded_title" ] && [ "$recorded_title" = "$3" ]
    ;;
  open)
    title="$3" details="${4:-}" cause="${5:-$3}"
    {
      echo "# $title"
      echo
      echo "Nothing was published: \`main\` and the releases stay as they were. [Run log]($run)."
      echo
      [ -n "$details" ] && [ -f "$details" ] && cat "$details" && echo
      echo "<!-- cause: $cause -->"
    } > "$file"
    cat "$file" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    publish "blocked: $title"
    if [ "$cause" = "$recorded_cause" ]; then
      echo "::warning::$title — same cause as already reported, so no new alert (see $kind.md on $BRANCH)"
      exit 0
    fi
    echo "::error::$title — details in this run's summary and in $kind.md on the $BRANCH branch"
    exit 1
    ;;
  close)
    [ -f "$file" ] || exit 0
    git -C "$work" rm -q "$kind.md"
    publish "resolved: $kind"
    echo "::notice::the earlier $kind block is resolved by $run"
    ;;
esac

#!/bin/bash
# One open issue per blocked kind (sync or release). `report.sh open <kind> <title> [<details.md> <cause>]`
# creates or updates it, `report.sh close <kind>` closes it once a run goes through again.
# The same cause on a newer upstream only retitles the issue, so a conflict notifies once.
set -euo pipefail
action="$1" kind="$2" label="personal-$2"
run="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
gh label create "$label" --color d93f0b --description "personal edition automation" --force > /dev/null
num=$(gh issue list --label "$label" --state open --json number -q '.[0].number // empty')
if [ "$action" = open ]; then
  title="$3" details="${4:-}" cause="${5:-}"
  body="$title — see [the run log]($run). Nothing was published: \`main\` and the releases stay as they were until the cause in \`.personal/\` is fixed."
  [ -n "$details" ] && [ -f "$details" ] && body="$body"$'\n\n'"$(cat "$details")"
  [ -n "$cause" ] && body="$body"$'\n\n'"<!-- cause: $cause -->"
  if [ -n "$num" ] && [ -n "$cause" ] && gh issue view "$num" --json body -q .body | grep -qxF "<!-- cause: $cause -->"; then
    gh issue edit "$num" --title "$title" > /dev/null
  elif [ -n "$num" ]; then
    gh issue edit "$num" --title "$title" --body "$body" > /dev/null
    gh issue comment "$num" --body "A different cause blocks it now — see [this run]($run)."
  else
    gh issue create --title "$title" --label "$label" --body "$body"
  fi
elif [ -n "$num" ]; then
  gh issue close "$num" --comment "Resolved: [this run]($run) went through."
fi

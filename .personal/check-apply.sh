#!/bin/bash
# apply.sh's patch loop as a dry run on a throwaway worktree, with no Xcode project: the Linux
# check can tell a conflict before a macOS runner is spent on it.
# usage: check-apply.sh <upstream-ref> <last-built-upstream-sha> <report.md>
# Exit 0 when every patch applies; otherwise print the cause and write the report.
set -uo pipefail
UP="$1" BUILT="$2" REPORT="$3"
COMMITS="https://github.com/abue-ammar/tinycast/commit"
SRC="$(git rev-parse --show-toplevel)"
WT="$(mktemp -d)"
git worktree add -q --detach "$WT" "$UP" || exit 2
trap 'git -C "$SRC" worktree remove --force "$WT"' EXIT
cd "$WT" || exit 2
UP="$(git rev-parse HEAD)"

for patch in "$SRC"/.personal/patches/*.patch; do
  name="$(basename "$patch" .patch)"
  if out="$(git apply --3way --whitespace=nowarn "$patch" 2>&1)"; then
    git add -A && git -c user.name=check -c user.email=check@localhost commit -qm "$name" --no-verify
    continue
  fi
  files="$(git diff --name-only --diff-filter=U)"
  [ -n "$files" ] || files="$(grep -oE "^error: (patch failed: [^:]+|[^:]+: (does not exist in index|already exists in working directory|No such file or directory))" <<< "$out" \
    | sed -E 's/^error: (patch failed: )?//; s/: (does not exist in index|already exists in working directory|No such file or directory)$//' | sort -u)"
  echo "$name: $(echo $files)"
  {
    echo "**\`$name\`** no longer applies to upstream [\`${UP:0:7}\`]($COMMITS/$UP): $(sed 's/.*/`&`/' <<< "$files" | paste -sd, - | sed 's/,/, /g')."
    echo
    if [ -n "$BUILT" ] && git cat-file -e "$BUILT^{commit}" 2> /dev/null && [ -n "$files" ]; then
      touched="$(git log --format="- [\`%h\`]($COMMITS/%H) %s" "$BUILT..$UP" -- $files)"
      if [ -n "$touched" ]; then
        echo "Upstream commits since the last built upstream [\`${BUILT:0:7}\`]($COMMITS/$BUILT) that touch it:"
        echo
        echo "$touched"
        echo
        echo "If one of them ships what the patch does, drop the patch and its README row; otherwise redo the hunk on top of it (see \`.personal/README.md\`, *Updating a patch*)."
      else
        echo "No upstream commit since [\`${BUILT:0:7}\`]($COMMITS/$BUILT) touches it, so an earlier patch of this edition moved the lines."
      fi
      echo
    fi
    echo "<details><summary>Where it stops</summary>"
    echo
    echo '```diff'
    if [ -n "$(git diff --name-only --diff-filter=U)" ]; then git diff -- $files | head -n 150; else head -n 40 <<< "$out"; fi
    echo '```'
    echo
    echo "</details>"
  } > "$REPORT"
  exit 1
done

#!/bin/bash
# Applies .personal/patches onto a pristine upstream checkout, in name order, then the rewrites.
# --3way falls back to a merge when context drifted, so only a real conflict fails.
# PERSONAL_COMMIT=1 (the workflows): each patch becomes its own commit, carrying the Xcode project
# it needs regenerated. PERSONAL_REFRESH=1 as well (the sync): each patch is then re-cut from its
# commit, so the patches on main name today's upstream blobs and the next --3way can merge.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# The project is generated from project.yml; a patch that adds a source never patches project.pbxproj.
derive() {
  if [ -n "$(git status --porcelain --untracked-files=all -- Tinycast Tests | grep -E '^(\?\?|A ) ' || true)" ] \
    || ! git diff --quiet HEAD -- project.yml; then
    if command -v xcodegen > /dev/null; then
      xcodegen generate --quiet
    elif [ "${PERSONAL_COMMIT:-}" = 1 ]; then
      echo "xcodegen is required to commit the patches" >&2
      exit 1
    fi
  fi
}

# Subject from the file name, body from the patch's row in .personal/README.md.
commit_patch() {
  local name="${1##*/}" body
  name="${name%.patch}"
  body="$(grep -F "| \`patches/$name.patch\` |" .personal/README.md | sed -E 's/^\| `[^`]+` \| (.*) \|$/\1/' || true)"
  git add -A -- . ':(exclude).personal' ':(exclude,glob).github/workflows/personal-*.yml'
  git commit -q -m "personal ${name%%-*}: $(echo "${name#*-}" | tr '-' ' ')" ${body:+-m "$body"}
}

refresh_patch() {
  git diff --no-color --binary --full-index HEAD~1 HEAD -- . ':(exclude)Tinycast.xcodeproj' > "$1"
}

for patch in .personal/patches/*.patch; do
  echo "applying ${patch##*/}"
  git apply --3way --whitespace=nowarn "$patch"
  if [ "${PERSONAL_COMMIT:-}" = 1 ]; then
    derive
    commit_patch "$patch"
    if [ "${PERSONAL_REFRESH:-}" = 1 ]; then refresh_patch "$patch"; fi
  fi
done
[ "${PERSONAL_COMMIT:-}" = 1 ] || derive

# Rewrites rather than hunks, so an upstream that moves these lines never conflicts with a patch.
# Upstream's releases page (the Changelog menu item and whatever comes next) points here.
{ grep -rlF --include='*.swift' 'github.com/abue-ammar/tinycast/releases' Tinycast || true; } | while read -r file; do
  sed -i.bak 's#github\.com/abue-ammar/tinycast/releases#github.com/sylvarg/tinycast-history/releases#g' "$file"
  rm -f "$file.bak"
done

# Upstream's own workflows publish its site, releases and announcements, triage its issues and
# mirror it; none of that belongs here, so only this edition's workflows are kept.
find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) ! -name 'personal-*' -delete

# The edition's README; upstream's is kept verbatim beside it, marked as the original project's.
{
  printf '%s\n\n' "> **This is the original Tinycast README, kept verbatim.** Its install instructions, links and contact details belong to [abue-ammar/tinycast](https://github.com/abue-ammar/tinycast), not to this personal edition — see the edition's [README](README.md)."
  cat README.md
} > README.upstream.md
cp .personal/README.edition.md README.md

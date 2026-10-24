#!/bin/bash
# Publishes dist/ as v$VERSION: a new tag on the generated source commit (never moved), a draft with
# every asset, then the switch to published and latest. A run that dies leaves at most a draft.
# Needs VERSION, TAG, UP, SOURCE, MAIN, PATCHES, GH_TOKEN, GITHUB_REPOSITORY, UPSTREAM_REPO.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
NEW="v$VERSION"
REPO="$GITHUB_REPOSITORY"
if [ -n "$(git ls-remote --tags origin "refs/tags/$NEW")" ]; then
  echo "::error::$NEW already exists; tags are never moved, the next run takes the next revision"
  exit 1
fi
notes="$RUNNER_TEMP/notes.md"
# Bare #123 would resolve against this repository, so they become links to the original project.
upstream_notes="$(gh release view "$TAG" -R "$UPSTREAM_REPO" --json body -q .body \
  | sed '/<!-- tinycast:install -->/,$d' \
  | perl -pe 's{(^|[\s(])#(\d+)\b}{$1\[#$2\](https://github.com/abue-ammar/tinycast/pull/$2)}g')"
{
  echo "**Tinycast $VERSION — personal edition with history** (unofficial). It rebuilds the official [Tinycast ${TAG#v}](https://github.com/$UPSTREAM_REPO/releases/tag/$TAG) and adds ↑ recall of launcher inputs with encrypted local history."
  echo
  echo "| | |"
  echo "| --- | --- |"
  echo "| Official base | [\`$TAG\`](https://github.com/$UPSTREAM_REPO/releases/tag/$TAG) · [\`${UP:0:7}\`](https://github.com/$UPSTREAM_REPO/commit/$UP) |"
  echo "| Personal revision | \`h.${VERSION##*-h.}\` |"
  echo "| Source of this build | [\`${SOURCE:0:7}\`](https://github.com/$REPO/commit/$SOURCE) (tag \`$NEW\`), from main [\`${MAIN:0:7}\`](https://github.com/$REPO/commit/$MAIN) |"
  echo "| Patches | [\`.personal/patches\`](https://github.com/$REPO/tree/$NEW/.personal/patches) |"
  echo
  echo "Changes in the official release:"
  echo
  echo "$upstream_notes"
  echo
  echo "<!-- tinycast:install -->"
  echo "Download \`Tinycast-$VERSION.dmg\` and drag Tinycast to Applications, replacing the official copy; settings and data are kept. The build is self-signed, so clear the quarantine once: \`xattr -dr com.apple.quarantine /Applications/Tinycast.app\`, then grant Accessibility again (System Settings › Privacy & Security). Installed copies of this edition update themselves from this repository. Checksums: \`Tinycast-$VERSION.sha256\`; signing certificate SHA-256: \`$(cat dist/signing-certificate.sha256)\`."
  echo
  echo "<!-- personal-content: $PATCHES -->"
} > "$notes"

git tag "$NEW" "$SOURCE"
git push origin "refs/tags/$NEW"
for draft in $(gh release list -R "$REPO" --limit 200 --json tagName,isDraft -q ".[] | select(.isDraft and .tagName == \"$NEW\") | .tagName"); do
  gh release delete "$draft" -R "$REPO" -y
done
gh release create "$NEW" -R "$REPO" --draft --verify-tag \
  --title "Tinycast $VERSION · personal edition with history" --notes-file "$notes" \
  "dist/Tinycast-$VERSION.zip" "dist/Tinycast-$VERSION.dmg" "dist/Tinycast-$VERSION.sha256"
assets="$(gh release view "$NEW" -R "$REPO" --json assets -q '[.assets[].name] | sort | join(" ")')"
expected="Tinycast-$VERSION.dmg Tinycast-$VERSION.sha256 Tinycast-$VERSION.zip"
[ "$assets" = "$expected" ] || { echo "::error::draft holds '$assets', expected '$expected'"; exit 1; }
gh release edit "$NEW" -R "$REPO" --draft=false --latest
echo "published https://github.com/$REPO/releases/tag/$NEW"

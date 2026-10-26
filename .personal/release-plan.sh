#!/bin/bash
# What the release workflow builds, as GitHub outputs: tag (empty when nothing to do), version and
# content. The content is the tree the patches produce on the official tag, so a patch re-cut by the
# sync changes nothing, while a real change to the edition earns the next -h.N of the same base.
# usage: release-plan.sh [official-tag]   (needs GH_TOKEN, GITHUB_REPOSITORY, UPSTREAM_REPO, UPSTREAM)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
REPO="$GITHUB_REPOSITORY"
requested="${1:-}"
tag="${requested:-$(gh release view -R "$UPSTREAM_REPO" --json tagName -q .tagName)}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "::error::not an official stable tag: $tag" >&2; exit 1; }
state="$(gh release view "$tag" -R "$UPSTREAM_REPO" --json isDraft,isPrerelease -q '"\(.isDraft) \(.isPrerelease)"')"
[ "$state" = "false false" ] || { echo "::error::$tag is not a published stable release upstream" >&2; exit 1; }
base="${tag#v}"

git fetch -q --no-tags "$UPSTREAM" "refs/tags/$tag:refs/upstream-tags/$tag"
wt="$(mktemp -d)"
git worktree add -q --detach "$wt" "refs/upstream-tags/$tag"
trap 'git worktree remove --force "$wt"' EXIT
cp -R .personal "$wt/"
(cd "$wt" && .personal/apply.sh > /dev/null && git add -A)
# What ships, as a tree: a README, doc or workflow edit never earns a new app version, and the Xcode
# project only differs by being regenerated on macOS.
shipped() {
  local index
  index="$(mktemp)"
  GIT_INDEX_FILE="$index" git read-tree "$1"
  GIT_INDEX_FILE="$index" git rm -r -q -f --cached --ignore-unmatch -- \
    .personal .github docs README.md README.fr.md README.upstream.md Tinycast.xcodeproj
  GIT_INDEX_FILE="$index" git write-tree
  rm -f "$index"
}
content="$(shipped "$(git -C "$wt" write-tree)")"

head="$(git rev-parse --short=7 HEAD)"
if [ -z "$requested" ] && .personal/report.sh blocked release "Release blocked: $tag + main $head"; then
  echo "::notice::$tag with main $head is already reported as blocked" >&2
  echo "tag="; exit 0
fi
published="$(gh release list -R "$REPO" --limit 200 --json tagName,isDraft \
  -q ".[] | select(.isDraft == false) | .tagName" | grep -E "^v${base//./\\.}-h\.[0-9]+$" || true)"
for existing in $published; do
  git fetch -q --no-tags origin "refs/tags/$existing:refs/tags/$existing"
  if [ "$(shipped "$existing^{tree}")" = "$content" ]; then
    echo "::notice::$existing already ships this content on $tag" >&2
    echo "tag="; exit 0
  fi
done
# Every tag ever pushed counts, published or not: a number is never reused and a tag never moved.
last="$(git ls-remote --tags origin "refs/tags/v$base-h.*" | sed -E 's#.*refs/tags/v[^-]+-h\.([0-9]+).*#\1#' \
  | sort -n | tail -n1)"
version="$base-h.$(( ${last:-0} + 1 ))"
echo "::notice::building $version from $tag (content $content)" >&2
echo "tag=$tag"
echo "version=$version"
echo "patches=$content"

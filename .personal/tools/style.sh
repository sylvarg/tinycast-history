#!/bin/bash
# House rules nothing lints: code within 110 columns, comments within 100, never two in a row.
# Checks the personal edition's own Swift files and the lines its patches add to upstream's.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
base="${1:-$(cat .personal/UPSTREAM 2>/dev/null || echo HEAD)}"
status=0
check() { # file, line number, text, previous-was-comment
  local file=$1 n=$2 text=$3
  local trimmed="${text#"${text%%[![:space:]]*}"}"
  if [[ "$trimmed" == //* ]]; then
    [ ${#text} -le 100 ] || { echo "$file:$n: comment over 100 columns"; status=1; }
  else
    [ ${#text} -le 110 ] || { echo "$file:$n: line over 110 columns"; status=1; }
  fi
}
while IFS= read -r file; do
  n=0; prev=0
  while IFS= read -r line; do
    n=$((n + 1)); check "$file" "$n" "$line"
    if [[ "${line#"${line%%[![:space:]]*}"}" == //* ]]; then
      [ $prev -eq 0 ] || { echo "$file:$n: two comment lines in a row"; status=1; }; prev=1
    else prev=0; fi
  done < "$file"
done < <(git diff --name-only --diff-filter=A "$base" -- 'Tinycast/*.swift' 'Tests/*.swift'; git ls-files --others --exclude-standard -- 'Tinycast/*.swift' 'Tests/*.swift')
# Lines added to upstream files.
git diff -U0 "$base" --diff-filter=M -- 'Tinycast/*.swift' | awk '
  /^\+\+\+ b\// { file = substr($0, 7) }
  /^@@/ { split($3, a, ","); n = substr(a[1], 2) - 1 }
  /^\+[^+]/ || /^\+$/ { n++; line = substr($0, 2); t = line; sub(/^[ \t]+/, "", t)
    limit = (t ~ /^\/\//) ? 100 : 110
    if (length(line) > limit) { print file ":" n ": added line over " limit " columns"; bad = 1 } }
  END { exit bad }' || status=1
exit $status

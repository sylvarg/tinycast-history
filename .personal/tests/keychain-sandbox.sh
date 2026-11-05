#!/bin/bash
# Runs a command with a throwaway, unlocked default keychain, so tests never touch the login one.
set -uo pipefail
dir="$(mktemp -d)"
keychain="$dir/tests.keychain-db"
password="$(openssl rand -hex 16)"
original_list=$(security list-keychains -d user | sed 's/"//g' | xargs)
original_default=$(security default-keychain -d user | sed 's/"//g' | xargs)
restore() {
  security list-keychains -d user -s $original_list
  [ -n "$original_default" ] && security default-keychain -d user -s "$original_default"
  security delete-keychain "$keychain" 2> /dev/null
  rm -rf "$dir"
}
trap restore EXIT
security create-keychain -p "$password" "$keychain" || exit 2
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$password" "$keychain" || exit 2
security list-keychains -d user -s "$keychain" $original_list
security default-keychain -d user -s "$keychain"
"$@"

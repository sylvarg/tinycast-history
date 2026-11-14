#!/bin/bash
# Selects the newest released Xcode on the runner: real folders only, since an image's Xcode_N.app
# symlink can point at a beta or RC.
set -euo pipefail
XCODE_PATH="$(find -E /Applications -maxdepth 1 -type d -regex '.*/Xcode_[0-9]+(\.[0-9]+)*\.app' | sort -V | tail -n1)"
if [ -z "$XCODE_PATH" ]; then
  echo "::error::no released Xcode on this runner:"; ls /Applications | grep -i xcode || true; exit 1
fi
echo "Using $XCODE_PATH (installed: $(ls /Applications | grep -i '^xcode' | paste -sd' ' -))"
echo "DEVELOPER_DIR=$XCODE_PATH/Contents/Developer" >> "$GITHUB_ENV"

#!/usr/bin/env bash
set -euo pipefail

read -r xcode_version < .xcode-version
export DEVELOPER_DIR="/Applications/Xcode_${xcode_version}.app/Contents/Developer"
xcodebuild -version

for platform in iphoneos iphonesimulator; do
  sdk_version=$(xcrun --sdk "$platform" --show-sdk-version)
  if [[ "$sdk_version" != "$xcode_version" ]]; then
    printf 'Expected %s SDK %s, found %s\n' "$platform" "$xcode_version" "$sdk_version" >&2
    exit 1
  fi
  printf '%s SDK %s\n' "$platform" "$sdk_version"
done

printf 'DEVELOPER_DIR=%s\nIOS_SDK_VERSION=%s\n' "$DEVELOPER_DIR" "$xcode_version" >> "$GITHUB_ENV"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-}"
if [[ -z "$device" ]]; then
  echo 'Usage: Scripts/run-simulator.sh SIMULATOR_UDID [--benchmark | --replay]'
  xcrun simctl list devices available
  exit 1
fi
shift
derived="${DOTLAB_DERIVED_DATA:-/tmp/dotlab-derived}"
xcodebuild -project DotLab.xcodeproj -scheme DotLab -configuration Release \
  -destination "platform=iOS Simulator,id=$device" -derivedDataPath "$derived" \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$device" -b
xcrun simctl install "$device" "$derived/Build/Products/Release-iphonesimulator/DotLab.app"
xcrun simctl launch --terminate-running-process "$device" com.alperkaratas.dotlab "$@"

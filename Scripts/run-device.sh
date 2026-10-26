#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -lt 2 ]]; then
  echo 'Usage: Scripts/run-device.sh IPHONE_UDID TEAM_ID [--standard]'
  exit 1
fi
device="$1"
team="$2"
shift 2
derived="${DOTLAB_DERIVED_DATA:-/tmp/dotlab-device}"
xcodebuild -project DotLab.xcodeproj -scheme DotLab -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$derived" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$team" build
xcrun devicectl device install app --device "$device" \
  "$derived/Build/Products/Release-iphoneos/DotLab.app"
xcrun devicectl device process launch --device "$device" --terminate-existing \
  com.alperkaratas.dotlab --benchmark "$@"
echo 'Benchmark launched. Keep DotLab foregrounded. Export from its Benchmark workspace when complete.'

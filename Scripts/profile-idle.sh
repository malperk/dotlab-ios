#!/bin/bash
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo 'Usage: Scripts/profile-idle.sh IPHONE_UDID MODE OUTPUT.trace'
  exit 1
fi
case "$2" in
  continuous|sleep|activeAoS|activeSoA) ;;
  *) echo 'Unknown simulation mode'; exit 1 ;;
esac
device="$1"
mode="$2"
output="$3"
xcrun devicectl device process launch --device "$device" --terminate-existing \
  com.alperkaratas.dotlab --mode "$mode" --count 50000 --keep-awake
xcrun xctrace record --template 'Power Profiler' --device "$device" \
  --attach DotLab --time-limit 60s --output "$output"

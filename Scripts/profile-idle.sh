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
launch_output=$(mktemp -t dotlab-profile)
cleanup() {
  rm -f -- "$launch_output"
  # End the profiling-only keep-awake session even when Instruments fails.
  xcrun devicectl device process launch --device "$device" --terminate-existing \
    com.alperkaratas.dotlab >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun devicectl device process launch --device "$device" --terminate-existing \
  --json-output "$launch_output" com.alperkaratas.dotlab --mode "$mode" --count 50000 --keep-awake
process_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["result"]["process"]["processIdentifier"])' "$launch_output")
sleep 2
xcrun xctrace record --template 'Power Profiler' --device "$device" \
  --attach "$process_id" --time-limit 60s --output "$output"

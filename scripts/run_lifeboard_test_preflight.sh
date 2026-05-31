#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-LifeBoard.xcworkspace}"
SCHEME="${SCHEME:-LifeBoard}"
SIM_NAME="${SIM_NAME:-LifeBoard Sunrise Test Runner}"
SIM_RUNTIME="${SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-3}"
SIM_DEVICE_TYPE="${SIM_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
RESULT_ROOT="${RESULT_ROOT:-/tmp/lifeboard-sunrise-tests}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.saransh1337.To-Do-List}"

mkdir -p "$RESULT_ROOT"

sim_udid="$(xcrun simctl list devices available | awk -v name="$SIM_NAME" '$0 ~ name { gsub(/[()]/, "", $2); print $2; exit }')"
if [[ -z "${sim_udid:-}" ]]; then
  sim_udid="$(xcrun simctl create "$SIM_NAME" "$SIM_DEVICE_TYPE" "$SIM_RUNTIME")"
fi

xcrun simctl shutdown "$sim_udid" >/dev/null 2>&1 || true
xcrun simctl boot "$sim_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$sim_udid" -b
xcrun simctl terminate "$sim_udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

destination="platform=iOS Simulator,id=$sim_udid"
build_result="$RESULT_ROOT/build-for-testing.xcresult"
smoke_result="$RESULT_ROOT/runner-smoke.xcresult"

rm -rf "$build_result" "$smoke_result"

xcodebuild build-for-testing \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "$destination" \
  -resultBundlePath "$build_result"

xcodebuild test-without-building \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "$destination" \
  -only-testing:LifeBoardTests/LifeBoardColorAdapterConcurrencyTests/testLifeBoardColorRoleResolutionIsSafeOffMainActor \
  -resultBundlePath "$smoke_result"

echo "Dedicated simulator: $sim_udid"
echo "Build result: $build_result"
echo "Smoke result: $smoke_result"

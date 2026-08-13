#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT_DIR/LifeBoard.xcworkspace"
SCHEME="LifeBoard"
PHONE_TEST_IDS=(
  "LifeBoardUITests/AppStoreScreenshotUITests/testCaptureReadmeLifeOSTour"
  "LifeBoardUITests/AppStoreScreenshotUITests/testCaptureMarketingTrackScenes"
  "LifeBoardUITests/AppStoreScreenshotUITests/testCaptureMarketingReflectionScenes"
)
IPAD_TEST_ID="LifeBoardUITests/AppStoreScreenshotUITests/testCaptureMarketingIPadWeek"
DEVICE_NAME="${LIFEBOARD_README_SCREENSHOT_DEVICE:-LifeBoard Test iPhone}"
IPAD_DEVICE_NAME="${LIFEBOARD_MARKETING_IPAD_DEVICE:-LifeBoard Test iPad}"
OS_VERSION="${LIFEBOARD_README_SCREENSHOT_OS:-26.5}"
FIXED_NOW="${LIFEBOARD_SCREENSHOT_FIXED_NOW:-2026-08-13T10:00:00Z}"
STATUS_BAR_TIME="${LIFEBOARD_README_STATUS_BAR_TIME:-2026-08-13T10:00:00.000+0000}"
WEBP_QUALITY="${LIFEBOARD_README_WEBP_QUALITY:-88}"
DERIVED_DATA_PATH="${LIFEBOARD_SCREENSHOT_DERIVED_DATA_PATH:-}"
FINAL_MARKETING_DIR="$ROOT_DIR/screenshots/marketing"
FINAL_README_DIR="$ROOT_DIR/screenshots/readme"
CONFIG_FILE="/tmp/lifeboard-app-store-screenshot-config.json"
TEMP_DIR="$(mktemp -d /tmp/lifeboard-readme-screenshots.XXXXXX)"
CONFIG_BACKUP=""
NEXT_MARKETING_DIR="$ROOT_DIR/screenshots/.marketing-next-$$"
NEXT_README_DIR="$ROOT_DIR/screenshots/.readme-next-$$"

EXPECTED_SCREENSHOTS=(
  "01-home-command-center"
  "02-universal-capture-review"
  "03-plan-day-capacity"
  "04-plan-week-workspace"
  "05-focus-active-session"
  "06-track-habit-board"
  "07-track-overview"
  "08-track-goals-routines"
  "09-track-wellness"
  "10-track-nutrition"
  "11-track-fasting"
  "12-track-life-moment"
  "13-journal-day"
  "14-knowledge-notes"
  "15-insights-evidence"
  "16-eva-proposal-review"
  "17-recovery-overdue-rescue"
  "18-plan-week-ipad"
)

README_SCREENSHOTS=(
  "01-home-command-center"
  "03-plan-day-capacity"
  "06-track-habit-board"
  "15-insights-evidence"
  "16-eva-proposal-review"
  "17-recovery-overdue-rescue"
)

if ! command -v cwebp >/dev/null 2>&1; then
  echo "error: cwebp is required to produce the optimized README assets (brew install webp)" >&2
  exit 1
fi

if [[ -e "$CONFIG_FILE" ]]; then
  CONFIG_BACKUP="$(mktemp /tmp/lifeboard-readme-config-backup.XXXXXX)"
  cp "$CONFIG_FILE" "$CONFIG_BACKUP"
fi

cleanup() {
  xcrun simctl status_bar "$DEVICE_NAME" clear >/dev/null 2>&1 || true
  xcrun simctl status_bar "$IPAD_DEVICE_NAME" clear >/dev/null 2>&1 || true
  rm -rf "$TEMP_DIR" "$NEXT_MARKETING_DIR" "$NEXT_README_DIR"
  if [[ -n "$CONFIG_BACKUP" ]]; then
    mv "$CONFIG_BACKUP" "$CONFIG_FILE"
  else
    rm -f "$CONFIG_FILE"
  fi
}
trap cleanup EXIT

python3 - "$CONFIG_FILE" "$TEMP_DIR" "$FIXED_NOW" <<'PY'
import json
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "outputRoot": sys.argv[2],
    "deviceSlug": "raw",
    "fixedNow": sys.argv[3],
}) + "\n")
PY

xcrun simctl shutdown "$DEVICE_NAME" >/dev/null 2>&1 || true
xcrun simctl boot "$DEVICE_NAME" >/dev/null 2>&1
xcrun simctl bootstatus "$DEVICE_NAME" -b
xcrun simctl uninstall "$DEVICE_NAME" com.saransh1337.To-Do-ListUITests.xctrunner >/dev/null 2>&1 || true
xcrun simctl uninstall "$DEVICE_NAME" com.saransh1337.To-Do-List >/dev/null 2>&1 || true
xcrun simctl status_bar "$DEVICE_NAME" override \
  --time "$STATUS_BAR_TIME" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 >/dev/null

echo "Capturing 17 populated Life OS scenes on $DEVICE_NAME (iOS $OS_VERSION)"
XCODEBUILD_ACTION="test"
DERIVED_DATA_ARGS=()
if [[ -n "$DERIVED_DATA_PATH" ]]; then
  XCODEBUILD_ACTION="test-without-building"
  DERIVED_DATA_ARGS=(-derivedDataPath "$DERIVED_DATA_PATH")
fi

LIFEBOARD_SCREENSHOT_OUTPUT_DIR="$TEMP_DIR" \
LIFEBOARD_SCREENSHOT_DEVICE_SLUG="raw" \
xcodebuild "$XCODEBUILD_ACTION" \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  "${DERIVED_DATA_ARGS[@]}" \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$OS_VERSION" \
  "${PHONE_TEST_IDS[@]/#/-only-testing:}" \
  -resultBundlePath "$TEMP_DIR/phone-screenshots.xcresult"

xcrun simctl status_bar "$DEVICE_NAME" clear >/dev/null 2>&1 || true
xcrun simctl shutdown "$DEVICE_NAME" >/dev/null 2>&1 || true
xcrun simctl shutdown "$IPAD_DEVICE_NAME" >/dev/null 2>&1 || true
xcrun simctl boot "$IPAD_DEVICE_NAME" >/dev/null 2>&1
xcrun simctl bootstatus "$IPAD_DEVICE_NAME" -b
xcrun simctl uninstall "$IPAD_DEVICE_NAME" com.saransh1337.To-Do-ListUITests.xctrunner >/dev/null 2>&1 || true
xcrun simctl uninstall "$IPAD_DEVICE_NAME" com.saransh1337.To-Do-List >/dev/null 2>&1 || true
xcrun simctl status_bar "$IPAD_DEVICE_NAME" override \
  --time "$STATUS_BAR_TIME" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 >/dev/null

echo "Capturing the regular-width weekly workspace on $IPAD_DEVICE_NAME (iOS $OS_VERSION)"
LIFEBOARD_SCREENSHOT_OUTPUT_DIR="$TEMP_DIR" \
LIFEBOARD_SCREENSHOT_DEVICE_SLUG="raw" \
xcodebuild "$XCODEBUILD_ACTION" \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  "${DERIVED_DATA_ARGS[@]}" \
  -destination "platform=iOS Simulator,name=$IPAD_DEVICE_NAME,OS=$OS_VERSION" \
  -only-testing:"$IPAD_TEST_ID" \
  -resultBundlePath "$TEMP_DIR/ipad-screenshots.xcresult"

mkdir -p "$NEXT_MARKETING_DIR" "$NEXT_README_DIR"

for name in "${EXPECTED_SCREENSHOTS[@]}"; do
  source_png="$TEMP_DIR/raw/$name.png"
  target_webp="$NEXT_MARKETING_DIR/$name.webp"

  if [[ ! -s "$source_png" ]]; then
    echo "error: missing or empty README screenshot: $source_png" >&2
    exit 1
  fi

  width="$(sips -g pixelWidth "$source_png" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$source_png" | awk '/pixelHeight/ {print $2}')"
  if [[ "$name" == "18-plan-week-ipad" ]]; then
    [[ "$width" -ge 1500 ]] || { echo "error: iPad Week capture must use a regular-width iPad device" >&2; exit 1; }
  else
    [[ "$height" -gt "$width" ]] || { echo "error: phone marketing capture must use portrait dimensions: $name" >&2; exit 1; }
  fi

  cwebp -quiet -q "$WEBP_QUALITY" -m 6 "$source_png" -o "$target_webp"
  if [[ ! -s "$target_webp" ]]; then
    echo "error: failed to produce $target_webp" >&2
    exit 1
  fi
done

for name in "${README_SCREENSHOTS[@]}"; do
  cp "$NEXT_MARKETING_DIR/$name.webp" "$NEXT_README_DIR/$name.webp"
done

rm -rf "$FINAL_MARKETING_DIR" "$FINAL_README_DIR"
mv "$NEXT_MARKETING_DIR" "$FINAL_MARKETING_DIR"
mv "$NEXT_README_DIR" "$FINAL_README_DIR"

echo "18 marketing screenshots written to $FINAL_MARKETING_DIR; curated README set written to $FINAL_README_DIR"

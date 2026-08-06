#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$ROOT_DIR/LifeBoard.xcworkspace"
SCHEME="LifeBoard"
TEST_ID="LifeBoardUITests/AppStoreScreenshotUITests/testCaptureReadmeLifeOSTour"
DEVICE_NAME="${LIFEBOARD_README_SCREENSHOT_DEVICE:-LifeBoard Test iPhone}"
OS_VERSION="${LIFEBOARD_README_SCREENSHOT_OS:-26.5}"
FIXED_NOW="${LIFEBOARD_SCREENSHOT_FIXED_NOW:-2026-08-04T10:00:00Z}"
STATUS_BAR_TIME="${LIFEBOARD_README_STATUS_BAR_TIME:-2026-08-04T10:00:00.000+0000}"
WEBP_QUALITY="${LIFEBOARD_README_WEBP_QUALITY:-88}"
FINAL_DIR="$ROOT_DIR/screenshots/readme"
CONFIG_FILE="/tmp/lifeboard-app-store-screenshot-config.json"
TEMP_DIR="$(mktemp -d /tmp/lifeboard-readme-screenshots.XXXXXX)"
CONFIG_BACKUP=""
NEXT_DIR="$ROOT_DIR/screenshots/.readme-next-$$"

EXPECTED_SCREENSHOTS=(
  "01-home-command-center"
  "02-plan-intention-into-time"
  "03-track-life-systems"
  "04-insights-patterns"
  "05-eva-chief-of-staff"
  "06-recover-imperfect-days"
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
  rm -rf "$TEMP_DIR" "$NEXT_DIR"
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
xcrun simctl status_bar "$DEVICE_NAME" override \
  --time "$STATUS_BAR_TIME" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 >/dev/null

echo "Capturing the LifeBoard README tour on $DEVICE_NAME (iOS $OS_VERSION)"
LIFEBOARD_SCREENSHOT_OUTPUT_DIR="$TEMP_DIR" \
LIFEBOARD_SCREENSHOT_DEVICE_SLUG="raw" \
xcodebuild test \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$OS_VERSION" \
  -only-testing:"$TEST_ID" \
  -resultBundlePath "$TEMP_DIR/readme-screenshots.xcresult"

mkdir -p "$NEXT_DIR"
reference_width=""
reference_height=""

for name in "${EXPECTED_SCREENSHOTS[@]}"; do
  source_png="$TEMP_DIR/raw/$name.png"
  target_webp="$NEXT_DIR/$name.webp"

  if [[ ! -s "$source_png" ]]; then
    echo "error: missing or empty README screenshot: $source_png" >&2
    exit 1
  fi

  width="$(sips -g pixelWidth "$source_png" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$source_png" | awk '/pixelHeight/ {print $2}')"
  if [[ -z "$reference_width" ]]; then
    reference_width="$width"
    reference_height="$height"
  elif [[ "$width" != "$reference_width" || "$height" != "$reference_height" ]]; then
    echo "error: inconsistent screenshot dimensions for $source_png: ${width}x${height}" >&2
    exit 1
  fi

  cwebp -quiet -q "$WEBP_QUALITY" -m 6 "$source_png" -o "$target_webp"
  if [[ ! -s "$target_webp" ]]; then
    echo "error: failed to produce $target_webp" >&2
    exit 1
  fi
done

rm -rf "$FINAL_DIR"
mv "$NEXT_DIR" "$FINAL_DIR"

echo "README screenshots written to $FINAL_DIR (${reference_width}x${reference_height})"

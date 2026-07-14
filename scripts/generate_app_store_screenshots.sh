#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DATE="$(date -u +%F)"
FIXED_NOW="${LIFEBOARD_SCREENSHOT_FIXED_NOW:-${RUN_DATE}T10:00:00Z}"
OUTPUT_DIR=""
ALLOW_MISSING_DEVICES=0
for argument in "$@"; do
  case "$argument" in
    --allow-missing-devices) ALLOW_MISSING_DEVICES=1 ;;
    *)
      if [[ -n "$OUTPUT_DIR" ]]; then
        echo "error: unexpected argument: $argument" >&2
        exit 2
      fi
      OUTPUT_DIR="$argument"
      ;;
  esac
done
OUTPUT_DIR="${OUTPUT_DIR:-"$ROOT_DIR/screenshots/app-store-raw-$RUN_DATE"}"
WORKSPACE="$ROOT_DIR/LifeBoard.xcworkspace"
SCHEME="LifeBoard"
TEST_ID="LifeBoardUITests/AppStoreScreenshotUITests/testCaptureExpandedAppStoreScreenshotSet"
RESULT_DIR="$OUTPUT_DIR/_xcresults"
DEVICE_LOG="$OUTPUT_DIR/.devices.tsv"
SKIP_LOG="$OUTPUT_DIR/.skipped.tsv"
CONFIG_FILE="/tmp/lifeboard-app-store-screenshot-config.json"
CONFIG_BACKUP=""
FORCE_REGENERATE="${LIFEBOARD_SCREENSHOT_FORCE_REGENERATE:-0}"

EXPECTED_SCREENSHOTS=(
  "01_onboarding_welcome.png"
  "02_onboarding_goal.png"
  "03_onboarding_blockers.png"
  "04_onboarding_choose_eva.png"
  "05_onboarding_life_areas.png"
  "06_onboarding_habit_setup.png"
  "07_onboarding_weekly_outcomes.png"
  "08_onboarding_first_task.png"
  "09_onboarding_home_demo.png"
  "10_onboarding_permissions.png"
  "11_home_seeded_day.png"
  "12_home_tasks.png"
  "13_home_meetings.png"
  "14_home_habits.png"
  "15_home_focus_strip.png"
  "16_eva_activation.png"
  "17_eva_chat.png"
  "18_habit_board_history.png"
  "19_habit_detail_history.png"
  "20_habit_grid_reflection.png"
  "21_overdue_rescue_entry.png"
  "22_overdue_rescue_deck.png"
  "23_overdue_rescue_completion.png"
  "24_daily_reflection_summary.png"
  "25_daily_reflection_plan.png"
  "26_daily_reflection_context.png"
)

IOS_DEVICES=(
  "iPhone 17 Pro Max|26.5"
  "iPhone 17 Pro|26.5"
  "iPhone 17|26.5"
  "iPhone 17e|26.5"
  "iPhone Air|26.5"
  "iPad Pro 13-inch (M5)|26.5"
  "iPad Pro 11-inch (M5)|26.5"
  "iPad mini (A17 Pro)|26.5"
  "iPad Air 13-inch (M4)|26.5"
  "iPad Air 11-inch (M4)|26.5"
  "iPad (A16)|26.5"
)

slugify() {
  printf "%s" "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

device_available() {
  local name="$1"
  local os="$2"
  xcrun simctl list devices available | awk -v os="-- iOS ${os} --" -v name="$name" '
    /^-- / { section = $0 }
    section == os && index($0, "    " name " (") == 1 { found = 1 }
    END { exit found ? 0 : 1 }
  '
}

device_udid() {
  local name="$1"
  local os="$2"
  xcrun simctl list devices available | awk -v os="-- iOS ${os} --" -v name="$name" '
    /^-- / { section = $0 }
    section == os && index($0, "    " name " (") == 1 {
      if (match($0, /\([0-9A-F-]+\)/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  '
}

validate_device_output() {
  local device_slug="$1"
  local expected_width="$2"
  local expected_height="$3"
  local device_dir="$OUTPUT_DIR/$device_slug"
  local png

  local actual_count
  actual_count="$(find "$device_dir" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')"
  if [[ "$actual_count" != "${#EXPECTED_SCREENSHOTS[@]}" ]]; then
    echo "error: expected ${#EXPECTED_SCREENSHOTS[@]} screenshots in $device_dir, found $actual_count" >&2
    return 1
  fi

  for png in "${EXPECTED_SCREENSHOTS[@]}"; do
    local path="$device_dir/$png"
    if [[ ! -s "$path" ]]; then
      echo "error: missing or empty screenshot: $path" >&2
      return 1
    fi
    local width height
    width="$(sips -g pixelWidth "$path" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$path" | awk '/pixelHeight/ { print $2 }')"
    if [[ "$width" != "$expected_width" || "$height" != "$expected_height" ]]; then
      echo "error: unexpected dimensions for $path: ${width}x${height}, expected ${expected_width}x${expected_height}" >&2
      return 1
    fi
  done
}

if [[ "$FORCE_REGENERATE" == "1" || "$FORCE_REGENERATE" == "true" ]]; then
  rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR" "$RESULT_DIR"
: > "$DEVICE_LOG"
: > "$SKIP_LOG"

if [[ -e "$CONFIG_FILE" ]]; then
  CONFIG_BACKUP="$(mktemp /tmp/lifeboard-app-store-screenshot-config.backup.XXXXXX)"
  cp "$CONFIG_FILE" "$CONFIG_BACKUP"
fi

OVERRIDDEN_SIMULATORS=()
cleanup() {
  local udid
  for udid in "${OVERRIDDEN_SIMULATORS[@]}"; do
    xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  done
  if [[ -n "$CONFIG_BACKUP" ]]; then
    mv "$CONFIG_BACKUP" "$CONFIG_FILE"
  else
    rm -f "$CONFIG_FILE"
  fi
}
trap cleanup EXIT

captured_count=0
for device_spec in "${IOS_DEVICES[@]}"; do
  device_name="${device_spec%%|*}"
  os_version="${device_spec##*|}"
  device_slug="$(slugify "$device_name")"

  if ! device_available "$device_name" "$os_version"; then
    printf "%s\t%s\t%s\n" "$device_name" "iOS $os_version" "simulator unavailable" >> "$SKIP_LOG"
    if [[ "$ALLOW_MISSING_DEVICES" != "1" ]]; then
      echo "error: required simulator unavailable: $device_name (iOS $os_version)" >&2
      exit 1
    fi
    continue
  fi

  device_id="$(device_udid "$device_name" "$os_version")"
  if [[ -z "$device_id" ]]; then
    echo "error: could not resolve simulator UDID for $device_name (iOS $os_version)" >&2
    exit 1
  fi
  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device_id" -b
  xcrun simctl status_bar "$device_id" override \
    --time 10:00 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 >/dev/null 2>&1 || true
  OVERRIDDEN_SIMULATORS+=("$device_id")

  dimension_probe="$(mktemp /tmp/lifeboard-screenshot-dimensions.XXXXXX.png)"
  xcrun simctl io "$device_id" screenshot "$dimension_probe" >/dev/null
  expected_width="$(sips -g pixelWidth "$dimension_probe" | awk '/pixelWidth/ { print $2 }')"
  expected_height="$(sips -g pixelHeight "$dimension_probe" | awk '/pixelHeight/ { print $2 }')"
  rm -f "$dimension_probe"

  if [[ "$FORCE_REGENERATE" != "1" && "$FORCE_REGENERATE" != "true" ]] && validate_device_output "$device_slug" "$expected_width" "$expected_height" 2>/dev/null; then
    echo "Using existing App Store screenshots for $device_name (iOS $os_version)"
    printf "%s\t%s\t%s\t%s\n" "$device_name" "iOS $os_version" "$device_slug" "${#EXPECTED_SCREENSHOTS[@]}" >> "$DEVICE_LOG"
    captured_count=$((captured_count + 1))
    continue
  fi

  echo "Capturing App Store screenshots on $device_name (iOS $os_version)"
  rm -rf "$OUTPUT_DIR/$device_slug" "$RESULT_DIR/$device_slug.xcresult"
  python3 - "$CONFIG_FILE" "$OUTPUT_DIR" "$device_slug" "$FIXED_NOW" <<'PY'
import json
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
config = {
    "outputRoot": sys.argv[2],
    "deviceSlug": sys.argv[3],
    "fixedNow": sys.argv[4],
}
config_path.write_text(json.dumps(config) + "\n")
PY

  LIFEBOARD_SCREENSHOT_OUTPUT_DIR="$OUTPUT_DIR" \
  LIFEBOARD_SCREENSHOT_DEVICE_SLUG="$device_slug" \
  xcodebuild test \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$device_name,OS=$os_version" \
    -only-testing:"$TEST_ID" \
    -resultBundlePath "$RESULT_DIR/$device_slug.xcresult"

  validate_device_output "$device_slug" "$expected_width" "$expected_height"
  printf "%s\t%s\t%s\t%s\n" "$device_name" "iOS $os_version" "$device_slug" "${#EXPECTED_SCREENSHOTS[@]}" >> "$DEVICE_LOG"
  captured_count=$((captured_count + 1))
done

if (( captured_count == 0 )); then
  echo "error: no requested iOS/iPadOS simulators were available." >&2
  exit 1
fi

if ! xcrun simctl list devices available | grep -q -- "-- watchOS "; then
  printf "%s\t%s\t%s\n" "Apple Watch" "watchOS" "watchOS simulator runtime unavailable" >> "$SKIP_LOG"
fi

python3 - "$OUTPUT_DIR" "$DEVICE_LOG" "$SKIP_LOG" "${#EXPECTED_SCREENSHOTS[@]}" "$FIXED_NOW" <<'PY'
import json
import pathlib
import sys

output_dir = pathlib.Path(sys.argv[1])
device_log = pathlib.Path(sys.argv[2])
skip_log = pathlib.Path(sys.argv[3])
expected_count = int(sys.argv[4])

devices = []
if device_log.exists():
    for line in device_log.read_text().splitlines():
        if not line.strip():
            continue
        name, runtime, slug, count = line.split("\t")
        devices.append({
            "name": name,
            "runtime": runtime,
            "folder": slug,
            "screenshotCount": int(count),
        })

skipped = []
if skip_log.exists():
    for line in skip_log.read_text().splitlines():
        if not line.strip():
            continue
        name, runtime, reason = line.split("\t")
        skipped.append({
            "name": name,
            "runtime": runtime,
            "reason": reason,
        })

manifest = {
    "generatedAt": sys.argv[5],
    "outputType": "raw-png",
    "expectedScreenshotsPerDevice": expected_count,
    "devices": devices,
    "skipped": skipped,
}
manifest_path = output_dir / "_manifest.json"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
PY

rm -f "$DEVICE_LOG" "$SKIP_LOG"
echo "Screenshots written to $OUTPUT_DIR"

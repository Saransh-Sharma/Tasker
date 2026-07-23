#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BASELINE_FILE="${LIFEBOARD_TEST_BASELINE_FILE:-scripts/lifeboard-test-failure-baseline.txt}"
RESULT_BUNDLE="${LIFEBOARD_TEST_RESULT_BUNDLE:-build/test-results/LifeBoardTests.xcresult}"
DESTINATION="${LIFEBOARD_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
FAILURES_FILE="$(mktemp /tmp/lifeboard-test-failures.XXXXXX)"
SUMMARY_FILE="$(mktemp /tmp/lifeboard-test-summary.XXXXXX.json)"
BASELINE_NORMALIZED="$(mktemp /tmp/lifeboard-test-baseline.XXXXXX)"
trap 'rm -f "$FAILURES_FILE" "$SUMMARY_FILE" "$BASELINE_NORMALIZED"' EXIT

rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

set +e
xcodebuild \
  -workspace "LifeBoard.xcworkspace" \
  -scheme "LifeBoard" \
  -destination "$DESTINATION" \
  -only-testing:LifeBoardTests \
  -resultBundlePath "$RESULT_BUNDLE" \
  test
XCODEBUILD_STATUS=$?
set -e

if [[ ! -d "$RESULT_BUNDLE" ]]; then
  echo "error: xcodebuild did not produce $RESULT_BUNDLE" >&2
  exit "$XCODEBUILD_STATUS"
fi

xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE" --compact > "$SUMMARY_FILE"
python3 - "$SUMMARY_FILE" "$FAILURES_FILE" <<'PY'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text())
failures = set()
test_count = 0

def visit(node):
    global test_count
    if not isinstance(node, dict):
        return
    if node.get("nodeType") == "Test Case":
        test_count += 1
        if node.get("result") == "Failed":
            failures.add(node.get("nodeIdentifier") or node.get("name"))
    for child in node.get("children", []):
        visit(child)

for root in payload.get("testNodes", []):
    visit(root)

if test_count == 0:
    raise SystemExit("xcresult contained no LifeBoardTests test cases")

pathlib.Path(sys.argv[2]).write_text("\n".join(sorted(failures)) + ("\n" if failures else ""))
print(f"LifeBoardTests executed: {test_count}; failed methods: {len(failures)}")
PY

if [[ "${UPDATE_LIFEBOARD_TEST_BASELINE:-0}" == "1" ]]; then
  cp "$FAILURES_FILE" "$BASELINE_FILE"
  echo "Updated $BASELINE_FILE"
  exit 0
fi

if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "error: missing failure baseline: $BASELINE_FILE" >&2
  exit 1
fi

rg -v '^\s*(#|$)' "$BASELINE_FILE" | sort -u > "$BASELINE_NORMALIZED" || true
if ! diff -u "$BASELINE_NORMALIZED" "$FAILURES_FILE"; then
  echo "error: LifeBoardTests failures differ from the checked-in baseline." >&2
  echo "Fix unexpected failures; when legacy failures are repaired, regenerate and reduce the baseline explicitly." >&2
  exit 1
fi

if [[ $XCODEBUILD_STATUS -ne 0 && ! -s "$FAILURES_FILE" ]]; then
  echo "error: xcodebuild failed without a baselined test failure." >&2
  exit "$XCODEBUILD_STATUS"
fi

echo "✅ Full LifeBoardTests result matches the explicit legacy-failure baseline."

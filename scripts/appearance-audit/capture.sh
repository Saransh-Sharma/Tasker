#!/bin/bash
# Captures one LifeBoard surface in one appearance cell on the simulator.
#
#   capture.sh <name> <appearance> <phase> [extra launch args...]
#
# appearance: light | dark | high-contrast-light | high-contrast-dark
# phase:      dawn | morning | midday | goldenHour | twilight | night
# Env:        AUDIT_UDID (default: LifeBoard Test iPhone), AUDIT_OUT (output dir),
#             AUDIT_ROUTE (LIFEBOARD_EVIDENCE_ROUTE), AUDIT_WAIT (seconds, default 9),
#             AUDIT_SEED (default ESTABLISHED_WORKSPACE; "none" to omit).
#
# Both the simulator appearance and `-LIFEBOARD_VISUAL_APPEARANCE` are set: the
# shell pins its scheme from the fixture, while UIKit traits (alerts, sheets
# presented from UIKit, dynamic UIColors resolved outside SwiftUI) follow the
# simulator. Setting only one of them produced "dark" captures that were light.
set -euo pipefail

NAME="$1"; APPEARANCE="$2"; PHASE="$3"; shift 3
UDID="${AUDIT_UDID:-A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF}"
OUT="${AUDIT_OUT:-docs/evidence/appearance-audit-2026-09/raw}"
WAIT="${AUDIT_WAIT:-9}"
SEED="${AUDIT_SEED:-ESTABLISHED_WORKSPACE}"
BUNDLE=com.saransh1337.To-Do-List
mkdir -p "$OUT"

case "$APPEARANCE" in
  *dark) SIM_STYLE=dark ;;
  *) SIM_STYLE=light ;;
esac
case "$APPEARANCE" in
  high-contrast-*) CONTRAST=enabled ;;
  *) CONTRAST=disabled ;;
esac
xcrun simctl ui "$UDID" appearance "$SIM_STYLE"
xcrun simctl ui "$UDID" increase_contrast "$CONTRAST" 2>/dev/null || true
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

ARGS=(-UI_TESTING -RESET_APP_STATE -SKIP_ONBOARDING -DISABLE_CLOUD_SYNC
  -LIFEBOARD_TEST_EVA_ACTIVATION_COMPLETED
  "-LIFEBOARD_CELESTIAL_PHASE=$PHASE" "-LIFEBOARD_VISUAL_APPEARANCE=$APPEARANCE"
  -AppleLanguages "(en)" -AppleLocale en_US)
[ "$SEED" != none ] && ARGS+=("-LIFEBOARD_TEST_SEED_$SEED")
for f in LIFE_OS_FOUNDATION DASHBOARD_CUSTOMIZATION_V2 TRACKERS_V1 HEALTH_INTEGRATIONS_V1 \
  JOURNAL_V1 KNOWLEDGE_NOTES_V1 PLANNING_CORE_V1 FOCUS_EXECUTION_V2 TRACK_FOUNDATIONS_V2 \
  GOALS_ROUTINES_V1 CARE_MODULES_V2 LIFE_OS_UNIFIED_PRESENTATION_V2 PREMIUM_IA_V5 \
  WELLNESS_CORE_V1 FASTING_V2 NUTRITION_V1 LIFE_MOMENTS_V1; do
  ARGS+=("-LIFEBOARD_ENABLE_$f")
done
if [ -n "${AUDIT_ROUTE:-}" ]; then
  ARGS+=(-LIFEBOARD_PRODUCTION_EVIDENCE)
  export SIMCTL_CHILD_LIFEBOARD_EVIDENCE_ROUTE="$AUDIT_ROUTE"
  export SIMCTL_CHILD_LIFEBOARD_EVIDENCE_ARRANGEMENT=mixed
fi
export SIMCTL_CHILD_TZ=UTC

xcrun simctl launch "$UDID" "$BUNDLE" "${ARGS[@]}" "$@" >/dev/null
sleep "$WAIT"
FILE="$OUT/$NAME--$APPEARANCE--$PHASE.png"
xcrun simctl io "$UDID" screenshot "$FILE" >/dev/null 2>&1
echo "$FILE"

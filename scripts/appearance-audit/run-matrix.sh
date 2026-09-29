#!/bin/bash
# Runs the appearance-audit capture matrix on the simulator.
#   run-matrix.sh roots     # 5 roots × light/dark × morning/goldenHour/twilight/night
#   run-matrix.sh surfaces  # every row of surfaces.tsv × light/dark/high-contrast-dark
# AUDIT_APPEARANCES / AUDIT_PHASES override the default cells.
set -uo pipefail
cd "$(dirname "$0")/../.."
CAP=scripts/appearance-audit/capture.sh
MODE="${1:-surfaces}"

if [ "$MODE" = roots ]; then
  for phase in ${AUDIT_PHASES:-morning goldenHour twilight night}; do
    for appearance in ${AUDIT_APPEARANCES:-light dark}; do
      for root in home plan track insights eva; do
        AUDIT_ROUTE=$root $CAP "$root-root" "$appearance" "$phase" || echo "FAILED $root $appearance $phase"
      done
    done
  done
  exit 0
fi

grep -v '^#' scripts/appearance-audit/surfaces.tsv | while IFS=$'\t' read -r name seed route extra; do
  [ -z "$name" ] && continue
  [ -n "${AUDIT_ONLY:-}" ] && [[ " $AUDIT_ONLY " != *" $name "* ]] && continue
  for appearance in ${AUDIT_APPEARANCES:-light dark high-contrast-dark}; do
    r=""; [ "$route" != "-" ] && r="$route"
    # shellcheck disable=SC2086
    AUDIT_SEED="$seed" AUDIT_ROUTE="$r" $CAP "$name" "$appearance" "${AUDIT_PHASE:-morning}" $extra </dev/null \
      || echo "FAILED $name $appearance"
  done
done

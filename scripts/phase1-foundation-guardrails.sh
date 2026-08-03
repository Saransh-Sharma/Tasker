#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
  echo "Phase 1 foundation guardrail failed: $1" >&2
  exit 1
}

if rg -n '(^|[[:space:]])(@preconcurrency[[:space:]]+)?import Firebase' LifeBoard --glob '*.swift'; then
  fail "Firebase imports are not allowed"
fi

if rg -n 'Pods_|Pods/Pods\.xcodeproj|baseConfigurationReference = .*Pods-' \
  LifeBoard.xcodeproj/project.pbxproj LifeBoard.xcworkspace/contents.xcworkspacedata; then
  fail "CocoaPods build integration is not allowed"
fi

if [[ -e Podfile || -e Podfile.lock || -d Pods ]]; then
  fail "CocoaPods artifacts must remain removed"
fi

if rg -n 'GoogleService-Info\.plist' LifeBoard.xcodeproj/project.pbxproj; then
  fail "Google service configuration must not be embedded"
fi

if rg -n '#[0-9A-Fa-f]{6}' LifeBoard/Foundation \
  --glob '*.swift' \
  --glob '!LifeBoardDaypartTokens.swift'; then
  fail "Foundation surfaces must resolve colors through semantic tokens"
fi

if rg -n 'IPHONEOS_DEPLOYMENT_TARGET = (1[0-9]|2[0-5])\.' LifeBoard.xcodeproj/project.pbxproj; then
  fail "Every iOS-family target must use the iOS 26 baseline"
fi

if rg -n 'WATCHOS_DEPLOYMENT_TARGET = (1[0-9]|2[0-5])\.' LifeBoard.xcodeproj/project.pbxproj; then
  fail "Every Watch target must use the watchOS 26 baseline"
fi

echo "Phase 1 foundation guardrails passed."

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

IOS_DESTINATION="${LIFEBOARD_BUILD_DESTINATION:-platform=iOS Simulator,name=LifeBoard Test iPhone,OS=latest}"
DERIVED_DATA="${LIFEBOARD_BUILD_DERIVED_DATA:-build/DerivedData/Phase1Phase2Matrix}"

build() {
  echo "→ $*"
  xcodebuild "$@"
}

build \
  -workspace LifeBoard.xcworkspace \
  -scheme LifeBoard \
  -configuration Debug \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=YES \
  build

# Build extension schemes independently as well as through the containing app.
# This catches target-membership and conditional-import regressions that an
# incremental app build can otherwise mask.
build \
  -project LifeBoard.xcodeproj \
  -scheme LifeBoardWidgets \
  -configuration Debug \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=YES \
  build

build \
  -project LifeBoard.xcodeproj \
  -scheme LifeBoardShareExtension \
  -configuration Debug \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=YES \
  build

build \
  -workspace LifeBoard.xcworkspace \
  -scheme LifeBoard \
  -configuration Release \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=YES \
  build

build \
  -workspace LifeBoard.xcworkspace \
  -scheme LifeBoard \
  -configuration Debug \
  -destination "platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath "$DERIVED_DATA" \
  build

if xcrun simctl list devices available | grep -q "Apple Watch"; then
  build \
    -project LifeBoard.xcodeproj \
    -scheme LifeBoardWatch \
    -configuration Debug \
    -destination "generic/platform=watchOS Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    build
  build \
    -project LifeBoard.xcodeproj \
    -scheme LifeBoardWatchWidgets \
    -configuration Debug \
    -destination "generic/platform=watchOS Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    build
else
  echo "⚠️  Watch app/widget builds skipped: no available watchOS simulator runtime."
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LEGACY_BUILD_GRAPH_PATTERN="/\\* NAddTaskScreen.swift in Sources \\*/|/\\* DependencyContainer.swift in Sources \\*/|/\\* AddTaskLegacyStubs.swift in Sources \\*/"
LEGACY_STORYBOARD_PATTERN='addTaskLegacy_unreachable|customClass="NAddTaskScreen"'
LEGACY_SINGLETON_PATTERN='(^|[^A-Za-z0-9_])DependencyContainer\.shared\b'
LEGACY_SCREEN_PATTERN='\bNAddTaskScreen\b'

RUNTIME_FILES=(
  "To Do List/AppDelegate.swift"
  "To Do List/SceneDelegate.swift"
  "To Do List/Presentation/DI/PresentationDependencyContainer.swift"
  "To Do List/State/DI/EnhancedDependencyContainer.swift"
  "To Do List/UseCases/Coordinator/UseCaseCoordinator.swift"
)

if rg -n "$LEGACY_BUILD_GRAPH_PATTERN" "Tasker.xcodeproj/project.pbxproj"; then
  echo "Legacy add-task runtime files are still compiled in app target"
  exit 1
fi

if rg -n "$LEGACY_STORYBOARD_PATTERN" "To Do List/Storyboards/Base.lproj/Main.storyboard"; then
  echo "Legacy storyboard route still present"
  exit 1
fi

if rg -n "$LEGACY_SINGLETON_PATTERN" "${RUNTIME_FILES[@]}"; then
  echo "Legacy runtime singleton reference detected"
  exit 1
fi

if rg -n "$LEGACY_SCREEN_PATTERN" "${RUNTIME_FILES[@]}"; then
  echo "Legacy runtime screen reference detected"
  exit 1
fi

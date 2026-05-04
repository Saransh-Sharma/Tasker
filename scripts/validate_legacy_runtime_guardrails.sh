#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LEGACY_BUILD_GRAPH_PATTERN="/\\* NAddTaskScreen.swift in Sources \\*/|/\\* DependencyContainer.swift in Sources \\*/|/\\* AddTaskLegacyStubs.swift in Sources \\*/"
LEGACY_STORYBOARD_PATTERN='addTaskLegacy_unreachable|customClass="NAddTaskScreen"'
LEGACY_SINGLETON_PATTERN='(^|[^A-Za-z0-9_])DependencyContainer\.shared\b'
LEGACY_SCREEN_PATTERN='\bNAddTaskScreen\b'
PRODUCTION_SWIFT_ROOT="LifeBoard"
CHAT_SWIFT_ROOT="LifeBoard/LLM/Views/Chat"
CHAT_MUTATION_BYPASS_PATTERN='\b(createTaskDefinition|updateTaskDefinition|deleteTaskDefinition|completeTaskDefinition|rescheduleTaskDefinition)\b'
CHAT_SEMANTIC_REBUILD_PATTERN='TaskSemanticRetrievalService\.shared\.(rebuildIndex|index)\('
PROPOSAL_RUN_GUARD_PATTERN='payload\.runID\s*==\s*nil'

RUNTIME_FILES=(
  "LifeBoard/AppDelegate.swift"
  "LifeBoard/SceneDelegate.swift"
  "LifeBoard/Presentation/DI/PresentationDependencyContainer.swift"
  "LifeBoard/State/DI/EnhancedDependencyContainer.swift"
  "LifeBoard/UseCases/Coordinator/UseCaseCoordinator.swift"
)

if rg -n "$LEGACY_BUILD_GRAPH_PATTERN" "LifeBoard.xcodeproj/project.pbxproj"; then
  echo "Legacy add-task runtime files are still compiled in app target"
  exit 1
fi

if rg -n "$LEGACY_STORYBOARD_PATTERN" "LifeBoard/Storyboards/Base.lproj/Main.storyboard"; then
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

check_banned_symbol() {
  local label="$1"
  local pattern="$2"

  if rg -n -P "$pattern" "$PRODUCTION_SWIFT_ROOT" --glob '*.swift'; then
    echo "Banned legacy symbol detected: $label"
    exit 1
  fi
}

check_banned_symbol "TaskRepositoryProtocol" 'TaskRepositoryProtocol'
check_banned_symbol "V2TaskRepositoryAdapter" 'V2TaskRepositoryAdapter'
check_banned_symbol "TaskData" '\bTaskData\b'
check_banned_symbol "toLegacyTask" 'toLegacyTask'
check_banned_symbol "legacyTask" 'legacyTask'
check_banned_symbol "CoreDataTaskRepository" 'CoreDataTaskRepository'
check_banned_symbol "NAddTaskScreen" 'NAddTaskScreen'
check_banned_symbol "DependencyContainer.shared" '(^|[^A-Za-z0-9_])DependencyContainer\.shared\b'
check_banned_symbol "CreateTaskRequest" 'CreateTaskRequest(?!Definition)'
check_banned_symbol "public struct Task:" 'public\s+struct\s+Task:'
check_banned_symbol "v2Enabled" 'v2Enabled'
check_banned_symbol "assertV2RuntimeReady" '\bassertV2RuntimeReady\b'
check_banned_symbol "evaluateV2RuntimeReadiness" '\bevaluateV2RuntimeReadiness\b'
check_banned_symbol "v2RuntimeReady" '\bv2RuntimeReady\b'
check_banned_symbol "v2_runtime_not_ready" '\bv2_runtime_not_ready\b'

if rg -n "TaskModelV2" "${RUNTIME_FILES[@]}" --glob '*.swift' | rg -v "^LifeBoard/AppDelegate.swift:"; then
  echo "TaskModelV2 reference detected outside AppDelegate runtime cleanup allowlist"
  exit 1
fi

if rg -n "TaskModelV2" "LifeBoard/AppDelegate.swift" | rg -v "TaskModelV2-(cloud|local)\\.sqlite(-wal|-shm)?"; then
  echo "TaskModelV2 reference detected in AppDelegate outside cleanup filename allowlist"
  exit 1
fi

if rg -n -P "$CHAT_MUTATION_BYPASS_PATTERN" "$CHAT_SWIFT_ROOT" --glob '*.swift'; then
  echo "Chat layer appears to mutate tasks directly; must route through AssistantActionPipelineUseCase"
  exit 1
fi

if rg -n -P "$CHAT_SEMANTIC_REBUILD_PATTERN" "$CHAT_SWIFT_ROOT" --glob '*.swift'; then
  echo "Chat layer must not rebuild or mutate semantic index directly"
  exit 1
fi

if ! rg -n -P "$PROPOSAL_RUN_GUARD_PATTERN" "LifeBoard/LLM/Views/Chat/ConversationView.swift" >/dev/null; then
  echo "Proposal card rendering must guard against missing run ID"
  exit 1
fi

if rg -n "assistantApplyEnabled" "$PRODUCTION_SWIFT_ROOT" --glob '*.swift' \
  | rg -v "^LifeBoard/Services/V2FeatureFlags.swift:|^LifeBoard/UseCases/LLM/AssistantActionPipelineUseCase.swift:"; then
  echo "assistantApplyEnabled must only be checked in feature flags and assistant pipeline"
  exit 1
fi

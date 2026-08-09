#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lifeboard-paths.env
source "$SCRIPT_DIR/lifeboard-paths.env"
cd "$LIFEBOARD_ROOT_DIR"

require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "error: required runtime-guard input is missing: ${file#"$LIFEBOARD_ROOT_DIR"/}" >&2
    exit 1
  fi
}

LEGACY_BUILD_GRAPH_PATTERN="/\\* NAddTaskScreen.swift in Sources \\*/|/\\* DependencyContainer.swift in Sources \\*/|/\\* AddTaskLegacyStubs.swift in Sources \\*/"
LEGACY_STORYBOARD_PATTERN='addTaskLegacy_unreachable|customClass="NAddTaskScreen"'
LEGACY_SINGLETON_PATTERN='(^|[^A-Za-z0-9_])DependencyContainer\.shared\b'
LEGACY_SCREEN_PATTERN='\bNAddTaskScreen\b'
PRODUCTION_SWIFT_ROOT="LifeBoard"
CHAT_SWIFT_ROOT="LifeBoard/Features/Eva/Views/Chat"
CHAT_MUTATION_BYPASS_PATTERN='\b(createTaskDefinition|updateTaskDefinition|deleteTaskDefinition|completeTaskDefinition|rescheduleTaskDefinition)\b'
CHAT_SEMANTIC_REBUILD_PATTERN='TaskSemanticRetrievalService\.shared\.(rebuildIndex|index)\('
PROPOSAL_RUN_GUARD_PATTERN='payload\.runID\s*==\s*nil'
PROPOSAL_RUN_GUARD_FILES=(
  "LifeBoard/Features/Eva/Views/Chat/ConversationView.swift"
  "LifeBoard/Features/Eva/Views/Chat/Conversation"
)

RUNTIME_FILES=(
  "$LIFEBOARD_APP_DELEGATE"
  "$LIFEBOARD_SCENE_DELEGATE"
  "$LIFEBOARD_COMPOSITION_ROOT"
  "$LIFEBOARD_COMPOSITION_ROOT_VIEW_MODELS"
  "$LIFEBOARD_USE_CASE_COORDINATOR"
)

require_file "$LIFEBOARD_PROJECT_FILE"
require_file "$LIFEBOARD_MAIN_STORYBOARD"
for runtime_file in "${RUNTIME_FILES[@]}"; do
  require_file "$runtime_file"
done

if rg -n "$LEGACY_BUILD_GRAPH_PATTERN" "$LIFEBOARD_PROJECT_FILE"; then
  echo "Legacy add-task runtime files are still compiled in app target"
  exit 1
fi

if rg -n "$LEGACY_STORYBOARD_PATTERN" "$LIFEBOARD_MAIN_STORYBOARD"; then
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
if rg -n -P 'legacyTask' "$PRODUCTION_SWIFT_ROOT" --glob '*.swift' \
  | rg -v '^LifeBoard/Features/Onboarding/AppOnboarding.swift:[0-9]+:.*legacyTaskIDMap'; then
  echo "Banned legacy symbol detected: legacyTask"
  exit 1
fi
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

if rg -n "TaskModelV2" "$LIFEBOARD_APP_DELEGATE" | rg -v "TaskModelV2-(cloud|local)\\.sqlite(-wal|-shm)?"; then
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

if ! rg -n -P "$PROPOSAL_RUN_GUARD_PATTERN" "${PROPOSAL_RUN_GUARD_FILES[@]}" --glob '*.swift' >/dev/null; then
  echo "Proposal card rendering must guard against missing run ID"
  exit 1
fi

if rg -n "assistantApplyEnabled" "$PRODUCTION_SWIFT_ROOT" --glob '*.swift' \
  | rg -v "^LifeBoard/Services/V2FeatureFlags.swift:|^LifeBoard/Features/Eva/Domain/AssistantActionPipelineUseCase.swift:"; then
  echo "assistantApplyEnabled must only be checked in feature flags and assistant pipeline"
  exit 1
fi

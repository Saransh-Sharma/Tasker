# Local LLM / EVA Architecture

EVA is Tasker's local assistant layer for chat, task review, and planner-assisted task changes. The runtime is designed around local MLX inference, deterministic guardrails, schema-validated planner output, and the existing V2 task action pipeline.

## Use Cases

- Chat over task context: answer user questions using the current projected task context.
- Read-only review: summarize tasks or the day without creating mutations that can be applied.
- Chief-of-staff day overview: answer natural-language day-status prompts with a brief plus editable task and habit cards.
- Plan with EVA: route planning prompts to a planner that can return visible text or proposal cards.
- Proposal review: show schema v3 task command cards, allow selected apply, and avoid cards for empty command runs.
- Context shortcuts: include slash-command context and task projections in prompts.
- Lightweight assistance: daily brief, top three, task breakdown, dynamic chips, and task suggestions.

Voice, scan, inline timeline diff, and full applied-run history surfaces are feature-flagged as unfinished surfaces. They must not be described as complete user workflows until their end-to-end paths are implemented.

## Runtime Flow

The chat UI accepts a prompt in `ChatView`, assigns a run ID, clears stale evaluator turn state with `LLMEvaluator.beginUserTurn(runID:)`, and routes the prompt. `EvaTurnRouter` identifies EVA planner routes, while `AIChatModeRouter` selects the local model route for ordinary LLM features based on installed models, device constraints, and fallback rules.

Context is built through the LLM context projection and envelope builders, with bounded budgets for chat-style turns. Required context failures are fail-closed: EVA persists a visible assistant message explaining the missing context instead of silently dropping the turn.

`AssistantPlannerService` produces `AssistantPlanResult` values. Planner outputs can be deterministic fallbacks, intent-gate responses, grounding-rejected clarifications, direct model output, normalized model output, or repair output. `AssistantPlanResult.usesModelGenerationForDeliveryGate` distinguishes deterministic responses from model-backed responses so stale evaluator cancellation does not block no-model planner text.

`EvaPlanResponseDelivery` is the testable delivery gate. It allows deterministic text and proposal delivery when the task is still active and the run ID matches. It checks `llm.cancelled` only for model-backed planner results. Delivery logs terminal events for persisted responses and explicit drops.

Proposal cards are built from schema v3 assistant command envelopes. Non-empty commands that can be applied are reviewed and selectively applied. The apply path goes through `AssistantActionPipelineUseCase`, repository validation, transactional persistence, and undo command storage; UI code does not mutate task state directly.

Read-only day review now has a parallel card contract. `AssistantCardType.dayOverview` carries `EvaDayOverviewPayload`, which contains `summaryMarkdown`, `contextReceipt`, `isPartialContext`, and ordered sections for overdue tasks, today tasks, focus candidates, due habits, recovery habits, quiet tracking, or an empty/degraded state. These cards persist as assistant messages, but post-render quick-action state is maintained as chat-local overlay state so the transcript remains immutable.

Chat messages and threads are persisted through the chat message flow. Assistant action runs use the Core Data assistant action repository. Applied-run history currently has a foundation behind feature flags, but the complete activity/history UI is not finished.

## Architecture Decisions

- Local-only inference: EVA uses on-device MLX models to preserve task privacy and offline behavior. The docs and UI should avoid implying cloud AI processing.
- Deterministic-first planner guards: review, no-op, habit guard, fallback, and grounding-rejected responses can return visible text without requiring a model generation reset.
- Day overview is a dedicated read-only surface: review prompts return `dayOverview` cards instead of proposal cards or plain no-op text.
- Schema v3 planner contracts: task mutations flow through structured command envelopes, proposal cards, validation, selected apply, and undo.
- Quick actions stay first-party: task and habit buttons on day overview cards invoke existing task and habit use cases directly because the user tapped them; they do not enter propose -> apply -> undo.
- Empty commands are text-only: zero-command planner results persist assistant text and do not create proposal cards or apply buttons.
- Required context is fail-closed: when policy says context is required but unavailable, EVA sends a visible failure/clarification message.
- Cancellation state is split: `cancelGeneration()` still cancels active model generation, while `beginUserTurn(runID:)` clears stale output and cancellation metadata for a new accepted UI turn without unloading or preparing the model.
- Delivery is run-scoped: planner responses are persisted only when the active `generationRunID` still matches the turn run ID.
- Feature flags separate complete and incomplete surfaces: text planning, structured composer, and proposal review cards are enabled by default; inline diff, applied-run history UI, voice, and scan deferred surfaces default off.
- V2 boundaries remain authoritative: UI routes intent, planner emits commands, action pipeline validates/applies, repositories persist.

## Risks And Known Gaps

- Simulator support: local MLX model activation can be unavailable in iOS Simulator, so some model-backed tests may skip or need device validation.
- Small-model drift: compact local models may produce malformed or partially grounded JSON; repair, normalization, and deterministic fallbacks are required.
- Cancellation regressions: stale `llm.cancelled`, run ID mismatch, task cancellation, empty sanitized text, or save failure can still drop responses if delivery gates regress.
- Context limits: bounded projection budgets and context timeouts may produce conservative responses or visible context-failure messages.
- Partial day overviews: missing task or habit slices must degrade to explicit empty/degraded sections instead of inferred prose.
- Memory pressure: model routing must keep respecting installed model availability, runtime support, and device memory limits.
- Draft recovery: prompt/draft preservation during stop, backgrounding, or model failure remains stateful in `ChatView` and should be tested before expanding workflows.
- Incomplete review surfaces: inline timeline diff preview hooks, complete applied-run history/activity UI, and voice/scan interactions are not complete.
- Strict apply gates: current gates cover selected apply and basic safety, but richer confirmations for recurrence scope, delete/drop, large batches, and calendar conflicts still depend on additional schema and context metadata.
- Package identity: MLX dependencies can surface package identity warnings; keep workspace-based builds as the primary validation path.

## Testing And Operations

Use the workspace, not the project, for iOS builds and tests:

```bash
xcodebuild test -workspace Tasker.xcworkspace -scheme 'To Do List' -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:'To Do ListTests/AssistantPlannerServiceTests' -only-testing:'To Do ListTests/LLMRuntimeCoordinatorTests/testBeginUserTurnClearsCancelledOutputStateWithoutUnloadingModel' -only-testing:'To Do ListTests/LLMRuntimeCoordinatorTests/testCancelGenerationClearsThinkingWhenNotRunning'
```

Static documentation check:

```bash
git diff --check -- README.md docs/architecture/TASKER_V2_ARCHITECTURE_GUIDE.md docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md EVA_PLAN_WITH_STRUCTURED_UI_TODO.md
```

Manual EVA response-drop validation:

```bash
xcrun simctl spawn booted log stream --style compact --predicate 'eventMessage CONTAINS[c] "eva_" OR eventMessage CONTAINS[c] "chat_sendMessage_completed" OR eventMessage CONTAINS[c] "chat_user_turn_started"'
```

Run these scenarios in the simulator or on device:

1. Send a normal generation prompt, tap Stop, then send `What are my tasks?`.
   - Expected UI: visible assistant response, no proposal card, no Apply button.
   - Expected logs: `chat_user_turn_started`, route/context logs, `eva_plan_response_send_attempted`, `chat_sendMessage_completed`, and `eva_plan_response_persisted`.
2. Send `Help me plan my day. What are my tasks?`.
   - Expected route: read-only review.
   - Expected UI: `dayOverview` card with markdown brief plus task and habit sections, no mutation proposal.
3. Send `How is my day?` or tap the first composer chip above the text box.
   - Expected route: read-only review.
   - Expected UI: same `dayOverview` card path as natural-language day review.
   - Expected interactions: task cards show task-style actions, habit cards show habit-style actions, and `Open` uses the existing detail sheet for that entity.
4. Send `Help me plan my day`.
   - Expected route: day planning.
   - Expected UI: visible summary or clarification text with no proposal card.
5. Send `Create Design review at 4 PM for 45 minutes`.
   - Expected route: task mutation.
   - Expected UI: proposal card appears with selected safe card and `Apply selected`.
   - Expected apply behavior: action pipeline applies the task change and shows the undo affordance.
6. While an EVA turn is building or generating, tap Stop.
   - Expected behavior: no silent hang; logs show an explicit cancellation/drop or the UI returns cleanly to idle.

Every EVA turn should end with one terminal event: persisted text, persisted proposal card, explicit response drop, or explicit cancellation.

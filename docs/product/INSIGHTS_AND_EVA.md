# Insights and EVA

**Classification:** Canonical feature contract

**Roots:** Insights and EVA
**Related:** [Journal and Reflection](./JOURNAL_NOTES_AND_REFLECTION.md), [Local EVA architecture](../architecture/LOCAL_LLM_EVA_ARCHITECTURE.md)

## Promise and user jobs

Insights helps users interpret their own evidence without overstating certainty. EVA helps users understand the day, explore options, and prepare safe changes through a local-first conversation with explicit review boundaries.

Users come here to:

- understand trends and weekly patterns;
- inspect the evidence behind a claim;
- save, dismiss, snooze, or follow up on a reflection;
- ask what matters now or why a suggestion appeared;
- break down, schedule, defer, or repair work;
- review a proposed change before applying it;
- stop generation, retry, continue, and undo applied work.

## Insights contract

Insights orders content by decision value: current summary, meaningful change/pattern, supporting evidence, timeframe/source, and next action. Metrics without enough data state that limitation. A visual trend includes a text/table equivalent and does not imply causation.

Proactive reflection:

- uses deterministic eligibility and protected evidence links;
- distinguishes recorded facts from interpretation;
- avoids diagnosis, moral judgment, and manufactured urgency;
- supports Save, Snooze, Dismiss, and Follow Up;
- respects persistent feedback and repetition cooldown;
- routes to the exact supporting source when authorization permits.

Saved insights retain stable identity, evidence references, and privacy classification. Cross-surface routes must return to the originating context after review or action.

## EVA contract

EVA is an assistant layer, not a second task engine. It can explain, summarize, clarify, and prepare proposals. Consequential changes pass through canonical mutations and an explicit review/apply boundary.

### Conversation states

1. Ready: prompt suggestions and available context are visible.
2. Accepted: the user’s turn is persisted and scoped to a run ID.
3. Working: truthful bounded status describes actual pipeline work.
4. Streaming: settled phrases appear without whole-bubble shimmer.
5. Review: proposal card shows affected items, rationale, and diff.
6. Applied: receipt and Undo are visible.
7. Stopped/failed: settled text remains, unfinished output is discarded, and Continue/Retry preserves the draft.

Manual scroll disables automatic following. A single accessible “New response” control returns to the latest content.

### Proposal and mutation behavior

- The four outcomes are answer, clarification, proposal, or explicit inability/recovery.
- Proposal cards expose Apply, Edit, and Not Now.
- Apply validates authorization, current state, and schema before mutation.
- Results return to the originating root and identify partial/failure outcomes.
- Undo invokes the canonical inverse receipt, not a reconstructed guess.
- Cancellation is run-scoped so stale model output cannot appear in a later turn.

### Context and privacy

Context is a bounded projection of authorized tasks, plans, calendar reality, habits, trackers, and evidence. External calendar content is read-only. Journal evidence requires the protected authorization path. Prompts and projected private content remain on device in the local runtime.

## State matrix

| State | Insights | EVA |
|---|---|---|
| Empty | Explain evidence needed | Offer concrete starter prompts |
| Loading | Preserve chart/card geometry | Show truthful pipeline status and Stop |
| Insufficient evidence | State threshold/timeframe | Ask a clarifying question or explain limitation |
| Offline | Keep local reports available | Use deterministic/local capability or explain unavailable model |
| Model unavailable | Insights remains usable | Preserve draft and offer setup/retry |
| Streaming stopped | Not applicable | Keep settled text; expose Continue/Retry |
| Proposal stale | Evidence remains readable | Revalidate and explain changed inputs |
| Apply failure | Keep insight/source intact | Preserve proposal and provide recovery |
| Protected evidence locked | Redacted card | Authenticate before revealing/using evidence |

## UI/UX contract

- Insights uses paper reading surfaces and restrained charts; a single meaningful pattern should outrank a wall of metrics.
- EVA chat chrome may use approved glass; message and proposal content use readable clay/paper surfaces.
- Assistant violet identifies EVA context only and never communicates success or selection by itself.
- Prompt chips are short, actionable, and do not obscure the composer at accessibility sizes.
- Streaming motion operates at newly settled phrase boundaries and stops under Reduce Motion/energy policy.
- Persona/mascot media is supportive and never replaces status, error, or action text.

## Accessibility and platforms

- Charts have text equivalents and meaningful VoiceOver summaries.
- Streaming updates avoid excessive announcements; new-response and Stop controls are reachable.
- Proposal cards expose affected item count, change summary, and all actions to VoiceOver and keyboard.
- iPad/Catalyst can use wider reading/proposal layouts without excessive line length.
- Model download/setup explains size, device support, progress, cancellation, and failure without blocking non-assistant features.

## Implementation and evidence

Primary anchors include `ReflectionKit`, Insights presentation, local LLM runtime/coordinator, run-scoped response delivery, context projection, assistant proposal/diff validators, canonical action pipeline, conversation views, and persistent composer.

Primary controls include `evaFoundationModelsResponderEnabled`, `assistantApplyEnabled`, `assistantUndoEnabled`, `assistantCopilotEnabled`, `assistantSemanticRetrievalEnabled`, `assistantFastModeEnabled`, and `assistantBreakdownEnabled`. Disabling an optional assistant capability must leave deterministic evidence, drafts, conversations, and ordinary app workflows usable.

Recorded evidence covers deterministic reflection thresholds, evidence authorization, truthful work states, streaming/cancel/retry, proposal validation, Apply/Undo, and local trust boundaries. Saved-insight cross-surface completion, complete degraded-state fixtures, device memory/thermal behavior, and full model setup journeys remain active gates.

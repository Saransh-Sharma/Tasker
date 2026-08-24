# Insights and EVA

**Classification:** Canonical feature contract

**Audience:** Users, support, product, design, engineering, safety/privacy review, and QA
**Capability status:** Current workspace; local decision loops enabled, Cloud Eva production publication blocked
**Source authority:** Insight services, Eva runtime/coordinator, local authority policy, and canonical proposal pipeline
**Last verified:** 2026-08-25

**Roots:** Insights and EVA
**Related:** [Journal and Reflection](./JOURNAL_NOTES_AND_REFLECTION.md), [Local EVA architecture](../architecture/LOCAL_LLM_EVA_ARCHITECTURE.md), [Eva roadmap status](../eva/EVA_ROADMAP_STATUS.md)

## Promise and user jobs

Insights helps users interpret their own evidence without overstating certainty. Eva helps users understand the day, explore options, navigate LifeBoard, capture small updates, and make safe changes through an explicit provider choice and tiered authority boundary. Cloud Eva uses Luna when a guest or Apple-linked account, applicable 13+ policy, device trust, consent, quota, network, and signed policy are ready. Offline Eva uses an explicitly selected installed MLX model. Deterministic recovery keeps ordinary LifeBoard usable without either. The implementation sequence is maintained in the [Eva Intelligence Roadmap](../eva/EVA_INTELLIGENCE_ROADMAP.md).

Users come here to:

- understand trends and weekly patterns;
- inspect the evidence behind a claim;
- save, dismiss, snooze, or follow up on a reflection;
- ask what matters now or why a suggestion appeared;
- break down, schedule, defer, or repair work;
- open a named record or relevant app surface without hunting through navigation;
- capture a note, journal entry, body metric, water, mood, tracker update, or life moment in one sentence;
- teach Eva a durable preference and correct or delete it later;
- review a proposed change before applying it;
- stop generation, retry, continue, and undo applied work.

## Delivery status

The shared intelligence, navigation, capture, memory, evidence, proactive-policy, and first three decision-loop foundations are implemented. Make It Fit Today, Friction Detective, and Weekly Reset default on in Debug and Release and remain useful locally when Cloud Eva is unavailable. The signed 100% production policy is prepared but not published: remote preflight found the dedicated DeviceCheck secrets missing in staging and production. Physical-device, seeded-quality, privacy, cost, load, accessibility, and operational evidence remains open, so production enablement and graduation must be reported separately.

Use [Eva roadmap status and gap analysis](../eva/EVA_ROADMAP_STATUS.md) for the maintained “where we are / done / decisions / left” view. Product copy and support material must not describe an implemented primitive as production-enabled or a future arc as shipped.

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

EVA is an assistant layer, not a second task engine. It can explain, summarize, clarify, navigate, capture, and prepare proposals. Consequential changes pass through canonical mutations and an explicit review/apply boundary. A narrow low-risk capture class may auto-apply only after local policy verifies a today-only, same-kind batch of at most three reversible writes; the result is immediately visible with a durable receipt and Undo. The model never grants itself that authority.

### Product principles

1. **Help with the real job, not merely the prompt.** Use relevant Life OS evidence, current capacity, and constraints to produce an outcome the user can act on.
2. **Make authority legible.** Answers, navigation, suggestions, proposals, and completed captures look and read differently.
3. **Earn personalization.** Durable memory is inspectable, correctable, deletable, and never inferred into permanence without confirmation.
4. **Ground claims before adding confidence.** Evidence and source availability matter more than fluent certainty.
5. **Prefer calm recovery.** Offline, insufficient-context, ambiguity, quota, refusal, and partial-failure states offer the next safe step.
6. **Protect attention.** Proactive help is scarce, governed, dismissible, and never a quota to fill.

### Response taxonomy

| Result | User need | Eva behavior | State change |
|---|---|---|---|
| Answer | Understand, compare, reflect | Gives a grounded explanation with evidence where applicable | None |
| Clarification | Resolve material ambiguity | Asks one focused question or presents a small choice | None |
| Navigation | Reach an existing place | Opens a closed app target or locally resolved eligible record | Navigation only |
| Direct capture | Record a narrow reversible fact | Executes locally under deterministic policy and shows receipt/undo | Allowlisted local write |
| Proposal | Make a broader change | Shows an editable diff and applies only after confirmation | Canonical mutation after review |
| Limitation/recovery | Complete safely when a dependency or policy blocks the job | Explains the boundary and offers retry, offline, search, or manual path | None unless user chooses |

Eva should choose the lowest-authority result that completes the job. It must not turn a request for explanation into a mutation or a broad planning request into multiple direct captures.

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
- Navigation resolves closed targets and durable record references locally; the model never invents a route or record ID.
- Low-risk capture is classified and authorized locally, then returns an applied result card with Open and Undo.
- Proposal cards expose Apply, Edit, and Not Now.
- Apply validates authorization, current state, and schema before mutation.
- Results return to the originating root and identify partial/failure outcomes.
- Undo invokes the canonical inverse receipt, not a reconstructed guess.
- Cancellation is run-scoped so stale model output cannot appear in a later turn.

### Direct capture behavior

The immediate lane is limited to current-day body mass, note capture, journal append, hydration, mood, tracker delta, and life-moment append. The app attempts deterministic interpretation first; cloud capture is used only when broader language understanding is needed. Medication or dosage, calories/nutrition/fasting, historical/future entries, destructive edits, mixed broad batches, or invalid values are never auto-applied.

A successful receipt states exactly what changed, offers **Open** where a destination exists, and exposes **Undo** for 30 minutes. A network response is never rendered as completed until local persistence succeeds.

### Navigation behavior

Eva may return only closed destination kinds. General requests open a known surface; named requests are resolved locally. Multiple plausible records produce a chooser. Missing, protected, archived, or excluded records do not cause Eva to guess, reveal hidden existence, or substitute another similarly named record.

### Memory behavior

Eva may propose one concise memory candidate after an eligible turn. Save/edit is the activation boundary. Confirmed memory retains provenance and can be inspected, corrected, superseded, deleted, or disabled for cloud use. A repeated inference, assistant-authored claim, temporary mood, or protected/sensitive detail never becomes permanent merely through repetition.

### Context and privacy

Context is a bounded projection of route-relevant tasks, plans, capacity, calendar reality, goals, habits, day-loop state, retrospective, Knowledge, and eligible evidence. External calendar content is read-only. Journal, Health, Life Moments, and personal memory are independently deny-by-default and require the protected authorization path. Evidence Lens exclusions apply before generation across Eva, Insights, and Home. Offline Eva keeps prompts and projected context on device. Cloud Eva sends the prompt and only the authorized bounded projection through LifeBoard's Cloudflare service to OpenAI with `store: false`; the Worker retains no cloud chat or audio history. The exact provider is visible and remains fixed for the request.

Cloud Eva is guest-first; Sign in with Apple is an optional Protect & Sync upgrade. Cloud availability additionally requires applicable 13+ eligibility, iOS App Attest or Catalyst risk evidence, an authoritative consent revision, available rolling quota, and a verified signed configuration. A cloud failure offers “Try Offline” rather than silently switching providers. Spoken output is optional AI-generated `tts-1` audio; dictation/transcription stays on Apple's stack and full-duplex voice is out of scope.

Contract v4 makes the context receipt auditable: it carries temporal/surface turn context and a reason for every selected section. The route manifest is an upper bound, and the allocator admits complete records rather than slicing structured evidence to fill a window. Omitted data is treated as unknown, not absent from the user's life.

### Proactive Eva

Proactive help is a governed presentation of an eligible insight, never continuous background conversation or autonomous action. The deterministic governor requires current consent and evidence, rejects stale or duplicate candidates, applies a 0.65 probability floor, respects quiet hours, allows at most two proactive surfaces per day, and puts a topic into 21-day dormancy after two dismissals. The product should choose the least interruptive eligible surface; zero proactive messages is a valid and often preferable outcome.

## State matrix

| State | Insights | EVA |
|---|---|---|
| Empty | Explain evidence needed | Offer concrete starter prompts |
| Loading | Preserve chart/card geometry | Show truthful pipeline status and Stop |
| Insufficient evidence | State threshold/timeframe | Ask a clarifying question or explain limitation |
| Offline | Keep local reports available | Use the explicitly selected installed MLX provider or explain unavailable model |
| Model unavailable | Insights remains usable | Preserve draft; explain the failed cloud/local gate; offer setup, retry, or explicit Offline EVA |
| Streaming stopped | Not applicable | Keep settled text; expose Continue/Retry |
| Proposal stale | Evidence remains readable | Revalidate and explain changed inputs |
| Apply failure | Keep insight/source intact | Preserve proposal and provide recovery |
| Protected evidence locked | Redacted card | Authenticate before revealing/using evidence |
| Ambiguous navigation | Keep evidence intact | Show safe record choices instead of guessing |
| Capture rejected by policy | Not applicable | Explain review/manual path; do not show completion receipt |
| Capture completed | Not applicable | Show exact receipt, Open where available, and time-bounded Undo |
| Memory candidate | Not applicable | Show Save, Edit, Later, and Dismiss; remain inactive until confirmation |

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
- Cloud setup explains guest identity, optional Apple protection, 13+ policy, context, rolling quota, and processing. Offline model setup explains size, device support, progress, cancellation, and failure. Neither blocks non-assistant features.
- Receipts announce completed versus suggested state, and their Open/Undo actions have specific labels.
- Navigation disambiguation never relies on icon or color alone and does not expose protected previews.
- Insight dismissal, evidence exclusion, and memory edit/delete controls remain reachable at accessibility sizes.

## Success framework

| Outcome | Primary measure | Guardrail |
|---|---|---|
| Understand | Grounded useful completion and evidence-open rate | No unsupported material claim or excluded evidence influence |
| Decide | Plan/proposal usefulness and edit rate | Capacity and conflicts are not hidden to make a plan appear complete |
| Reach | Navigation success without repeat search | Protected/no-match behavior does not leak or guess |
| Capture | Successful uncorrected capture | Bounds, prohibited domains, idempotency, receipt, and undo always hold |
| Personalize | Confirmed-memory usefulness and fewer repeated corrections | Every memory remains inspectable and deletable |
| Reflect | Insight helpfulness/action rate | Dismissal, disable, and over-notification remain within qualification bands |
| Trust | Consent comprehension and accurate state language | No false completion, silent provider switch, or private content telemetry |

## Product acceptance criteria

- [ ] Every supported user job maps to one response type and one visible authority level.
- [ ] Answer, clarification, navigation, proposal, completed capture, failure, and offline states are visually and semantically distinct.
- [ ] Route-scoped context improves benchmark usefulness while subtraction and exclusion cases prove actual evidence dependence.
- [ ] Every navigation target covers exact, ambiguous, missing, stale, and protected outcomes.
- [ ] Every capture family covers value boundaries, malformed language, retry, persistence failure, receipt, and undo.
- [ ] Sensitive grants can be understood, changed, and revoked without disabling ordinary LifeBoard.
- [ ] Memory candidates never persist without the local confirmation transition.
- [ ] Two dismissals, quiet hours, daily cap, and probability floor produce deterministic proactive behavior.
- [ ] Streaming, Stop, Continue, review, execution, partial failure, and undo preserve accurate state across cancellation and relaunch.
- [ ] VoiceOver, keyboard, Dynamic Type, Reduce Motion, localization, and protected-data presentation are qualified on all supported platforms.

## Implementation and evidence

Primary anchors include local reflection/Insights services, Insights presentation, `EvaProviderRouter`, `EvaCloudProvider`, `EvaMLXProvider`, signed configuration and cloud account state, local LLM runtime/coordinator, run-scoped response delivery, route-scoped context projection, navigation resolver, capture authority policy, assistant proposal/diff validators, canonical action pipeline, assistant-action runs and undo, memory store, proactive governor, conversation views, spoken-output services, and the persistent composer. The complete cloud boundary is documented in [Cloud Eva Product and Technical Guide](../eva/CLOUD_EVA_PRODUCT_AND_TECHNICAL_GUIDE.md).

Primary controls include `evaFoundationModelsResponderEnabled`, `assistantApplyEnabled`, `assistantUndoEnabled`, `assistantCopilotEnabled`, `assistantSemanticRetrievalEnabled`, `assistantFastModeEnabled`, and `assistantBreakdownEnabled`. Disabling an optional assistant capability must leave deterministic evidence, drafts, conversations, and ordinary app workflows usable.

Recorded evidence covers deterministic reflection thresholds, evidence authorization, truthful work states, streaming/cancel/retry, proposal validation, Apply/Undo, and local trust boundaries. Saved-insight cross-surface completion, complete degraded-state fixtures, device memory/thermal behavior, and full model setup journeys remain active gates.

## Detailed references

- [Context and prompt architecture](../eva/CONTEXT_AND_PROMPT_ARCHITECTURE.md)
- [Navigation and capture authority](../eva/NAVIGATION_AND_CAPTURE_AUTHORITY.md)
- [Memory, evidence, and proactivity](../eva/MEMORY_EVIDENCE_AND_PROACTIVITY.md)
- [Evaluation and observability](../eva/EVALUATION_AND_OBSERVABILITY.md)
- [Privacy and data flow](../eva/PRIVACY_AND_DATA_FLOW.md)

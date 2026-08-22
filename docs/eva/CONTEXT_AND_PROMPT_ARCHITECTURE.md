# Eva context and prompt architecture

**Audience:** product, client, backend, privacy, QA, and applied-AI engineers
**Status:** canonical implementation reference
**Source of truth:** `Shared/EVACloudContracts`, `EvaTurnContextAssembler`, `EvaContextBudgetAllocator`, and the Cloudflare Worker prompt policy
**Verified against implementation:** 21 August 2026

## Purpose

Eva should feel informed without uploading the user's entire Life OS. The context system therefore does not treat a larger model window as permission to send more data indiscriminately. It uses that window to send better structured, better justified, and more complete evidence for the current job.

Every cloud turn must satisfy six obligations:

1. **Relevant:** include information that can materially improve this route and turn.
2. **Minimal:** omit unrelated data even when token capacity is available.
3. **Authorized:** sensitive categories require both route eligibility and current user consent.
4. **Explainable:** every section records why it was selected and what it contains.
5. **Structurally intact:** admit or drop whole records; never slice identifiers or create misleading fragments.
6. **Degradable:** if retrieval, authorization, or capacity fails, the turn either proceeds with an honest limitation or fails closed.

## Turn flow

```mermaid
flowchart LR
    U[User request] --> R[Route selection]
    R --> M[Route manifest]
    M --> A[Consent and exclusion checks]
    A --> Q[Typed and semantic retrieval]
    Q --> P[Selection provenance]
    P --> B[Whole-turn token budget]
    B --> E[Versioned context envelope]
    E --> C[Cloud contract validation]
    C --> L[Layered prompt]
    L --> O[Structured or conversational result]
    O --> D[Device authority and rendering]
```

The client owns retrieval and data authorization. The worker validates the envelope, constructs the provider prompt, executes the model, validates structured outputs, and returns a typed response. The device remains authoritative for navigation resolution and all local mutation.

## Contract evolution

| Version | Meaning | Compatibility rule |
|---|---|---|
| 1 | Original cloud request and basic context | Accepted only for legacy clients; no new client should emit it |
| 2 | Expanded shared contract | Accepted during migration |
| 3 | Typed section metadata and removal of conversation-summary transport | `conversationSummary` is rejected; section metadata is required |
| 4 | Turn context and explicit per-section selection reasons | Current emitted version; every inference request supplies `turnContext` and selection provenance |

The worker currently accepts versions 1–4 and emits version 4. Wire-contract version, prompt-policy identifier, planner schema version, and runtime-config schema version are separate version domains and must not be compared numerically.

## Turn context

`turnContext` describes temporal and surface conditions for the request, not the user's stored life data. Version 4 requires `requestedAt`, `localDate`, `calendarIdentifier`, `firstWeekday`, and one originating surface from the closed surface enum. The semantic route, locale, time zone, messages, and provider capabilities remain separate request fields.

`turnContext` deliberately contains no database identifiers. Explicit references live in typed context records and are still evidence, not mutation authority. A model-returned identifier must pass schema validation and the local resolver or executor.

## Context categories

| Category | What it represents | Typical use | Sensitive grant required |
|---|---|---|---|
| `planning` | Current tasks and actionable planning state | Chat, planning, prioritization, capture hints | No |
| `capacity` | Available time and workload constraints | Plan, top three, daily brief | No |
| `goals` | Active goals and their relationships | Planning, task suggestions, field suggestions | No |
| `habits` | Current habit definitions and recent adherence summaries | Planning and review | No |
| `dayLoop` | Current day-loop state and checkpoints | Daily brief, planning, retrospective | No |
| `retrospective` | Recent structured review signals | Planning and coaching | No |
| `calendar` | Relevant calendar windows and conflicts | Chat and scheduling decisions | No |
| `personalMemory` | User-confirmed preferences and durable facts | Personalized chat and planning | Yes |
| `knowledge` | Eligible notes and knowledge records | Chat, capture, knowledge answers | No |
| `journal` | User journal evidence that passes entry-level protection rules | Journal answers and explicitly eligible chat | Yes |
| `health` | Health-related summaries explicitly approved for cloud use | Eligible chat only | Yes |
| `lifeMoments` | Personal life-moment records explicitly approved for cloud use | Eligible chat only | Yes |
| `conversationSummary` | Legacy server-oriented summary transport | None | Prohibited in v3+ |

### Sensitive-data invariant

A sensitive section is admitted only when all of the following are true:

1. the route manifest permits the category;
2. the user has granted the category for cloud use;
3. the source record passes local protection and exclusion checks;
4. retrieval found relevant evidence;
5. the whole-turn allocator has room for the complete record;
6. the final contract validates the grant and section consistently.

Failing any condition means omission, not redaction followed by transmission. Empty permission flags never substitute for actual consent.

## Route manifest

The manifest is a hard upper bound, not a retrieval wish list.

| Turn route | Eligible context |
|---|---|
| `chat`, `shortcutsAnswer` | planning, capacity, calendar, goals, habits, personalMemory, dayLoop, retrospective, knowledge, journal, health, lifeMoments |
| `plan`, `planRepair`, `topThree`, `dailyBrief`, `dynamicChips` | planning, capacity, calendar, goals, habits, dayLoop, retrospective, personalMemory |
| `knowledgeAnswer` | knowledge |
| `journalAnswer` | journal |
| `memoryCandidate` | personal memory candidate input only |
| `fieldSuggestion`, `taskBreakdown` | planning, goals |
| `capture` | planning, goals, habits, knowledge |
| `navigation`, `universalInputClassification`, `debugSmoke` | none |

Adding a category to a route is a privacy and product change. It requires a threat review, subtraction evaluation, contract fixture, and documentation update—not just a manifest edit.

## Retrieval strategy

### Planning

Planning retrieval begins with typed task predicates, then semantically ranks eligible tasks for the current turn. It preserves task identity and structured fields. Overdue status may affect rank but is not a blanket filter: an overdue task can be the most relevant evidence for a request.

### Knowledge

Knowledge retrieval combines lexical relevance and Apple Natural Language embedding similarity. It excludes archived, locked, empty, or otherwise meaningless records before ranking and admits at most the top 12 eligible records before global budgeting. Retrieval records retain stable IDs so citations can open the source locally.

### Journal

Journal semantic retrieval runs only when the route manifest, category consent, and local journal-evidence setting all permit it. Each entry must also pass per-entry exclusion and protection rules. The absence of eligible journal context must never be described to the provider as evidence that no journal record exists.

### Evidence exclusions

Evidence Lens exclusions are enforced in the context projection layer. Excluded records do not enter Eva answers, insights, home projections, or their derived summaries. This prevents a downstream feature from accidentally reintroducing data that the user excluded upstream.

## Selection provenance

Every admitted section includes metadata describing its source records, size, sensitivity, and selection reasons. Version 4 permits only these reasons:

- `routeBaseline`: necessary background for the route's normal operation;
- `explicitReference`: directly selected or mentioned by the user;
- `semanticMatch`: retrieved because it is meaningfully similar to the request;
- `linkedRecord`: connected to another selected entity through a typed relationship;
- `operationalRisk`: needed to avoid a conflict, overload, or unsafe recommendation.

Selection reasons are observable engineering data, not prose exposed to the model as fact. At least one valid reason is required for every included section.

## Whole-turn budgeting

Context allocation is global rather than independently truncating each category.

1. Reserve space for system doctrine, route instructions, conversation messages, structured-output overhead, and the configured maximum response.
2. Build eligible records after manifest, consent, protection, and relevance checks.
3. Rank complete records within each category.
4. Admit records according to route-sensitive category priority.
5. Drop records that do not fit; never truncate an identifier or structured record.
6. Recompute section metadata and counts from the admitted set.
7. Validate the final envelope and enforce the maximum of 13 sections.

The baseline admission order is planning; capacity and calendar; goals, habits, personal memory, and knowledge; day loop and retrospective; then sensitive categories. The serialized cache-stable order is personal memory, goals, retrospective, habits, day loop, capacity, calendar, planning, knowledge, journal, health, and life moments.

### Route token caps

Runtime configuration may lower these fail-closed ceilings but may not exceed them.

| Route | Max input | Max output | Reasoning | Billable | Output |
|---|---:|---:|---|---|---|
| `chat` | 16,000 | 2,048 | medium | yes | text |
| `capture` | 8,000 | 1,200 | low | yes | structured |
| `navigation` | 4,000 | 512 | none | no | structured |
| `plan` | 32,000 | 4,096 | medium | yes | structured |
| `planRepair` | 32,000 | 4,096 | low | no | structured |
| `fieldSuggestion` | 8,000 | 1,200 | low | no | structured |
| `memoryCandidate` | 2,000 | 320 | none | no | structured |
| `topThree` | 8,000 | 1,200 | low | yes | structured |
| `taskBreakdown` | 8,000 | 1,200 | low | yes | structured |
| `dailyBrief` | 16,000 | 1,600 | medium | yes | structured |
| `universalInputClassification` | 2,000 | 512 | none | no | structured |
| `dynamicChips` | 2,000 | 512 | none | no | structured |
| `journalAnswer`, `knowledgeAnswer` | 16,000 | 1,600 | low | yes | text |
| `shortcutsAnswer` | 8,000 | 1,200 | low | yes | text |
| `debugSmoke` | 2,000 | 256 | none | no | structured |

“Billable” is an internal quota classification. It does not imply that a no-charge route has no provider cost.

## Prompt construction

The worker builds prompts in explicit layers:

1. **Stable doctrine:** identity, safety, authority, privacy, and non-fabrication rules.
2. **Route instruction:** the narrow job and response contract for this turn.
3. **User preferences:** clearly fenced, user-editable instructions treated as preferences rather than system authority.
4. **Context envelope:** typed, delimited, untrusted evidence with record provenance.
5. **Conversation messages:** role-preserving current-thread content.
6. **Output schema:** provider-enforced structured format where the route requires it.

Retrieved content is always untrusted data. Text inside a note, task, memory, or journal entry cannot override system or route instructions. Provider responses are also untrusted until decoded and validated.

### Prompt caching

The stable doctrine is separated from volatile turn data by an explicit cache breakpoint. Cache efficiency must never be improved by moving user data into the stable prefix or omitting authorization metadata. Changes to the doctrine increment the prompt-policy identifier and require regression evaluation.

## Degraded behavior

| Failure | Required behavior |
|---|---|
| Category retrieval fails | Omit the category, log a content-free diagnostic, and continue only if the answer can remain honest |
| Sensitive grant missing or inconsistent | Reject or omit the sensitive section; never infer consent |
| Context exceeds capacity | Drop lowest-priority whole records and update metadata |
| Contract version unsupported | Return a typed compatibility error before provider execution |
| Structured output fails validation | Use route-specific repair only where allowed; otherwise return a typed failure |
| Provider unavailable | Show an explicit unavailable state and eligible retry/offline choices |
| Citation target missing locally | Keep answer text, mark source unavailable, and do not navigate to a substitute record |

## Change checklist

- [ ] Update the shared schema and compatibility fixtures.
- [ ] Update the route manifest and fail-closed caps if applicable.
- [ ] Define consent, protection, retention, and deletion behavior for new data.
- [ ] Add positive, negative, and subtraction retrieval cases.
- [ ] Test prompt-injection content inside every new record type.
- [ ] Test whole-record admission at token boundaries.
- [ ] Verify section metadata and selection reasons after dropping records.
- [ ] Update privacy, API, evaluation, and product documents.
- [ ] Qualify the change behind signed runtime configuration before production enablement.

## Related documents

- [API contract](API_CONTRACT.md)
- [Privacy and data flow](PRIVACY_AND_DATA_FLOW.md)
- [Navigation and capture authority](NAVIGATION_AND_CAPTURE_AUTHORITY.md)
- [Memory, evidence, and proactivity](MEMORY_EVIDENCE_AND_PROACTIVITY.md)
- [Evaluation and observability](EVALUATION_AND_OBSERVABILITY.md)

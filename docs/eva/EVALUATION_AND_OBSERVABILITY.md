# Eva evaluation and observability

**Audience:** product, applied AI, client, backend, data, privacy, release, support, and QA
**Status:** canonical quality and operations contract
**Verified against implementation:** 21 August 2026

## Purpose

Eva quality is not equivalent to a model benchmark score. A useful turn must select the right context, avoid excluded data, follow authority policy, produce a valid structure, behave well in the interface, and remain operable at acceptable latency and cost. Evaluation and production observability therefore share a common outcome taxonomy.

## Quality model

Each evaluated turn is scored across independent dimensions:

| Dimension | Question |
|---|---|
| Intent | Did Eva understand the user's job and choose the correct route? |
| Retrieval | Did it select the necessary records and omit irrelevant ones? |
| Grounding | Are factual claims supported by admitted evidence? |
| Reasoning | Is the conclusion useful, internally coherent, and constraint-aware? |
| Authority | Did the result remain within navigation, proposal, or direct-capture policy? |
| Contract | Did requests and responses satisfy the versioned schema? |
| UX | Was state, uncertainty, completion, failure, and recovery communicated clearly? |
| Privacy | Did consent, exclusions, protected data, and telemetry minimization hold? |
| Reliability | Did the route meet latency, availability, repair, and retry expectations? |
| Efficiency | Was the quality appropriate for tokens, provider calls, cache use, and cost? |

A high aggregate score cannot compensate for a privacy or authority failure. Release gates include hard zero-tolerance dimensions.

## Test pyramid

### 1. Schema and deterministic policy tests

Fast tests cover:

- contract decoding and encoding for versions 1–4;
- strict structured-output schemas and unknown-field rejection;
- route manifest and fail-closed token caps;
- context selection reasons and maximum section count;
- consent, protected-record, and Evidence Lens exclusions;
- navigation target and record-kind drift fixtures;
- capture bounds, exclusion rules, idempotency, receipts, and undo;
- proactive frequency, probability, dormancy, and quiet-hour policy.

### 2. Context and prompt tests

Golden fixtures assert the complete provider request shape, including stable doctrine, route instruction, fenced preferences, untrusted context delimiters, message roles, output schema, and cache breakpoint. Boundary fixtures prove that the allocator drops whole records and recomputes metadata.

Prompt-injection fixtures place adversarial instructions inside every retrievable record type. Passing behavior treats those instructions as data and preserves system/route authority.

### 3. Offline model evaluation

A seeded corpus covers representative and adversarial tasks across chat, planning, repair, prioritization, brief, breakdown, field suggestion, capture, navigation, memory, knowledge, journal, shortcuts, chips, and classification.

Each case contains:

- synthetic or consented fixture data;
- user turn and expected semantic route;
- records that must be included and must be excluded;
- acceptable answer properties or exact structured result;
- authority level;
- expected evidence references;
- grading rubric and hard-failure conditions.

Use multiple fixed seeds where the provider supports them. Store the request policy/model/config versions with results so changes can be attributed.

### 4. Integrated client evaluation

Integration tests exercise the signed configuration path, authentication, request signing, streaming/non-streaming UI state, schema repair, local resolution, proposal review, execution, receipts, undo, evidence opening, offline behavior, and accessibility.

### 5. Production qualification

Production enablement requires a staged cohort, live operational dashboards, content-free sampling metrics, rollback controls, and documented sign-off from product, privacy/security, client, and backend owners.

## Essential evaluation suites

| Suite | What it proves |
|---|---|
| Baseline usefulness | Common jobs produce materially useful results |
| Context sufficiency | Required records are available to the model |
| Subtraction | Removing a key record changes claims that depended on it |
| Irrelevance | Adding unrelated records does not distort the answer |
| Exclusion | Protected or excluded records have no influence |
| Ambiguity | Eva asks, disambiguates, or proposes instead of guessing |
| Authority | Navigation and mutations remain within local policy |
| Adversarial content | Retrieved prompt injection cannot change instructions |
| Degradation | Timeouts, malformed output, missing citations, and offline states recover honestly |
| Regression | Provider, prompt, schema, and retrieval changes do not silently reduce quality |

Subtraction is especially important: a citation can look correct even when the model ignored it, and excluded data can influence an answer even when the citation is hidden.

## Product metrics

Metrics are segmented by route, app version, contract version, prompt policy, model, configuration cohort, locale, and broad device capability where privacy allows.

### North-star outcomes

- **Useful completion rate:** turns that produce the intended user outcome without immediate correction, retry, or abandonment.
- **Trusted action rate:** accepted proposals and direct captures that remain uncorrected after the reversal window.
- **Grounded usefulness:** useful answers whose material factual claims are supported by eligible evidence.

### Diagnostic metrics

- route selection accuracy;
- required-context recall and irrelevant-context rate;
- context utilization and tokens by category;
- evidence open and unavailable-source rates;
- capture correction, rejection, duplicate, and undo rates;
- navigation success, disambiguation, no-match, and protected-result rates;
- proposal edit and partial-execution rates;
- memory candidate accept, edit, reject, later-correct, and delete rates;
- insight open, action, dismiss, repeated-dismissal, and disable rates;
- proactive helpful action per interruption;
- schema failure and repair success;
- time to first visible state, total latency, provider error, and retry success;
- input/output tokens, cache hit, provider calls, and cost per useful completion.

### Hard guardrails

- zero known sensitive-context transmission without a valid grant;
- zero influence from excluded evidence in the qualification suite;
- zero unauthorized direct mutation families;
- zero silent provider fallback or false success receipts;
- no breach of proactive daily, quiet-hour, or dormancy limits;
- no raw prompt, response, record body, memory statement, or journal text in analytics.

## Trace and event model

Use distinct identifiers:

- `requestID`: one network attempt and its server logs;
- `runID`: the logical Eva operation across retries, repair, local execution, receipt, and undo;
- `threadID`: a user-visible conversation thread where applicable;
- idempotency key: retry identity for a mutation or billable operation.

Events should describe lifecycle and outcomes, for example requested, context assembled, provider started, schema repaired, proposal shown, action confirmed, execution completed, receipt undone, evidence opened, or failure classified.

Telemetry fields are allowlisted. Prefer enums, booleans, durations, byte/token counts, and coarse result counts. Never attach user text, record titles, identifiers that expose content, structured command bodies, or provider payloads.

## Operational dashboards

Minimum dashboards:

1. **Availability and latency:** success by route, percentile latency, timeout, provider error, config failure.
2. **Contract health:** client/contract versions, validation failures, repair attempts, unknown enum/route rejections.
3. **Context health:** sections and tokens by category, empty retrieval, grant mismatch, budget drops, citation availability.
4. **Authority health:** proposals, captures, local policy rejection, partial execution, undo, duplicate prevention.
5. **Quality signals:** retry, correction, abandonment, evidence open, navigation success, memory correction, insight dismissal.
6. **Cost and capacity:** provider calls, input/output tokens, cache performance, billable quota, cost per useful turn.
7. **Privacy controls:** aggregate exclusion and consent enforcement outcomes, with no content.

Alerts must point to a runbook play rather than merely crossing a chart threshold.

## Release gates

These gates are the quality and observability workstream of roadmap P0. They must pass alongside physical-device authority and privacy/operations qualification before a limited production cohort. See [Eva roadmap status and gap analysis](EVA_ROADMAP_STATUS.md).

| Gate | Required evidence |
|---|---|
| Contract | Shared schemas, fixtures, cross-language drift tests, compatibility tests pass |
| Quality | Route-specific offline evaluation meets approved bands with no hard failures |
| Context | Relevance, subtraction, exclusion, and prompt-injection suites pass |
| Authority | Capture/navigation/proposal/undo policy matrix passes |
| Privacy | Data-flow review, consent tests, retention/deletion validation, telemetry inspection pass |
| UX | Loading, empty, offline, error, retry, review, receipt, undo, and accessibility states pass |
| Operations | Staging soak, dashboards, alerts, budgets, kill switches, and rollback drill pass |

Any provider, model, prompt doctrine, retrieval policy, route manifest, schema, token cap, or authority change reopens the relevant gates.

## Failure taxonomy

Use stable, mutually exclusive primary failure classes:

- configuration or compatibility;
- authentication or entitlement;
- context retrieval or authorization;
- provider availability or capacity;
- provider safety refusal;
- output schema or repair;
- local policy or resolution;
- persistence or execution;
- presentation or cancellation;
- privacy invariant.

Keep provider-specific error codes as secondary diagnostics. Product behavior should depend on the stable class.

## Investigation workflow

1. Identify affected route, cohort, versions, and first bad release/config.
2. Use aggregate telemetry to choose the failure class.
3. Reproduce with synthetic or user-provided fixtures; do not fetch private content from production logs.
4. Compare context metadata, schema result, provider status, and local authority outcome.
5. Mitigate with the narrowest signed-config switch, route disable, cap reduction, or rollback.
6. Add a regression fixture before re-enablement.

## Documentation and test checklist

- [ ] Evaluation cases are versioned and reviewable like code.
- [ ] Every route has happy, boundary, adversarial, and degraded cases.
- [ ] Each metric has an owner, definition, source event, and privacy classification.
- [ ] Dashboards separate product failure from user cancellation or intentional exclusion.
- [ ] Alerts link to [the incident runbook](INCIDENT_RUNBOOK.md).
- [ ] Release notes identify model, prompt, retrieval, schema, and authority changes.
- [ ] Qualification results and approved exceptions are archived without private content.

## Related documents

- [Context and prompt architecture](CONTEXT_AND_PROMPT_ARCHITECTURE.md)
- [Navigation and capture authority](NAVIGATION_AND_CAPTURE_AUTHORITY.md)
- [Memory, evidence, and proactivity](MEMORY_EVIDENCE_AND_PROACTIVITY.md)
- [Backend runbook](BACKEND_RUNBOOK.md)
- [Incident runbook](INCIDENT_RUNBOOK.md)

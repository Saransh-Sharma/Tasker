# Future LifeOS Blueprint

> Classification: Future product blueprint — not shipped behavior
> Audience: Product, design, engineering, research, security, and leadership
> Capability status: FUTURE — UNIMPLEMENTED unless an item explicitly says partial
> Source authority: Product direction; never overrides the current Feature Catalog
> Last verified: 2026-08-13

> **Important:** Nothing in this document should be described to users as available. Current behavior is defined only by the [Feature Catalog](./FEATURE_CATALOG.md). A future item may reuse current tasks, goals, notes, or trackers, but the workflow described here remains unimplemented until its acceptance criteria are verified and its status is moved into the catalog.

## Blueprint-wide requirements

Every capability must use canonical records, provenance, explicit ownership, portable identifiers, local-first safe behavior, accessible text equivalents, and reversible mutations where feasible. Health is non-clinical, money is non-advisory, and shared/relationship data is consent-first. Automation may prepare or propose; it cannot silently create external commitments, disclose private context, spend money, contact people, or change protected records.

Rollout proceeds through: research and threat model → schema and migration → local single-user workflow → reliability/accessibility verification → guarded integration → optional collaboration. Success measures combine task completion with trust, correction rate, burden, accessibility, and data portability; engagement alone is insufficient.

## 1. Long-range direction

- **Outcome:** Connect daily choices to values, roles, life vision, and yearly/quarterly/monthly direction without turning values into scores.
- **Data:** Value, role, vision statement, horizon plan, theme, goal portfolio, review, alignment explanation, and evidence link.
- **Workflow:** Define values/roles → draft a horizon → select a small portfolio → connect existing goals/projects → run monthly/quarterly/life-area reviews → revise with an audit trail.
- **Privacy/safety:** Values and identity statements are sensitive, never used for advertising or coercive nudging. EVA distinguishes the user’s stated priorities from inferred patterns.
- **Failures/integrations:** Conflicting roles, abandoned horizons, sparse evidence, timezone/calendar shifts, and imported plan conflicts remain explainable. Calendar/tasks/goals are linked, not duplicated.
- **Success/dependencies:** Users can explain why current commitments exist, reduce abandoned commitments, and revise without losing history. Depends on goal linking, evidence, export, and proposal receipts.
- **Acceptance:** Create each horizon, link/unlink current entities, run a review, inspect provenance, export it, delete it, recover an interrupted edit, and verify no current screen claims inferred values as fact.

## 2. Work operating system

- **Outcome:** Run individual or team work through milestones, decisions, meetings, delegation, waiting-for, and workload forecasts while maintaining work/personal boundaries.
- **Data:** Milestone, deliverable, decision record, meeting note, attendee reference, delegated item, waiting-for state, workload forecast, boundary policy, and shared-project membership.
- **Workflow:** Plan milestone → prepare/capture meeting → record decisions/actions → delegate with explicit owner → track waiting-for → forecast capacity → close and review.
- **Privacy/safety:** Personal context is excluded from work sharing by default. Organizational access cannot reveal health, journal, or private-life signals. Clear ownership and revocation are required.
- **Failures/integrations:** Calendar/email/project-tool import, duplicates, revoked access, stale delegation, and offline edits need provenance and conflict resolution.
- **Success/dependencies:** Fewer lost decisions and overdue delegated items; realistic forecast accuracy; low accidental disclosure. Depends on identity, collaboration, notifications, conflict handling, and boundary policies.
- **Acceptance:** Complete an end-to-end milestone with meeting decision and delegation; revoke a collaborator; prove personal data is absent from exports and projections.

## 3. Home and life administration

- **Outcome:** Reliably manage household maintenance, errands, inventories, documents, subscriptions, bills, appointments, travel, vehicles, warranties, and recurring responsibilities.
- **Data:** Household/asset, inventory item, document, provider, subscription, bill schedule, appointment, itinerary, vehicle, warranty, maintenance plan, errand route, and responsibility owner.
- **Workflow:** Capture an obligation → attach documents/renewal terms → schedule reminders/tasks → complete or renew → retain receipt/history → review recurring costs and maintenance.
- **Privacy/safety:** Addresses, IDs, financial documents, travel, and household membership are sensitive. No silent vendor contact, purchase, cancellation, or location sharing.
- **Failures/integrations:** OCR errors, expired documents, price changes, duplicate bills, offline travel, timezone changes, and failed reminder delivery must be visible.
- **Success/dependencies:** Reduced missed renewals/appointments and faster document retrieval without increased unwanted alerts. Depends on secure files, recurrence, calendar, export, and future money/coordination layers.
- **Acceptance:** Manage one asset and one recurring obligation through reminder, completion, correction, export, and deletion with document access protected.

## 4. Health and care coordination

- **Outcome:** Organize symptoms, appointments, care plans, medications, labs/documents, preventative routines, recovery plans, and caregiver coordination without diagnosing or replacing clinicians.
- **Data:** Symptom observation, appointment, clinician/contact, care-plan instruction, medication plan/adherence event, lab/document, preventative schedule, recovery plan, caregiver grant, and escalation resource.
- **Workflow:** Record observation → prepare appointment → attach clinician-provided plan → schedule care actions → share a selected summary → review adherence/evidence → correct or revoke.
- **Privacy/safety:** Explicit non-clinical boundary; urgent symptoms route to appropriate emergency guidance, not EVA interpretation. Granular consent, encryption, access history, revocation, and minimum necessary disclosure are mandatory.
- **Failures/integrations:** Conflicting medication data, unit errors, unavailable protected Health data, revoked caregiver access, stale care plans, and failed reminders require high-salience recovery.
- **Success/dependencies:** Better appointment preparation and plan adherence with low correction and disclosure error rates. Depends on identity/access control, secure documents, Health provenance, notifications, and audit history.
- **Acceptance:** Demonstrate correction-safe medication and lab flows, selective caregiver export/share, revocation, emergency-language review, and no diagnosis or dosage recommendation.

## 5. Relationships

- **Outcome:** Remember people, important dates, commitments, check-ins, shared plans, gifts, and caregiving without instrumentalizing relationships.
- **Data:** Person record, relationship label, private note, date, commitment, check-in preference, shared plan, gift idea, care responsibility, consent grant, and contact provenance.
- **Workflow:** Add a person intentionally → record a commitment/date → choose reminder style → plan/check in → mark fulfilled or revise → selectively share a plan.
- **Privacy/safety:** No covert contact scraping, sentiment scoring, or inferred intimacy. Notes about another person remain private and are never shared without explicit review. Collaboration is consent-aware and revocable.
- **Failures/integrations:** Contact changes, duplicate people, changed relationships, deceased contacts, declined collaboration, and sensitive reminder contexts need humane handling.
- **Success/dependencies:** Fewer missed commitments with low reminder burden and zero accidental sharing. Depends on contact permission, moments, notifications, collaboration, and deletion/export.
- **Acceptance:** Handle merge, relationship change, consent/revocation, export, and deletion while keeping private notes out of shared views.

## 6. Money

- **Outcome:** Manage bills, subscriptions, budgets, savings goals, and financial routines with clear aggregation and advice boundaries.
- **Data:** Account reference, transaction/import provenance, merchant, category, bill, subscription, budget envelope, savings goal, recurring routine, consent grant, and export record.
- **Workflow:** Choose manual or connected setup → review imported data → classify/correct → schedule bills → plan budget/savings → review variance → export or disconnect.
- **Privacy/safety:** Non-advisory language; no trading, credit, tax, or investment recommendations. Credentials are never stored directly. Aggregation is opt-in, revocable, least-privilege, and provider-labeled.
- **Failures/integrations:** Delayed feeds, duplicates, reversals, currency/locale, shared transactions, disconnected institutions, and partial exports are explicit.
- **Success/dependencies:** Fewer missed bills and greater plan clarity, measured with correction and consent confidence. Depends on secure integration, provenance, recurrence, export, and future household permissions.
- **Acceptance:** Manual and connected scenarios reconcile correctly, disconnect preserves user-owned annotations, export is portable, and all advice language passes safety review.

## 7. Learning and growth

- **Outcome:** Turn courses, reading, and practice into a sustainable learning plan with evidence of skill growth.
- **Data:** Course/resource, reading item, skill, practice plan/session, spaced-review card, learning note, competency evidence, and goal link.
- **Workflow:** Choose a skill → collect resources → plan practice → capture notes/evidence → schedule spaced review → reflect and revise.
- **Privacy/safety:** Ability estimates are tentative, user-correctable, and never employment/education eligibility judgments.
- **Failures/integrations:** Broken links, changed editions, missed review queues, imported duplicates, and subjective evidence are labeled.
- **Success/dependencies:** Consistent practice and retrieval with low queue burden. Depends on Notes/Knowledge, goals, routines, calendar, semantic search, and evidence links.
- **Acceptance:** Complete a course/practice flow, produce linked evidence, reschedule a missed queue, export notes, and delete derived estimates.

## 8. Creativity and recreation

- **Outcome:** Protect idea capture, creative pipelines, events, leisure, collections, and deliberately unstructured time.
- **Data:** Idea, creative project/stage, draft/artifact, event, leisure wish, collection item, protected-time block, inspiration source, and reflection.
- **Workflow:** Capture without friction → optionally develop through stages → schedule or protect time → create/attend → archive/share/export → reflect without productivity scoring.
- **Privacy/safety:** Drafts and private tastes are not exposed or used to pressure output. Rights/source attribution accompanies imported inspiration.
- **Failures/integrations:** Large attachments, missing source files, event cancellation, sync conflict, and abandoned ideas remain recoverable.
- **Success/dependencies:** More protected recreation/creative follow-through without converting rest into obligation. Depends on capture, Knowledge, projects, calendar, attachments, and export.
- **Acceptance:** Preserve a raw idea, optionally promote it, protect unstructured time, handle cancellation/offline files, and export with provenance.

## 9. Shared coordination

- **Outcome:** Coordinate households, families, and teams through selective sharing, delegation, permissions, and explicit conflict handling.
- **Data:** Group, member, role, permission grant, shared object, assignment, acknowledgment, conflict version, activity event, and revocation.
- **Workflow:** Create group → invite with scope → share selected records → assign/accept → edit with visible authorship → resolve conflicts → leave/revoke/export.
- **Privacy/safety:** Private-by-default; no inferred sharing from life area or relationship. Child, caregiver, workplace, and household contexts require distinct policies. Every access has purpose, scope, and history.
- **Failures/integrations:** Invitation mismatch, offline concurrent edit, removed member, ownership transfer, abuse/reporting, and account loss require designed recovery.
- **Success/dependencies:** High assignment clarity and low conflict/disclosure rate. Depends on accounts/identity, encryption, portable ownership, notification controls, and complete audit history.
- **Acceptance:** Verify least-privilege matrices, concurrent edits, owner departure, revocation propagation, offline recovery, and selective export.

## 10. Data ownership and continuity

- **Outcome:** Make backup, restore, portable export, retention, encryption, account recovery, provenance, conflict resolution, and migration understandable and dependable.
- **Data:** Backup manifest, encryption/key metadata, export schema/version, retention policy, deletion tombstone, provenance event, conflict, migration, recovery credential, and audit event.
- **Workflow:** Configure backup → verify recoverability → export selected/all data → restore or migrate → resolve conflicts → inspect retention/access → delete with confirmation.
- **Privacy/safety:** End-to-end threat model, secure key recovery, no secret content in diagnostics, verifiable deletion, and documented legal/provider boundaries.
- **Failures/integrations:** Lost keys/devices, corrupt backup, version mismatch, partial export, CloudKit account change, duplicate restore, and interrupted migration have tested playbooks.
- **Success/dependencies:** Measured restore success, export completeness, conflict resolution, and recovery comprehension. This is a prerequisite for high-trust collaboration and financial/care expansion.
- **Acceptance:** Automated round-trip tests cover every schema, attachment, provenance record, deletion, downgrade boundary, and corrupted/partial backup case.

## 11. EVA evolution

- **Outcome:** Provide cross-horizon, proactive-but-bounded help with explainable recommendations and complete activity history.
- **Data:** Context grant by category/horizon, recommendation, evidence bundle, uncertainty, approval policy, automation rule, execution event, exception, and revocation.
- **Workflow:** Grant narrow context → ask or receive an eligible suggestion → inspect why/evidence → simulate diff → approve/edit/decline → execute within policy → inspect/undo/activity history.
- **Privacy/safety:** Local-first where feasible; remote context is separately granted per category. EVA cannot alter care, money, external communication, collaboration permissions, or destructive records without transaction-specific approval. No hidden background goals.
- **Failures/integrations:** Model unavailable, stale context, tool partial failure, policy conflict, hallucinated entity, and revoked consent stop execution and preserve an audit trail.
- **Success/dependencies:** Recommendation usefulness is secondary to explanation comprehension, correction rate, reversible success, and absence of unauthorized change. Depends on the data-ownership layer and mature domain APIs.
- **Acceptance:** Red-team cross-category leaks, prove policy enforcement under partial failures, show complete activity history, revoke context immediately, and restore every reversible proposal.

## Rollout governance

A blueprint capability graduates only when its schema, migration, permissions, threat model, empty/offline/error states, accessibility, export/deletion, analytics minimization, and end-to-end acceptance scenarios are verified. At graduation, its current behavior moves into the Feature Catalog and this document retains only remaining future scope.

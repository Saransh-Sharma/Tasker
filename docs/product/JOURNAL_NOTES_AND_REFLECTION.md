# Journal, Notes, Knowledge, and Reflection

**Classification:** Canonical feature contract

**Primary entry points:** Home, Universal Capture, Insights, EVA, Spotlight, and typed routes
**Privacy:** `privateSensitive` for Journal content/media and derived semantic data

## Promise and user jobs

Journal provides a private place to capture lived context and build reflection from the user’s own evidence. Notes and Knowledge preserve structured information without inheriting Journal’s emotional or biometric assumptions.

Users come here to:

- write, dictate, record audio, scan a document, or attach media;
- review recognized content before saving;
- search and revisit a day safely;
- recover missing/unavailable attachments without losing the entry’s structure;
- create notes and organize knowledge;
- open an evidence-linked weekly or proactive reflection;
- control lock, app-switcher shielding, indexing, and external exposure.

## Information architecture

### Journal day

A Journal day groups entries and attachments by captured time. The hierarchy is date/context, capture/add action, entries in temporal order, attachment state, and reflection/evidence routes. Editing preserves stable entry identity.

### Capture and review

Text may commit directly through the reviewed composer path. Document recognition, voice transcription, and media selection produce an editable review. Cancellation commits nothing; saving happens only after the user can inspect the result.

Audio follows save-first durability: the original recording remains authoritative when transcription is delayed or unavailable. Transcription is derived data and can be rebuilt without replacing the recording.

### Media and attachment recovery

Photos open in a dedicated viewer with zoom, reset, and system sharing. Missing or unavailable media retains its place and explains restore/removal options. A user-visible removal action must not masquerade as recovery.

### Search and Spotlight

In-app search can use authorized Journal content. Spotlight donations and widgets are redacted and content-free. A Spotlight result routes through the protected destination; it does not reveal entry text in system UI.

### Notes and Knowledge

Notes are structured private-standard content with stable identity, folders, links, and typed routes. Knowledge organization does not silently ingest Journal content. Cross-domain links are explicit and permission-aware.

### Reflection

Weekly and proactive reflection is built from deterministic eligibility and evidence links. Claims identify the supporting entries/records and use non-clinical language. Save, snooze, dismiss, and follow-up states are protected. A reflection can be useful while local generation is unavailable through deterministic summaries and explicit degraded states.

## Trust and privacy contract

- Journal routes authenticate before content is mounted.
- App-switcher shielding appears before protected snapshots can be captured.
- Logs, diagnostics, notifications, widgets, Spotlight, intents, and Watch previews contain no Journal text, prompts, media, embeddings, or mood-derived content.
- Derived indexes, semantic chunks, graphs, reflection caches, and tombstones inherit protection and deletion policy.
- Deletion propagates through the derived pipeline and blocks late re-ingest.
- Export/restore clearly distinguishes metadata, content, media availability, and corruption/wrong-password results.

## State matrix

| State | Required presentation | Recovery |
|---|---|---|
| Populated | Day context, entries, media state, and capture action | Open/edit/capture |
| Empty day | Quiet invitation without emotional pressure | Start writing or choose another capture |
| Recording | Persistent elapsed/status and explicit Stop/Cancel | Save durable audio or discard intentionally |
| Transcribing | Keep audio accessible; label derived work | Continue later/retry |
| Locked | Content-free privacy surface | Authenticate |
| Media unavailable | Preserve attachment block and metadata | Restore guidance or remove |
| Offline | Keep local capture/search available | Retry optional remote/external work later |
| Index rebuilding | Explain search limitations without blocking reading | Resume/retry rebuild |
| Error | Preserve draft or durable media | Retry, continue editing, or discard explicitly |
| Deleted | Remove canonical/derived projections and retain required tombstone | Undo only within supported receipt lifetime |

## UI/UX contract

- Journal uses reading surfaces with calm spacing; the capture action is obvious but not demanding.
- Required reading never sits on translucent glass.
- Media uses the approved one-shot reveal only when newly committed; revisiting content is stable.
- Reflection evidence is visually distinct from generated interpretation.
- Lock and recovery surfaces avoid content-derived thumbnails or counts that reveal sensitive context.
- Notes use denser utility layouts than Journal while preserving the same clay/paper system.

## Accessibility and platforms

- VoiceOver identifies entry type, date/time, attachment state, and available actions without reading hidden protected content.
- Dynamic Type keeps writing, Save, Cancel, and attachment recovery reachable.
- Document scanning and microphone/camera permission failures provide a non-media capture path.
- Watch capture uses a durable outbox, privacy-safe preview settings, queue status, retry, and acknowledgement.
- External surfaces route to protected content rather than reproducing it.

## Implementation and evidence

Primary anchors include the shared `JournalKit` products, LifeBoard Journal/Knowledge views, derived pipeline actor, protected route service, Journal security policy, Watch import/outbox contracts, Spotlight indexer, and reflection integration.

Primary flags are `journalV1Enabled`, `journalParityV1Enabled`, and `knowledgeNotesV1Enabled`. Flag rollback must preserve protected entries, attachment files, semantic derivatives, note identity, and migration state.

Recorded evidence covers shared package tests, protected routes, document review, audio/transcription, attachment recovery, deletion/index invalidation, Watch quarantine, and redacted external contracts. Mixed-video capture, complete parity screenshots, paired-device loss/retry, populated migration, and signed-device media workflows remain active gates.

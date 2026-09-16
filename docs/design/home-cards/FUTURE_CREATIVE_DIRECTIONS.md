# Future creative directions for LifeBoard

**Classification:** Creative research proposals — not the implementation contract

**Audience:** Product, design, and iOS engineering
**Capability status:** Unimplemented hypotheses; no delivery commitment
**Source authority:** Design exploration informed by [the current system](IMPLEMENTED_DESIGN_SYSTEM.md)
**Last verified:** 2026-09-16 (proposal review only)

These directions ask where artwork could improve orientation, ownership, and continuity. None adds work to the current reference-catalog completion scope. Priorities rank possible experiments after the existing release gates pass; they are not a roadmap promise.

Every experiment keeps semantic typography, shared section-header spacing, native controls, source identities, appearance/daypart independence, and privacy behavior. No direction may infer health state, fabricate progress, personalize from sensitive content without a separate explicit product contract, or add a per-card ambient animation loop.

## 1. More distinctive feature environments

**Exploration priority: 1 — recognition study before more production art.**

**Benefit and emotional character.** Help people recognize where they are before reading every heading. Plan could feel ordered and open; Journal sheltered and reflective; Care calm and dependable. The aim is orientation, not decorative intensity.

**Concrete experiment.** Compare the current Journal, Plan, and Nutrition headers with three more distinct panoramic environments. Journal: a shallow writing alcove with a soft fabric edge. Plan: broad paper planes and a pencil aligned toward open space. Nutrition: a matte kitchen worktop with neutral utensils and unmarked ceramic forms. Retain the same header height and button placement.

**Palette and composition.** Give each feature a modest supporting color relationship: Journal paper/wood, Plan paper/ochre, Nutrition clay/sage. Dark versions retain indigo/parchment readability. Avoid saturated violet outside Eva. Keep the leading title zone and trailing control zone quiet; recognition should survive substantial cropping.

**Unchanged.** Navigation labels, SF typography, shared section spacing, all actions, and the underlying semantic surfaces. Do not encode health or achievement in lighting or color.

**Constraints and dependencies.** Six trial illustrations (three appearance pairs), route-level screenshots, the existing header renderer, and a way to switch trial art in an isolated build. Use the same prepared-image cache and no extra mounted artwork layers. Protected/degraded headers suppress art normally.

**Acceptance experiment.** In a short unlabelled recognition exercise, participants should identify the feature more reliably than with current art; then complete the same labelled navigation tasks without slower reading or mis-taps. Inspect both appearances at the actual phone header height, not just a full-resolution art board. Retain only improvements that work after normal opacity/masking.

**Reasons to reject.** Differences vanish at runtime scale; participants mistake art for recorded content; a distinct environment needs taller headers; or palette differences weaken the shared app identity. A visually impressive full source that fails the header crop is not a success.

## 2. Composition-aware scene variants

**Exploration priority: 1 — highest likely framing benefit, narrow prototype scope.**

**Benefit and emotional character.** Make dense cards feel intentional and quiet. A shared square scene may crop well in a wide card but reveal an awkward object fragment in a very narrow, tall task list. Dedicated variants could improve framing without adding height.

**Concrete experiment.** Trial two Tasks compositions and two Journal compositions: a dense-content vertical wash, a horizontal reading-field composition, and their dark pairs. For Tasks, use broad paper texture and a pencil near a safe edge, with no drawn checklist. For Journal, use a wide desk plane whose notebook is recognizable without requiring the full scene.

**Palette and composition.** Keep the current family palette and painterly medium. Vary subject placement and depth, not saturation or foreground contrast. A dense variant could intentionally omit detailed objects; a wide variant could retain a horizontal tabletop. Keep essential subjects away from crop boundaries.

**Unchanged.** Existing presets, intrinsic heights, row budgets, native completion controls, and current actions. Variant selection is a presentation decision based on kind, available bounds, and content density, never inferred user performance.

**Constraints and dependencies.** A small `sceneVariant` resolver and explicit manifest usage mapping; approximately eight trial files for two families × two compositions × two appearances. Keep fallback pairing deterministic and avoid preloading every variant. Measure cache churn and retained pixels before extending the catalog.

**Acceptance experiment.** Compare current crop versus dedicated crop on Tasks Compact/Expanded and Journal Wide/Story using the same fixture. Review subject recognition, edge clipping, foreground readability, total height, and warm/cold image preparation. Adopt only if multiple reviewers consistently prefer the framing and there is no repeated decoding or meaningful memory regression.

**Reasons to reject.** Asset count grows faster than demonstrable improvement; variants become difficult to pair across appearances; resolver changes cause visual popping on minor width changes; or a simpler crop/opacity adjustment achieves the same result.

## 3. Connected visual storytelling

**Exploration priority: 3 — test continuity without turning navigation into scenery.**

**Benefit and emotional character.** Make related screens feel connected while keeping each destination clear. The relationship should be a subtle recognition cue, not a narrative about what the user has accomplished.

**Concrete experiment.** Use one botanical shape across Care's Home card, Care header, and medication composer. Its shape could reappear as a different crop, not as a plant that grows when medication is marked taken. Alternatively, share a paper edge between Quick Capture and Journal entry composition.

**Palette and composition.** Carry one material or silhouette through the flow. Adjust crop to each existing surface but keep a constant feature palette. Avoid a continuous panoramic image spanning unrelated scroll containers; each surface must remain independently legible.

**Unchanged.** Source ownership, routes, composer fields, privacy controls, and native confirmation receipts. No new decorative progress states, counters, or implied habit streaks.

**Constraints and dependencies.** Two or three paired assets, explicit family links in the manifest, and route fixture evidence. Privacy suppression applies independently at every destination. Reuse prepared pixels where suitable; do not mount hidden destination backgrounds just for continuity.

**Acceptance experiment.** Compare completion of a Home→Care→composer task with and without the shared motif. Ask whether participants understand their current location and the relationship between screens. Accept only if continuity helps orientation without creating false expectations about progress or data synchronization.

**Reasons to reject.** Motifs feel repetitive, compete with source photos, imply successful completion, or make visually different destinations harder to distinguish. Connected storytelling is optional; clear navigation already does essential work.

## 4. User-controlled aesthetic collections

**Exploration priority: 4 — validate demand before building collection infrastructure.**

**Benefit and emotional character.** Let people choose a comfortable visual character: botanical, architectural, or landscape. Personalization should express deliberate preference, not guesses derived from health records, journals, or conversation history.

**Concrete experiment.** Prototype a small appearance picker with three static Home previews covering the same Journal, Tasks, and Capacity content. Botanical uses muted leaves and natural materials; architectural uses quiet openings and planes; landscape uses horizons and terrain. Include the current collection as the default and a low-decoration option.

**Palette and composition.** All collections retain semantic surface/ink colors. Collection changes affect decorative subject and supporting hues, not the meaning of action colors or Eva violet. Each must work with both appearances and every daypart.

**Unchanged.** Layout, presets, data, navigation, accessibility preferences, section typography, and privacy rules. Do not bundle aesthetic choice with data access permissions.

**Constraints and dependencies.** First prototype only nine family scenes with paired appearances, no full-catalog commitment. A production version would need persistent collection choice, deterministic fallback, download/storage policy, asset-version migration, cache keys containing collection identity, and a declared decoded-memory budget. Selection must never fetch an entire library during scrolling.

**Acceptance experiment.** Test whether users notice a meaningful comfort/ownership benefit, can choose and revert without confusion, and still identify primary actions. Compare cold load, storage, and repeated collection switching. Decide whether the benefit justifies multiplying asset maintenance.

**Reasons to reject.** Users see little value; collection coverage is inconsistent; selection distracts from setup; or asset/storage/decode costs are disproportionate. Do not infer that more choices necessarily improve the product.

## 5. Meaningful transition moments

**Exploration priority: 5 — only after static layout and performance are settled.**

**Benefit and emotional character.** A short transition might clarify movement between a card and its destination or acknowledge a real saved action. The feeling should be continuity and closure, never pressure to maintain a streak.

**Concrete experiment.** Try one finite crossfade between Journal's Home art and its existing destination header during navigation, or a brief tint settling behind an existing save receipt after a real successful save. Do not invent an achievement or animate an unconfirmed mutation.

**Palette and composition.** Reuse the same artwork and semantic palette. Avoid zooms that expose soft low-resolution edges, strong parallax behind text, flashing highlights, or celebratory intensity around health records.

**Unchanged.** Existing navigation timing, Undo availability, motion preferences, VoiceOver announcement order, and data confirmation semantics. Art cannot delay an action or obscure failure recovery.

**Constraints and dependencies.** Existing transition coordination and motion budget, confirmed domain events, one finite animation, cancellation behavior, and Reduce Motion fallback. No animation timer on each card; no predecoded invisible destination scenes. A still transition must communicate the same action outcome.

**Acceptance experiment.** Prototype one route and one genuine save receipt. Measure navigation latency, frame hitches where available, peak memory, cancellation, rapid repeated navigation, and Reduce Motion. Ask whether the transition improves spatial understanding. Adopt only if that benefit is measurable and the existing screen motion budget is preserved.

**Reasons to reject.** Motion draws attention away from the receipt, suggests medical success, creates retained-image growth, delays input, or offers pleasure without a useful navigation benefit. Static continuity is preferable when it works equally well.

## 6. Media and illustration coexistence

**Exploration priority: 2 — protect ownership while improving mixed-content screens.**

**Benefit and emotional character.** Keep personal photos and memories recognizably the user's while preserving the app's visual coherence. Illustration should provide a quiet frame around personal content, not compete with or reinterpret it.

**Concrete experiment.** Compare a Life Moment with a photo, the same record without a photo, and a missing-image state. Repeat with Recent Meal. With user media present, test illustration only outside the media's owning region or remove it entirely, as the current policy does. Never generate a replacement image that looks like the user's missing photo.

**Palette and composition.** Use neutral paper/indigo surrounding surfaces. Any frame should avoid color sampling from sensitive media unless separately authorized and specified. Do not blend generated people or food into a real photo. Keep image ownership and source details accessible.

**Unchanged.** User-media precedence, privacy locks, source IDs, deletion behavior, edit/navigation actions, and the distinction between missing and empty. No automatic interpretation of meals, bodies, moods, or memories.

**Constraints and dependencies.** Synthetic or explicitly consented sample photos, existing media loaders, privacy fixtures, and clear loading/failure states. Account for combined photo and illustration decoded memory. Do not keep hidden generated decoration mounted beneath opaque photos.

**Acceptance experiment.** Ask participants to identify which image belongs to them and which is decorative. Test media loading, deletion, protected content, missing files, and navigation in both appearances. Accept only with unambiguous ownership, no layout jump, no decorative stand-in for missing content, and bounded image preparation/memory.

**Reasons to reject.** A frame makes user media feel secondary, attribution is ambiguous, generated decoration is mistaken for a recorded memory, or two simultaneous image layers increase costs without improving comprehension.

## Choosing the next experiment

Start with evidence from the current release: awkward crop examples support direction 2; weak feature recognition supports direction 1; mixed-media confusion supports direction 6. Directions 3–5 require a demonstrated user problem before asset production or infrastructure work. Record the hypothesis, compare against the current implementation, and retain a clear rejection option.

A future proposal becomes a product commitment only through a separate scoped decision. Neither this chapter nor its linked concept images marks a capability implemented, verified, or released.

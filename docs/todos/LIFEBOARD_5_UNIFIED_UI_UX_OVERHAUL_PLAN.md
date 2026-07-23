# LifeBoard 5.0 Unified UI/UX Overhaul Plan

Date: 2026-07-16  
Status: Proposed execution plan  
Supersedes: the UI/presentation portions of `LifeBoard 5.0 Phase I–IV Remaining-Work Execution Plan - CODEX 15th Jul.md`  
Does not supersede: `docs/life-os/phase-1-4-completion-audit.md`, which remains the production acceptance ledger

> **Historical planning reference:** The [remaining completion ledger](./LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md) owns current completion status. See the [implementation/design audit](../audits/LIFEBOARD_5_IMPLEMENTATION_AND_DESIGN_AUDIT_2026-07-23.md) for reviewed evidence and [DESIGN.md](../../DESIGN.md) for the active visual contract.

## Outcome

Rebuild every active LifeBoard presentation surface around one warm, personal, conversational visual system that is materially close to the supplied target screenshots while preserving the now-complete Phase I–IV domain, persistence, routing, privacy, planning, evidence, and receipt behavior.

The finished app should feel like a calm paper sunrise with precise native interaction: open layouts, minimal chrome, friendly copy, compact high-value information, selective Liquid Glass, spring-based continuity, and three restrained Metal signature moments. It must remain fully usable without transparency, motion, shaders, local-model support, Health/Calendar permission, network access, or large-screen space.

## Current Baseline and Guardrails

The 2026-07-16 worktree is the baseline, not the July 15 estimate:

- 96 focused tests pass in the current audit, with simulator coverage for all five roots, Home hierarchy/actions, four manual dayparts, compact accessibility sizes, regular-width iPad Home and Week, universal capture, Plan Day, Backlog deletion/undo/relaunch, habit resilience, and protected Weekly Reflection.
- Typed routing, repository requirements, Home hierarchy, tracker/care CRUD, Notes blocks/folders/attachments, Journal drafts/media/privacy/backup, Plan Day/Week/Backlog, Track resilience/history, normalized evidence, Eva runtime mounting, and Insights projections already exist. Do not rebuild them.
- Preserve `LifeBoardDestination`, `AppRoute`, dashboard placement identities, Core Data/SwiftData schemas, stable IDs, receipt semantics, evidence authorization, Journal protection, and all feature behavior proven by the completion audit.
- Keep the five roots exactly as **Home, Plan, Track, Insights, Eva**. The reference screenshots supply hierarchy, warmth, spacing, material, and interaction direction; they do not replace LifeBoard's current IA with Community/Search/More.
- Keep universal capture as the raised center action layer, not a sixth tab. Keep Search contextual/global through existing routes and Eva commands rather than adding another primary root.
- No Phase V+ product expansion, cloud AI, collaboration, new tracker domains, schema replacement, or wholesale TCA/architecture rewrite is part of this overhaul.
- Preserve every existing dirty-worktree change. Use additive visual adapters and delete old presentation code only after route, reference, and rollback checks pass.

## Visual and Interaction Contract

### One canonical visual system

- [x] Make `LifeBoardColorTokens` plus the existing spacing, radius, typography, motion, and signature-effect contracts the canonical implementation source (`make(palette:)` resolves the warm paper/cocoa system under `lifeOSUnifiedPresentationV2`, with the legacy sunrise palette retained as the documented rollback; `LifeBoardFoundationTypography` now uses SF Rounded for greetings/section titles).
- [x] Convert `LB*` Sunrise tokens/components into temporary compatibility wrappers over the canonical tokens (`LBColorTokens` navy/canvas/glass/gold/hairline/shadow constants now resolve to the warm palette; violet retained only as the assistant/focus domain accent).
- [ ] Update `LifeBoardSunriseGlassDesign.md` so its palette, five-root dock, background, and component guidance match this post-Phase-I–IV plan; remove obsolete Home/Calendar/Add/Insights/Profile navigation guidance.
- [ ] Add a guardrail that rejects new hard-coded UI colors, raw shadows, fixed app-wide font sizes, or direct glass use outside canonical token/component files.

### Reference art and palette

- [ ] Import the supplied `HomeBackground.png` as the exact Home backdrop and `ANotherBackground.png` as the exact secondary-screen backdrop, with explicit asset attribution/source notes.
- [ ] Render each asset top-aligned and aspect-filled behind the safe area, retaining its paper texture and natural blank lower field; never tile, stretch non-uniformly, or place text over a high-contrast crop.
- [x] Derive the functional palette from the active warm Foundation values: paper `#FFF7D8`, solid paper `#FFFDF7`, cocoa ink `#2B2118`, secondary ink `#746757`, sun `#F0CD87`, apricot `#E7BB7E`, sage `#C9C6BA`, and warm hairline `#E9DFC6`.
- [x] Reserve saturated color for semantic status and one primary action. Remove violet/blue as the default selection language from Foundation surfaces (a global cocoa-ink `.tint` on the shell resolves every default-tinted control to warm; Eva's chat chrome recolored to paper/cocoa; verified no blue remains on any of the five roots in the simulator).
- [ ] Apply daypart as a subtle art tint/atmospheric shift, never as a forced appearance mode. Dark appearance uses a designed warm-indigo/cocoa treatment of the same composition, not inversion.

### Typography and density

- [x] Use SF Pro Rounded for greetings, friendly section emphasis, and conversational states; use SF Pro Text for body/data; use monospaced digits only for time, duration, progress, and aligned metrics.
- [ ] Keep ordinary interface text on semantic Dynamic Type styles. Do not adopt the generic web-design font recommendation or bundle new fonts for this pass.
- [ ] Target compact reference-like metrics on standard iPhone: 16 pt screen margin, 20 pt section rhythm, 12 pt row rhythm, 16–22 pt content radii, 34 pt greeting, 20–22 pt section titles, 16–17 pt row titles, and 13–15 pt metadata.
- [ ] At accessibility sizes, stack metadata and actions, switch signal grids to horizontal/vertical scrolling as appropriate, and hide decoration before truncating task, care, schedule, or evidence content.

### Material and depth

- [ ] Use system **Regular Liquid Glass** only for navigation, tab chrome, floating capture, menus, compact filters, sheet headers, and the Eva composer.
- [ ] Use **Clear Liquid Glass** only for small controls directly over the supplied scenic backdrops, with a local dimming layer and verified contrast. Do not mix Regular and Clear in one chrome cluster.
- [x] Use opaque/translucent paper or shallow clay for content (shared `lifeBoardRaisedClayCard`/`lifeBoardFloatingClayCard`/`lifeBoardEmbeddedClayWell` primitives; glass confined to the dock and composer chrome, which sit on a solid canvas backing so no content reads through).
- [ ] Replace card-on-card nesting with open sections, separators, compact tiles, and whitespace. A card is justified only when it groups one decision, one summary, or one independently movable widget.
- [ ] Under Reduce Transparency, switch all glass to solid tokenized surfaces with stronger hairlines while preserving hierarchy.

### Motion, haptics, and shaders

- [ ] Keep four motion roles: press/selection 120–180 ms, local state 180–280 ms, route/sheet 280–450 ms, ambient/daypart 450–650 ms. Prefer interruptible springs and preserve gesture velocity.
- [ ] Use matched/zoom continuity for card-to-detail, capture-to-composer, evidence-chip-to-source, and media-to-Journal-detail transitions where identity is stable.
- [ ] Keep `daypartBloom` as a one-shot backdrop transition, `evaInkReveal` at paragraph/chunk boundaries for newly streamed content, and `journalMediaReveal` for newly committed media. Do not add continuous chromatic, glitch, shimmer, or text-distortion effects.
- [ ] Compile/load all signature shader functions off the main actor and record first-use frame timing; no interaction may hitch for more than 100 ms.
- [ ] Centralize haptics: selection for tabs/chips, soft impact for opening/placement, success only for committed completion/save/apply, warning only for blocked destructive work. Never vibrate for passive loading or every streamed token.
- [ ] `LifeBoardMotionPolicy` remains authoritative for Reduce Motion, Reduce Transparency, Low Power Mode, thermal pressure, scene activity, shader capability, and Catalyst fallback.

## Information Architecture and Surface Plan

### 1. Shell, navigation, and global interaction

- [x] Rebuild compact chrome as a floating glass dock with five equal tab targets, short labels, and a raised capture orb; removed the oversized footer and blank band (the dock is now a 30pt-radius glass capsule that floats over content).
- [x] Keep each root's independent typed `NavigationStack` and reselection-to-root behavior. Use a subtle selected well (the selected tab now gets a warm `foundationSurfaceSelected` capsule); tabs do not animate width.
- [x] Measure dock/capture/palette height and publish it through safe-area layout so the final row, keyboard, sheets, and accessibility content are never obscured (chrome height is measured via `onGeometryChange` and reserved per-root; a fade-into-canvas backing prevents any content resting under the composer).
- [ ] On iPad/Catalyst, use the existing expanded shell as a true adaptive split experience: five-root sidebar, destination content, optional detail/inspector column, toolbar capture, keyboard shortcuts, and pointer states. Do not scale the phone dock across wide windows.
- [ ] Put Settings/Profile in the Home contextual menu and native destination; keep low-frequency customization and privacy controls out of the primary dock.
- [ ] Route every “Why?”, “Help me decide,” “Replan,” and “Reflect with Eva” action into the same Eva conversation runtime with a typed origin/evidence context, then return applied/undone results to the originating root.

### 2. Home — high-fidelity reference surface

- [x] Treat Home as the visual acceptance reference before migrating other roots (Home locked with live time-of-day greeting, four gauge signal rings with liquid-fill hydration/fasting, one dominant Focus Now card, customizable "My Home" grid — verified in the simulator against the reference frames).
- [ ] Match the target reading order: compact mode row and Customize control; friendly greeting/date; one dominant Focus Now decision; four honest signal rings; contextual care; today's tasks; routines/habits; schedule/capacity; timeline; Journal/reflection; progress.
- [ ] Keep the Home background visible through open space. Stop wrapping every module in a full-width rounded rectangle.
- [ ] Size the normal greeting to one 34 pt line where possible, allow two lines at accessibility sizes, and keep the date directly below in secondary cocoa.
- [ ] Render four signal items as 56–64 pt rings with label above and value/state inside. Loading, setup required, stale, unavailable, and explicit zero must remain visually and semantically distinct.
- [ ] Present care/medication as a two-column compact tile grid when populated and as one quiet open row when empty. Never infer adherence or show a zero for unavailable data.
- [ ] Present tasks as open 56–64 pt rows with 44 pt completion targets, title first, one metadata line, and an optional restrained status chip; remove nested task cards and gamification as primary emphasis.
- [ ] Present routines/habits as a horizontal rail of compact tactile tiles, echoing the reference screenshots, with SF Symbols or curated art instead of emoji UI icons.
- [ ] Keep Focus Now as the only dominant Home card. Its primary action remains visible, its explanation is one line by default, and secondary reasoning moves to Eva/details.
- [ ] Ensure skeletons replace—not overlay—loaded content, preserve final geometry, and stop immediately when authoritative state arrives.
- [ ] Keep dashboard customization, but constrain user layouts below the mandatory orientation/focus/signals layer and preview changes in the same paper-sunrise system.

### 3. Plan — Day, Week, Backlog, Focus

- [ ] Use one compact scenic/paper header with Day/Week/Backlog lens control and the current date/capacity story; remove repeated title cards.
- [ ] Day defaults to a calm time narrative: fixed commitments, LifeBoard blocks, free windows, conflicts, and the next usable gap on one visual spine. Preserve Agenda fallback for VoiceOver, accessibility text, compact height, and Reduce Motion.
- [ ] Use shallow semantic blocks and direct manipulation for drag/move/resize; show snap/conflict feedback without turning the canvas into a dense calendar clone. Keep menu/keyboard alternatives and receipt-backed Undo visible.
- [ ] Week uses compact day summaries on iPhone and the existing seven-day drag board on regular width. Outcomes, minimum viable week, triage, and review remain progressively disclosed rather than stacked as competing dashboards.
- [ ] Backlog uses a sticky search/filter rail, open grouped rows, a bottom bulk-action tray only during selection, explicit destructive confirmation, and immediate receipt Undo.
- [ ] Focus uses a single calm timer plane, one task/context sentence, pause/end controls, a minimal Live Activity-consistent progress treatment, and a short reflective completion sheet.

### 4. Track — Today and domain modules

- [ ] Keep Track's current Today/Body/Mind/Routines/Goals/Library organization, but lead with today's required check-ins and recovery-critical items rather than a directory of modules.
- [ ] Use compact semantic tiles for hydration, mood, sleep, care, and generic trackers; show one value/state and one primary action, with history/details on tap.
- [ ] Make habit completion tactile and forgiving: visible tap control, optional swipe/drag delight, equivalent menu and VoiceOver actions, explicit skipped/recovered/off-day states, and a calm 30-day history.
- [ ] Keep routine and goal editors progressive: identity and next action first; schedule, branches, typed sources, provenance, history, and destructive actions in labeled disclosure sections.
- [ ] Use empty, permission, partial, stale, and error states as first-class compact surfaces with a clear next step. Do not show generic repository errors or raw IDs.

### 5. Eva — one conversational action layer

- [ ] Recompose Eva as a full-height conversation with the secondary paper-sunrise backdrop, a compact context header, a quiet transcript, and a keyboard-safe Regular Glass composer.
- [ ] Preserve a single conversation runtime and proposal pipeline. Remove any remaining visually separate “assistant cards” that behave like independent bots.
- [ ] Stream in readable paragraph/chunk units. Use a small thinking capsule with truthful activity text, a visible Stop action, and `evaInkReveal` only on newly settled content.
- [ ] Render evidence as compact, accessible chips attached to the relevant claim. Sensitive chips remain domain-only; missing/stale/withheld sources are explained in plain language.
- [ ] Render proposed mutations as a concise diff card with Apply, Edit, and Not now. Applying produces a success state with receipt-backed Undo; no conversational text can silently mutate data.
- [ ] Give attachments, slash commands, and contextual suggestions one expandable composer tray. Never rotate/wiggle controls or collapse while the user is interacting.
- [ ] Use Eva mascot art only for empty, celebration, or recovery moments; it must not occupy transcript space persistently.

### 6. Insights

- [ ] Preserve Today/Week/System scopes and normalized authorized evidence, but make each scope read as: interpretation, evidence completeness, one recommended action, compact metrics, optional detail.
- [ ] Replace giant metric cards with a compact strip or horizontal rail; keep charts simple, labeled, and accompanied by a text equivalent.
- [ ] Treat insufficient data as an honest story with source counts and the next useful capture/setup action, not a blank chart or fabricated trend.
- [ ] Open every evidence item through typed navigation and preserve the user's return position.

### 7. Journal, Notes, details, creation, settings, onboarding

- [ ] Journal uses quiet paper surfaces, grouped day entries, a focused composer, tactile media ordering, save-first audio states, and the existing protected lock/privacy boundary. Weekly Reflection should feel editorial, not analytical.
- [ ] Notes uses a clean document canvas with a compact block insertion control; tables, bookmarks, note links, images/files, folders, graph/list, retry, and missing-file recovery retain existing behavior without each block becoming a heavy card.
- [ ] Task, habit, project, routine, goal, tracker, care, and evidence details share one scaffold: identity/status hero, primary actions, progressive disclosure, history/provenance, and destructive actions last.
- [ ] Creation starts with title plus the one most likely timing/context choice. Advanced fields remain collapsed; save is pinned and reflects real `AsyncActionPhase` state with cancellation/retry where supported.
- [ ] Menus, confirmation dialogs, and sheets must always provide an escape hatch. Full-screen covers need visible Close/Done controls in addition to gestures.
- [ ] Settings groups appearance, comfort/motion, privacy, integrations, data, Eva, and About into short native sections using the secondary backdrop and paper rows; remove decorative cards around ordinary toggles.
- [ ] Restyle the existing eight-step onboarding as a friendly conversation using the supplied backgrounds, one decision per screen, visible progress, Back/Skip where safe, and no permission prompts inside the funnel.

### 8. Widgets, Live Activity, Watch, and system surfaces

- [ ] Apply the same warm paper/cocoa roles to existing widgets while respecting widget materials, privacy redaction, content margins, and glanceability. Do not reproduce the full in-app background in small widgets.
- [ ] Align Focus Live Activity/Lock Screen controls with the in-app focus state and semantic colors; storage remains authoritative and ActivityKit remains a projection.
- [ ] Bring existing Watch surfaces into typographic/color parity with large targets and reduced detail; do not add deferred Watch Journal features.
- [ ] Verify Spotlight, notification, widget, and deep-link previews never expose protected Journal/health content and always land on a recoverable typed route.

## Implementation Sequence

### Milestone 0 — Freeze truth and create the visual gate

- [ ] Preserve the current dirty worktree and record a fresh build/test/screenshot baseline before UI edits.
- [ ] Add `lifeOSUnifiedPresentationV2` as one rollback-compatible visual flag; it may alter composition and styling only, never domain/persistence behavior.
- [ ] Add reference screenshot fixtures for current Home and the supplied target, plus a route/state matrix covering every active root, leaf category, sheet, empty/loading/error/permission state, four dayparts, light/dark, and accessibility settings.
- [ ] Mark this file and the completion audit as the only active execution/checklist pair for this overhaul.

### Milestone 1 — Tokens, backdrops, primitives, and shell

- [ ] Import/validate the two supplied backgrounds, canonicalize tokens, and implement shared backdrop, paper section, compact tile, glass chrome, section header, async action, empty/error/permission, snackbar, and contextual Eva handoff primitives.
- [ ] Migrate compact and expanded shells, measured content clearance, menus, keyboard/pointer behavior, and profile/settings entry.
- [ ] Pass shell snapshots and navigation/capture/reselection UI tests before touching feature layouts.

### Milestone 2 — Home reference lock

- [ ] Rebuild Home to the target hierarchy and metrics, including all current availability states and customization behavior.
- [ ] Tune on a compact iPhone first, then validate large iPhone, landscape, iPad full/split, Catalyst, and every Dynamic Type category.
- [ ] Freeze Home visual baselines only after design review of Morning/Afternoon/Evening/Night in light and dark appearances.

### Milestone 3 — Plan and Track

- [ ] Migrate Day/Week/Backlog/Focus without changing planning receipts, day identity, drag behavior, or restoration.
- [ ] Migrate Track root, habits, routines, goals, care, trackers, histories, corrections, and source pickers without changing repository contracts.
- [ ] Run the existing seeded Plan/Backlog/Week/Habit-resilience journeys after each root migration.

### Milestone 4 — Eva, Insights, Journal, and Notes

- [ ] Unify contextual Eva entry, transcript, streaming, evidence, proposal/apply/undo, and composer presentation.
- [ ] Migrate Insights interpretation/evidence hierarchy.
- [ ] Migrate Journal, Weekly Reflection, Notes, Knowledge Graph/list, media/audio, export/import, and protected-route presentation while preserving privacy behavior.

### Milestone 5 — Remaining leaves and ecosystem surfaces

- [ ] Migrate task/habit/project/routine/goal/tracker/care details, capture/edit sheets, Search, Settings/Profile, onboarding, recovery/triage, and all modal/alert states.
- [ ] Restyle widgets, Live Activity, and current Watch surfaces without adding new capabilities.
- [ ] Remove temporary old/new visual mixtures from any navigable route.

### Milestone 6 — Signature polish, deletion, and promotion

- [ ] Tune springs, matched transitions, haptics, and the three signature shaders only after static layout and accessibility pass.
- [ ] Remove unreferenced duplicated Sunrise/Foundation visual constants and wrappers after runtime/test guardrails prove no route depends on them.
- [ ] Promote the visual flag only when the complete automated, simulator, signed-device, accessibility, and performance gates below pass; keep one-release rollback compatibility.

## Verification and Acceptance

### Automated

- [ ] Preserve all focused Phase I–IV tests and run the complete unit/UI schemes after each milestone.
- [ ] Preserve stable accessibility identifiers where semantics are unchanged; migrate tests in the same change when composition requires a new identifier.
- [ ] Add snapshot coverage for all five roots, representative leaf/detail, capture/edit sheets, Eva streaming/proposal/undo, Journal lock/media/reflection, Home customization, four dayparts, light/dark, Reduce Transparency, increased contrast, and accessibility Dynamic Type.
- [ ] Add component tests proving glass is confined to approved roles, content uses opaque paper surfaces, and Reduce Transparency resolves to solid surfaces.
- [ ] Add motion-policy tests for Reduce Motion, Low Power, thermal pressure, inactive scene, unsupported shaders, and Catalyst.
- [ ] Add a UI flow for every modal/full-screen cover proving dismiss, cancel, retry, and successful completion paths.

### Visual and UX acceptance

- [ ] Home must clearly match the supplied reference's warmth, hierarchy, open spacing, compact signals, task/care/habit density, and unobtrusive bottom navigation without copying its unrelated product IA.
- [ ] In a two-second glance, each root answers one question: Home “what needs me now?”, Plan “where can it fit?”, Track “what should I log or recover?”, Insights “what pattern matters?”, Eva “what can we decide together?”.
- [ ] No normal state shows nested full-width cards, glass on content, hidden primary actions, gesture-only actions, blank empty states, silent async failure, or loaded content beneath an active skeleton.
- [ ] Every interactive target is at least 44×44 pt; VoiceOver order follows visual order; keyboard/pointer focus is visible; color is never the only state cue; RTL preserves navigation and data meaning.
- [ ] Verify iPhone portrait/landscape, iPad full/split/slide-over, arbitrary Catalyst sizes, all Dynamic Type sizes, bold text, high contrast, Reduce Motion, and Reduce Transparency.

### Performance and release gates

- [ ] Preserve the existing budgets: Home/Track scroll at least 55 FPS p95 on the oldest supported signed device; no interaction hitch over 100 ms; atmosphere/shaders under 4 ms GPU per frame; signed-device cold launch under 2.5 s p95 after migration.
- [ ] Pause ambient/shader work when offscreen/inactive and avoid custom per-frame `body` recomputation for effects achievable with built-in transforms.
- [ ] Run ten-minute Home, Plan, Journal, and Eva stress sessions with less than 20 MB retained-memory growth and no thermal/energy runaway.
- [ ] Complete signed-device App Group, biometrics/file protection, widgets, Live Activities, Watch, local-model GPU, iCloud conflict, split-view, and Catalyst gates already remaining in the completion audit.
- [ ] Release with zero known critical-flow defects, zero touched-code warnings, complete third-party notices, approved reference screenshots, and a documented rollback toggle.

## Assumptions

- The supplied PNGs are approved product assets and may ship in the app; implementation will preserve originals and record their provenance.
- Functional truth in the current worktree and completion audit outranks older design documentation.
- “As close as possible” means adopting the target's emotional tone, composition, density, background art, and material behavior while retaining LifeBoard's current five-root IA and truthful data model.
- Premium motion clarifies real state and continuity. It never delays input, fabricates progress, obscures text, or bypasses accessibility/energy policy.
- The marketing web under `src/` is not part of this iOS execution plan.

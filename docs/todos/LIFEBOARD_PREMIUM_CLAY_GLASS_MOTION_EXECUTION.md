# LifeBoard Premium Clay, Glass & Motion Execution

Status legend: `[ ]` not started, `[-]` in progress, `[x]` implemented and locally reviewed, `[v]` simulator/build verified, `[!]` blocked with documented reason.

## Foundation and guardrails

- [v] Add `LifeBoardScreenScaffold` with ambient, detail, editor, utility, focused, and critical modes.
- [v] Add window-scoped shared-element namespace, glass identities, route helpers, and replay-safe one-shot coordination.
- [v] Expand motion roles to press, selection, local state, insertion, morph, reflow, direct manipulation, route, celebration, and ambient.
- [v] Resolve Calm/Balanced/Playful, accessibility, energy, thermal, Catalyst, scene, and focused-presentation policy centrally.
- [x] Add hero, reading, grouped, raised, selected, and destructive surface contexts plus metadata, action, and inverse foregrounds.
- [x] Add premium UI and changed-line token/motion guardrails.
- [x] Remove production Clear Glass call sites.
- [-] Remove remaining raw material/shadow/spring debt from legacy screens as each registered surface migrates; production Clear Glass and generic animation aliases are gone.

## Navigation and chrome

- [v] Install one transition host per app window.
- [v] Give capture and Eva composer glass stable semantic identities.
- [v] Add a spatially continuous selected dock pill and semantic selection feedback.
- [x] Keep bottom dock, capture, and composer on Regular Glass with opaque Reduce Transparency fallbacks.
- [-] Attach matched transition sources to task, habit, insight, journal, and project entry surfaces; task source/destination is implemented.
- [ ] Complete Eva attachment/voice/action composer morph states.

## Screen and surface registry

| Family | Default | Loading | Empty | Error/offline | Disabled | Destructive/presented | Status |
|---|---:|---:|---:|---:|---:|---:|---|
| Home / Plan / Track / Insights / Eva roots | reviewed | reviewed | reviewed | reviewed | reviewed | n/a | `[v]` existing celestial host retained |
| Secondary destination scaffold | reviewed | inherited | inherited | inherited | inherited | inherited | `[v]` canonical scaffold + clay cards |
| Settings root and sections | reviewed | n/a | reviewed | reviewed | reviewed | reviewed | `[v]` canonical utility scaffold + canonical cards |
| Bootstrap / sync recovery UIKit | reviewed | reviewed | n/a | reviewed | reviewed | reviewed | `[v]` semantic UIKit clay recovery card |
| Task / habit detail and editors | partial | partial | partial | partial | partial | partial | `[-]` route shell inherited; feature internals remain |
| Project / routine / goal routes | partial | partial | partial | partial | partial | partial | `[-]` |
| Journal / note / knowledge / focus routes | partial | partial | partial | partial | partial | partial | `[-]` |
| Search and filters | reviewed | n/a | reviewed | reviewed | reviewed | n/a | `[x]` reading surfaces moved to clay; chrome retained |
| Plan Repair / Overdue Rescue | reviewed | n/a | reviewed | reviewed | reviewed | reviewed | `[x]` velocity projection, threshold haptics, alternatives, undo retained |
| Shell capture, placement, audio, and scan-review sheets | reviewed | reviewed | reviewed | reviewed | reviewed | reviewed | `[v]` canonical presentation scaffold |
| Remaining feature-owned sheets and full-screen editors | partial | partial | partial | partial | partial | partial | `[-]` keyboard and presentation audit in progress |
| Onboarding | partial | reviewed | n/a | reviewed | reviewed | reviewed | `[-]` deliberate cinematic material exceptions under review |
| Apple-owned permission/EventKit controllers | native | native | native | native | native | native | `[x]` documented system-owned exemption |

## Interaction and feedback

- [x] Use velocity-aware commit prediction with minimum intent, cancellation spring-back, snap haptic, commit haptic, button alternatives, VoiceOver actions, and undo receipts in Overdue Rescue and Plan Repair.
- [x] Keep the existing completion particles, async action control, liquid progress, haptic vocabulary, shaders, and attribution as the only effect system.
- [x] Remove generic `snappy`, `bouncy`, `gentle`, `quick`, and expressive aliases and migrate their production/widget call sites to named roles.
- [x] Make milestone celebrations replay-safe per window, single-haptic, readable on clay, and bounded below one second.
- [-] Route remaining feature-local raw springs through named semantic roles.
- [ ] Add shared-element sources/destinations for the five approved content relationships.
- [v] Complete Plan Repair velocity/threshold/cancel/commit/accessibility parity and retain the planning mutation undo receipt.
- [ ] Audit one-shot milestone receipts against refresh, navigation return, and sync replay.

## Verification

- [v] iPhone Simulator app build after foundation and high-impact migrations.
- [v] Focused motion policy, one-shot, route identity, contrast, Plan Repair, and Overdue Rescue tests.
- [v] iPad Simulator build and standard-size night contrast smoke pass.
- [v] Mac Catalyst build; deterministic layout contracts compile, with manual 640/900/1280-point recording still pending.
- [x] Reduce Motion and Reduce Transparency policy/fallback tests; full gesture smoke pass remains.
- [ ] Record signature interaction evidence.

## Documented exemptions

- Apple-owned permission and EventKit controllers retain native visuals inside LifeBoard entry and exit surfaces.
- Material inside the shared Regular Glass compatibility adapter remains the pre-iOS-26 fallback.
- Decorative onboarding lensing may retain a bounded material implementation until its dedicated cinematic migration; it cannot contain required reading copy.
- Representative accessibility-size flows are verified; no bespoke XXXL redesign is required for every low-risk screen.

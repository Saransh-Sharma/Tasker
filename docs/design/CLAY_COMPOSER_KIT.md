# The clay composer kit

> Classification: Canonical design implementation reference
> Audience: Product, design, engineering, and QA
> Capability status: Current workspace
> Source authority: LifeBoard design-system composer components and tests
> Last verified: 2026-08-11

The data-entry layer of the LifeBoard design system. Lives in
`LifeBoard/DesignSystem/`, alongside `LifeBoardClaySurface` and the signature
effects it composes.

## Why it exists

The app's *screen containers* adopted the warm paper/cocoa clay language early.
Its *data entry* did not. Roughly twenty-five composer and settings sheets were
bare SwiftUI `Form`/`List` with stock `Picker`, `Stepper`, `Toggle`,
`DatePicker`, `.buttonStyle(.bordered)` and `.borderedProminent`, so they
rendered as grey iOS grouped forms inside a warm app. Ten of them did not even
carry `.lifeBoardFormSurface()` and sat on `systemGroupedBackground` — a cool
grey belonging to no part of this design system.

**`Form` is removed here, not restyled.** `Form` owns its row insets, its
separator geometry, its control chrome *and* its grouped background;
`.scrollContentBackground(.hidden)` only repaints the last of those. That is why
the previously "fixed" composers still read as grey forms wearing a warm
backdrop — the background was the only part the app ever controlled. A
`ScrollView` over clay sections is the only arrangement in which the corner
vocabulary (14/16/20/28), the 4/8/12/16/20 rhythm and the depth scale are ours.

## Containers

| Type | Use |
|---|---|
| `LifeBoardComposerScaffold` | A **presented** sheet. Owns the `NavigationStack`, canvas, cancel, and either a commit bar or a toolbar confirm action. |
| `LifeBoardComposerPage` | A **pushed** editor. Same canvas and commit inset, but leaves navigation to the host — nesting a second `NavigationStack` inside the one that pushed you strands the back button. |
| `LifeBoardComposerSection` | Grouped clay. Header, detail and footer stay on open canvas; only controls take a surface. DESIGN.md: a card is justified only when its contents form one independent decision. |
| `LifeBoardComposerRow` | Label + trailing control, 48 pt floor, reflows label-over-control at accessibility sizes rather than truncating. |
| `LifeBoardComposerCommitBar` | Failure banner + `LifeBoardCommitControl`, on Regular Liquid Glass. A commit bar is control chrome, which is exactly — and only — what the glass law reserves glass for. |

`LifeBoardComposerReceipt` / `LifeBoardComposerPhase` replace two byte-identical
private copies (`TrackComposerReceipt`, `TrackerCommitReceipt`) that existed only
because two host files cannot see each other's `private` types.

## Controls

| Type | Replaces |
|---|---|
| `LifeBoardComposerField` | `TextField`, single-line and `axis: .vertical` |
| `LifeBoardComposerNumberField` | numeric `TextField` + keyboard accessory `Done` |
| `LifeBoardClayToggleStyle` (`.lifeBoardClay`) | `Toggle`'s system switch |
| `LifeBoardMenuRow` | `Picker(.menu)` for closed sets > ~5 cases |
| `LifeBoardOptionRail` | `Picker` for closed sets ≤ ~6 cases |
| `LifeBoardDateCapsuleRow` | `DatePicker` |
| `LifeBoardBeadStepper` | `Stepper` over a bounded ordinal (1…5) |
| `LifeBoardComposerDial` | `Stepper` over a wide bounded range (0…20, 1…48) |
| `LifeBoardValueDrum` | free numeric entry (weight, waist, hydration target) |
| `LifeBoardDangerRow` | destructive row + its confirmation |
| `LifeBoardReorderableRows` | `List` + `.onMove` + `EditButton` |
| `LifeBoardLensPicker` (pre-existing) | `.pickerStyle(.segmented)` |

### Three rules that are not style preferences

1. **The clay switch is a `ToggleStyle`, never a `Button`.**
   `LifeBoardUITests.swift:409` drives `app.switches["Allow recovery
   completions"]`. Only a real `Toggle` reports as `.switch` to XCUITest and
   carries the toggle trait to VoiceOver. Restyling keeps those guarantees;
   replacing throws them away for a shape.

2. **Fields wrap real `TextField`s.** The tracker flow binds
   `app.textFields["track.tracker.name"]` and `…value.numeric` by element type.
   It is also simply correct: dictation, autocorrect, the caret, selection
   handles and the keyboard are free only if the field is real.

3. **Option rail ≠ lens picker.** The lens picker is a *view switcher* with one
   travelling thumb whose `matchedGeometryEffect` id is a global constant, so two
   on one screen fight over it. It stays reserved for `.pickerStyle(.segmented)`
   replacements. The option rail chooses a *value*, where labels vary in length
   and more than one per screen is normal.

## Section discipline (required)

A migrated composer's `body` holds **only** the container and one
`private struct …Section: View` per section — never a computed `some View`,
never a `@ViewBuilder func`. Both of those inline into the caller's frame.

This is not stylistic. `LifeBoardTrackFoundationViews.swift:193` documents the
hazard: at `-Onone` every SwiftUI temporary gets a stack slot, generic metadata
instantiation walks the 1 MB main-thread stack, and the result is
`EXC_BAD_ACCESS (code=2)` on the guard page **at launch, before a pixel is
drawn**. It will not appear in a Release smoke test. The migration makes it worse
before better, because `Form { A; B; C }` builds a shallow tuple of concrete
SwiftUI types whereas the scaffold builds a deeply nested generic one.

Keep `ViewBuilder` blocks to ≤ 6 children.

## Motion

Every control uses `.lifeBoardMotion(_:value:)` and `LifeBoardHaptic`, never a
raw `.spring(` or a bare feedback generator — the motion-law guardrail permits
spring geometry only inside `DesignSystem/`.

Success feedback is structural, not conventional: `successTrigger &+= 1` goes
*inside* the `if await save(...)` arm, so there is no code path that can fire a
completion burst optimistically.

## Known trap: `paperGrain` on a bare `Color`

`.lifeboardPaperGrain(intensity:)` is a `layerEffect`, and a `layerEffect`
applied to a bare `Color` — which has unbounded ideal size — **rasterizes to
nothing**. The view disappears entirely rather than gaining texture. This was
measured by sampling simulator pixels: a composer canvas rendered `#FFFDF7` (the
sheet's elevated fill) instead of `#FFF7D8` (warm paper).

Paint the flat canvas unconditionally, then put the grain on a shape with a
concrete frame:

```swift
ZStack {
    Color(LifeBoardColorTokens.foundationCanvas)
    GeometryReader { proxy in
        Rectangle()
            .fill(Color(LifeBoardColorTokens.foundationCanvas))
            .frame(width: proxy.size.width, height: proxy.size.height)
            .lifeboardPaperGrain(intensity: 0.42)
    }
}
.ignoresSafeArea()
```

Two pre-existing production call sites still use the broken pattern and are very
likely rendering no backdrop at all:
`LifeBoardDayCloseViews.swift:95` and `WeeklyPlanningWorkspaceView.swift:110`.

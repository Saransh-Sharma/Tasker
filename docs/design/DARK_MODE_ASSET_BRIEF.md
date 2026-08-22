# Dark-mode asset brief

Generated 2026-08-22 from an audit of `LifeBoard/Assets.xcassets` (104 imagesets)
and `LifeBoard/Features/Journal/Resources/Moods.xcassets` (30).

## The short version

**134 imagesets. Exactly 1 has a dark appearance variant** (`LaunchCanvas.colorset`,
which is a colorset, not an imageset). But only **18 actually need one.**

The deciding test is the alpha channel:

- **Opaque** (`hasAlpha: no`) — the asset carries its own background, so it stays
  light no matter what the canvas does. **These need a dark variant.**
- **Transparent** (`hasAlpha: yes`) — a sprite composited over whatever is behind
  it. These generally work in both appearances; only re-author one if its ink is
  so light or so dark that it disappears against the opposite canvas.

That takes the job from 134 assets to 18 — of which 3 are already dead (see below).

## How to add a variant once generated

Each imageset's `Contents.json` gains a second entry with
`"appearances": [{"appearance": "luminosity", "value": "dark"}]`. Xcode does this
for you by setting the imageset's **Appearances → Any, Dark** in the inspector and
dropping the dark file into the new well. Keep the same filename convention with a
`_Dark` suffix so the catalogue stays readable.

## Palette to generate against

Light canvas `#FFF7D8` · dark canvas `#151B2D` · dark surface `#202741` ·
dark ink `#F4EBDD`. Warm paper and cocoa by day; warm indigo and parchment by
night. The house voice is *calm, personal, unhurried* — not a productivity
dashboard. Avoid: neon, high-saturation gradients, glossy 3D, stock-photo people,
clutter, any text baked into the image.

---

# Tier 1 — Full-bleed scenes (highest impact)

These fill the entire screen behind every root. Today the renderer fakes dark by
crushing the light art: `.saturation(0.38).brightness(-0.36)` at
[LifeBoardAtmosphereRenderer.swift:448](../../LifeBoard/Foundation/Design/LifeBoardAtmosphereRenderer.swift).
That is a brightness hack — it desaturates the artwork rather than lighting the
scene for night. Real dark art lets those two compensations drop to `1.0 / 0`.

**Size: 941 × 1672 (portrait, ~9:16). Opaque, no alpha. No text.**

**Used by:** `LifeBoardAtmosphereRenderer.swift:184` (descriptor table, one row per
phase) and `TimeOfDayHeaderAsset.swift:66-72`. Rendered twice per screen — once
blurred at radius 90 as a bed, once sharp as the scenic plane. Because it is
blurred, **large soft shapes matter far more than fine detail.**

| Asset | Phase | Code-side fallback tint |
|---|---|---|
| `CelestialDawnBackground` | dawn | `#F2D6B6` |
| `CelestialMorningBackground` | morning | `#F4D9A8` |
| `CelestialMiddayBackground` | midday | `#EDC178` |
| `CelestialGoldenHourBackground` | golden hour | `#E7B875` |
| `CelestialTwilightBackground` | twilight | `#B7A5A2` |
| `CelestialNightBackground` | night | `#343545` |

**Prompt template** — substitute the phase description:

> A soft, abstract landscape horizon in deep indigo and warm charcoal, painted in
> flat gouache-like layers with visible paper grain. Rolling hill silhouettes
> recede into haze across the lower third; the upper two-thirds is open sky.
> {PHASE}. Muted and desaturated, no neon, no hard edges, no text, no people, no
> buildings. Calm and unhurried. Vertical composition 941×1672, subject weighted
> to the lower half so the top stays quiet for reading. Colour palette anchored on
> #151B2D and #202741 with a single warm accent.

Per-phase `{PHASE}` clauses:

- **Dawn** — "the first cold blue before sunrise, one thin band of warm rose along
  the horizon"
- **Morning** — "early indigo with a soft amber glow low on the left, stars just
  faded"
- **Midday** — "a deep twilight-blue sky standing in for daylight, brightest at
  the horizon, cool and even"
- **Golden hour** — "low warm amber light raking across the hills against a deep
  blue sky"
- **Twilight** — "violet and slate blue, the last warmth draining from the horizon"
- **Night** — "full night, deepest indigo, a faint cool moonglow and a scatter of
  small stars"

---

# Tier 2 — Card art with baked light backgrounds

## `TaskCard01` … `TaskCard06` — Eva focus cards

**Sizes:** `TaskCard01` 1254², `TaskCard02` 627², `TaskCard03`–`05` 1881²,
`TaskCard06` 1254². Square, opaque.

**Used by:** [SunriseEvaSheets.swift:1523](../../LifeBoard/Features/Eva/UI/SunriseEvaSheets.swift)
(`TaskHeroImage` enum) and rendered at `:836`. Each is paired with a near-white
`surfaceColor` hex (`#FFF4EA`, `#F4FAFF`, `#F4EEFF`, `#F2FAEE`, `#FFF0E6`,
`#FFF7EC`) that also has no dark counterpart — **fixing the art without also
fixing those six surface hexes will not solve the card.**

| Asset | Case | Subject |
|---|---|---|
| `TaskCard01` | `meditation` | a seated figure meditating |
| `TaskCard02` | `genericClouds` | soft clouds |
| `TaskCard03` | `recoveryLake` | a still lake |
| `TaskCard04` | `greenPath` | a green path |
| `TaskCard05` | `sunrisePath` | a path at sunrise |
| `TaskCard06` | `deskNotebook` | a desk with a notebook |

**Prompt template:**

> {SUBJECT}, illustrated in flat gouache layers with soft paper grain, at night.
> Deep indigo and warm charcoal palette anchored on #202741, lit by one restrained
> warm accent. Calm, spacious, slightly abstract — shapes over detail. No text, no
> faces, no logos, no harsh contrast. Square composition, subject centred with
> generous negative space so a title can sit over the upper third.

## `routine_morning_strip` / `routine_evening_strip`

**Size: 1086 × 362 (wide banner). Opaque.**

**Used by:** [TimelineRoutineAnchorVisualStyle.swift:57,65](../../LifeBoard/LifeBoardDesign/Components/TimelineRoutineAnchorVisualStyle.swift)
and [TimelineAnchorRitualTheme.swift:22,44](../../LifeBoard/Features/Home/UI/TimelineAnchorRitualTheme.swift).
Full-width art behind a routine anchor card on Home.

⚠️ Both files pair this art with **hardcoded light ink** (`#10264F` morning title,
`#3E5576` subtitle, `#FFF8EA` scrim) that has no dark variant. The art and the ink
must be re-authored together.

**Prompt:**

> A wide abstract banner, 1086×362, flat gouache layers with paper grain. {morning:
> "the very first light of day" | evening: "the last light fading"} rendered for a
> dark interface: deep indigo ground (#151B2D), one warm accent sweeping low across
> the frame, soft horizon shapes. Very low contrast so light text remains readable
> over any part of it. No text, no people, no hard edges.

## `HeroWelcomePoster`

**Size: 1928 × 1076 (landscape). Opaque.**

**Used by:** [LifeMapHeroBackdrop.swift:219](../../LifeBoard/Features/Onboarding/LifeMap/LifeMapHeroBackdrop.swift)
— full-screen behind onboarding.

⚠️ Onboarding is presented from UIKit **outside** `FoundationShell`, so it never
receives the appearance fixture; it follows the system setting only. It currently
survives dark because the poster is already dusk-toned — so this is the **lowest
priority** of Tier 2.

**Prompt:**

> A person seated on a hillside at dusk looking out over a soft valley of cloud,
> seen from behind at a distance, small in frame. Flat gouache illustration with
> paper grain, deep indigo and violet sky, one warm horizon glow. Peaceful,
> spacious, unhurried. Landscape 1928×1076 with the figure low and off-centre and
> the upper half quiet for a headline. No text, no faces, no logos.

---

# Already resolved — do not generate

`Neutral_Glow`, `Positive_Glow`, `Difficult_Glow` (627² opaque, **duplicated** in
both `LifeBoard/Assets.xcassets/LifeBoardJournal/Moods/` and
`LifeBoard/Features/Journal/Resources/Moods.xcassets/`).

These were indexed PNGs with a `PLTE` chunk and **no `tRNS`** — fully opaque
squares whose radial falloff had been flattened onto a light background. At 24%
over a light canvas they read as a faint halo; over the night canvas they rendered
as a visible grey box behind the mood face.

Replaced with a code-drawn `RadialGradient` in
[MoodDialHeader.swift:80](../../LifeBoard/Features/Journal/UI/MoodDial/MoodDialHeader.swift),
which has real alpha and picks up the per-mood daypart tint the theme already
computes. **`Mood.glowImage` now has no callers** — the six files are dead and can
be deleted in a cleanup pass.

---

# Not needed — transparent sprites (105)

These composite over the canvas and are fine in both appearances. Listed so nobody
re-audits them:

- **`EvaMascot/*`** (17) — mascot poses, `EvaMediaView.swift:405`
- **`SunriseDecor/*`** (13) — `OverdueRescueHeroes.swift`, `OverdueRescueDeckCards.swift`
- **`LifeBoardJournal/Moods/*`** + **`Moods.xcassets/*`** (~54) — mood faces and dial segments
- **`CelestialAtmospheres/Celestial{Dawn,Morning,Midday,GoldenHour,Twilight,Night}`**
  (6, 418² each) — the sun/moon sprites drawn *over* the scene at
  `LifeBoardAtmosphereRenderer.swift:562`. Transparent, and a moon reads correctly
  on either canvas.
- **`3D_icons/*`** (6), **`Buttons/*`** (4), **`TableViewCell/*`** (4),
  `LifeBoardLogo`, `LifeBoardSplashIcon`

**One caveat worth a glance:** four sprites are explicitly named `*_White`
(`material_add_White`, `material_day_White`, `material_done_White`,
`material_evening_White`) in `Material_Icons/`. White glyphs vanish on a light
canvas — check where they are drawn before assuming they are safe. They may
already be intentional white-on-accent.

---

# Suggested order

1. **Six celestial backgrounds** — every screen, every root. Biggest single win,
   and lets the renderer drop its brightness hack.
2. **Two routine strips** — paired with hardcoded light ink that must change with them.
3. **Six TaskCards** — paired with six near-white surface hexes that must change with them.
4. **HeroWelcomePoster** — currently survives; lowest priority.

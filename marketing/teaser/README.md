# LifeBoard launch films

Four hand-drawn films for the LifeBoard launch, every frame drawn by JavaScript on Canvas 2D with the
[hand-drawn-canvas-animation](https://github.com/alesha-pro/tools/tree/main/skills/hand-drawn-canvas-animation) skill
(MIT). No images, no libraries, no video model: one shared `core.js`, one shared `lifeboard-scenes.js`, and one small
HTML file per cut. Drawn at 12 fps on twos, packed to 24 fps. The score is Web Audio, written from the same timeline,
so every note lands on a cut.

## The idea: "A real day, drawn."

A day is scattered across the scraps of a life. It folds into one calm place. The app asks the questions LifeBoard
actually asks. The plan breaks and, instead of a red score, EVA helps you recover. The sun that rose in shot one lands
as the icon's eye.

- **The drawing rhythm carries "calm".** The scattered opening is the only shot whose outlines boil. At the fold, every
  texture goes still.
- **The anchor is the sun, and the sun is the clock.** It rises, crosses the frame through LifeBoard's own dayparts
  (morning, afternoon, evening, night palettes), sits in the Home header, is the Focus dial's centre, becomes the moon,
  and ends as the white square eye of the icon.
- **Labels are the app's own questions.** "What matters now?", "When should it happen?", "What am I doing now?",
  "What needs sustaining?", "What changed?", "What do I want to remember?", and Eva's "Ask. Review. Undo."
- **Recovery is the climax.** A block overruns, cards spill on a flash frame, EVA runs them onto tomorrow. Nothing turns
  red. "Plans break. You don't."
- **The icon is printed like a riso.** Blue, orange, yellow, purple, then the black profile, with the eye knocked out
  for the sun to land in.

## The cuts

| file | length | use |
|---|---|---|
| `bumper-6s.html` | 6.0 s | logo ident: sunrise, the sun crosses a day, lands as the eye, sign-off |
| `teaser-10s.html` | 9.5 s | the hook: scraps boil, blot, fold into one place, a day passes over the board, sign-off |
| `advert-30s.html` | 30.0 s | the spine: sunrise, scatter, blot, fold, Home, Plan, Focus, Track, Recover, Insights, Eva, gallery, sign-off |
| `launch-45s.html` | 45.0 s | the spine plus the seven life areas, Journal, Everywhere, Private by default, montage, platforms line |

Each film's HTML holds its beat sheet as a comment above the timeline. Every cut renders in 9:16 (1080x1920),
16:9 (1920x1080) and 1:1 (1080x1080) from the same code: scenes place everything relative to `CX, CY, W, H`.

## Scenes, one line each

| scene | what it shows |
|---|---|
| sunrise | dunes from the Home header; the sun rises with a hatch bloom; construction crosses; "Good morning." |
| scatter | thirteen scraps of a life (sticky note, calendar page, pills, receipt, shoe, book, glass, envelope, phone with badges, fork, heart, coin, dumbbell) boiling on the desk |
| blot | an ink blot reveals the blueprint: the same scraps in chalk and the operating loop (orient, capture, organize, plan, focus, recover, reflect, adapt) drawing itself |
| fold | hard cuts every three drawn frames: scraps gather, a written sheet, folded in half, a card, the board outline |
| home | the board is Home: hero card lifts, one honest empty signal ring, two tasks check with a completion burst |
| plan | blocks slide onto the time canvas, the capacity arc fills, the last block does not fit and goes to tomorrow |
| focus | the dial draws itself around the sun; the arc fills; speed lines on the pulse |
| track | habit hex cells fill one per drawn frame with bursts; one ring stays dashed |
| recover | a block overruns and crushes the others; ink splat and one flash frame; EVA runs the spilled cards to tomorrow's column with speed lines and wake loops |
| insights | an iris opens on night; cells light where habits happened; a chart line self-draws with sparks on the peaks |
| eva | EVA arrives through an ink blot; a half-second duotone beat in violet and sun; speech bubble, proposal card, receipt stamp, undo arrow drawn backwards, one jump after the receipt |
| gallery | the feature cards as riso badges on dashed rings, collapsing into the sun dot |
| print | the sun drops into the icon's eye with crayon ripples; plates print one by one; "LifeBoard" and the tagline in two inks |
| areas (45 s) | seven life-area badges: work, home, health, relationships, learning, creativity, money |
| journal (45 s) | pencil look: a wall of handwriting, a sticky note, a torn rose section rising with pressed plants, a thread down the page |
| everywhere (45 s) | phone, iPad and watch self-draw in chalk with the sun on every screen; a Live Activity pill |
| private (45 s) | a chalk house around the operating loop, a lock, construction lines |
| day (teaser) | the board holds while the sun arcs over it, the paper flickers to dusk, tally marks count the hours |
| arc (bumper) | the sun crosses the dunes; the paper flickers to dusk |

## Rendering

Needs Node 18+, ffmpeg, and a Chromium. On this Mac the Playwright Chrome for Testing is used; set `CHROME` to point at another.

```bash
npm i --no-audit --no-fund
node render.mjs advert-30s.html --grid 24 --ar 9:16 --out out/grid   # 24-frame sheet in seconds; look at it first
node render.mjs advert-30s.html --only 0,120,240 --ar 16:9 --out out/spot
node tools/score.mjs advert-30s.html out/advert-30s.wav              # headless score
bash build.sh                                                        # everything: 4 films x 3 formats, muxed, posters, contact sheets
bash build.sh teaser-10s                                             # one film
```

Outputs land in `out/final/`: `<film>-<format>.mp4` (with score), `<film>-<format>-silent.mp4`, `<film>-<format>-poster.png`
(last frame) and `<film>-<format>-contact.jpg` (two tiles per second). `out/` is gitignored.

Open any film HTML directly in a browser to scrub, play with sound, or export PNG frames and `score.wav` by hand.

## Editing

- `lifeboard-scenes.js` owns palettes (`lbMorning`, `lbAfternoon`, `lbEvening`, `lbNight`, `lbRiso`, `lbPencil`),
  layout (`LAYOUT()`), puppets (`drawEva`, `boardHome/Plan/Track`, `drawScraps`, `printIcon`), scenes (factories that
  take a duration) and score motifs (`scoreFromTimeline`).
- A film is just a `TIMELINE` of `{ name, dur, fn }`; scene names drive the score.
- Labels are one `handText` per shot through `label()`. Keep them under seven words.
- Rules from the skill still apply: `paper()` or `night()` first, `rng(seed)` only, no gradients or filters on the
  final canvas, hard cuts, one transition device between shots.

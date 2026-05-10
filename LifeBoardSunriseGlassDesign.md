---
version: "2.0.0"
name: "LifeBoard Sunrise Glass"
status: "radical-redesign-source-of-truth"
last_updated: "2026-05-08"
platforms:
  primary:
    - "iOS 16+"
    - "SwiftUI first"
  secondary:
    - "UIKit bridge surfaces"
    - "iOS widgets"
    - "watchOS widgets"
    - "marketing web"
format:
  front_matter: "normative machine-readable tokens"
  markdown_body: "human-readable rationale, rules, and component recipes"
product:
  name: "LifeBoard"
  promise: "A calm visual day command center for tasks, meetings, habits, routines, focus, and reflection."
  design_language: "Sunrise Glass"
  primary_feeling: "quiet morning clarity"
  primary_interaction_model: "glance, choose next step, act, recover, reflect"
  forbidden_visible_names:
    - "any previous product name"
  forbidden_positioning:
    - "clinical or diagnostic framing"
    - "shame-based productivity"
    - "punitive streak loss"
    - "autonomous schedule mutation"

ios_principles:
  hierarchy: "Make the next meaningful action visually obvious before secondary metrics."
  familiarity: "Use native iOS navigation, sheets, gestures, Dynamic Type, SF Symbols, haptics, and system materials."
  reachability: "Place frequent creation, completion, filter, and navigation actions inside comfortable thumb zones."
  deference: "Let the day content lead; chrome floats lightly and never becomes the product."
  depth: "Use glass, shadows, motion, and selected columns to clarify layers and temporal context."
  feedback: "Every tap, mutation, load, and failure gets a visible, reversible, accessible response."
  forgiveness: "Misses, overload, empty days, and errors are recoverable states, not failures."
  privacy_trust: "Assistant and calendar guidance stays explicit, reviewable, and bounded by visible user confirmation."
  accessibility: "Design for Dynamic Type, VoiceOver, Reduce Motion, Reduce Transparency, contrast, and large touch targets from the start."

colors:
  brand:
    navy: "#071B52"
    navy_soft: "#203765"
    navy_muted: "#3C4E78"
    violet: "#6842FF"
    violet_deep: "#4F2CFF"
    violet_soft: "#EEE9FF"
    violet_frost: "#F6F2FF"
    sunrise_gold: "#FFB300"
    sunrise_gold_deep: "#D88900"
    peach: "#FF7A3D"
    sky: "#2F8CFF"
    sea: "#14B8AE"
    leaf: "#28B53F"
    rose: "#F64F95"
  background:
    base: "#FFFDFC"
    warm: "#FFF8EF"
    cool: "#F7FBFF"
    dawn: "#FDF5EA"
    evening: "#FFF7E8"
    mist: "#F4F7FC"
  surface:
    glass: "#FFFFFFE8"
    glass_strong: "#FFFFFFF5"
    solid: "#FFFFFF"
    raised: "#FFFDF9"
    subtle: "#F8FAFF"
    lavender: "#F5F0FF"
    mint: "#EFF9EC"
    blue: "#EAF6FF"
    peach: "#FFF1E9"
    gold: "#FFF7DF"
    disabled: "#F4F5F8"
  text:
    primary: "#071B52"
    secondary: "#48607F"
    tertiary: "#7A8BA5"
    quaternary: "#A7B1C2"
    inverse: "#FFFFFF"
    link: "#563BFF"
    warning: "#9B6200"
    danger: "#A83A32"
  border:
    soft: "#E7EAF3"
    hairline: "#DDE3EE"
    glass: "#FFFFFFB8"
    violet: "#C9B8FF"
    warm: "#F4E0B8"
    mint: "#D6EFD3"
    blue: "#CFE9FF"
    peach: "#FFD8C5"
  semantic:
    routine:
      base: "#FFB300"
      deep: "#D88900"
      soft: "#FFF7DF"
      border: "#F6DE9A"
      icon: "sun.max"
    task:
      base: "#28B53F"
      deep: "#15952B"
      soft: "#EFF9EC"
      border: "#D6EFD3"
      icon: "checkmark.square"
    meeting:
      base: "#6842FF"
      deep: "#5230F3"
      soft: "#F4F0FF"
      border: "#E2D8FF"
      icon: "calendar"
    personal:
      base: "#FF6B2B"
      deep: "#C74716"
      soft: "#FFF1E9"
      border: "#FFD8C5"
      icon: "figure.walk"
    focus:
      base: "#2F8CFF"
      deep: "#1266D6"
      soft: "#EAF6FF"
      border: "#CFE9FF"
      icon: "sparkles"
    meal:
      base: "#F26C35"
      deep: "#B84312"
      soft: "#FFF0E8"
      border: "#FFD8C5"
      icon: "fork.knife"
    assistant:
      base: "#6842FF"
      deep: "#4F2CFF"
      soft: "#F6F2FF"
      border: "#DACDFF"
      icon: "sparkles"
    no_activity:
      base: "#F4F5F8"
      soft: "#FFFFFF"
      border: "#E6E9F0"
      icon: "minus"
  habits:
    green:
      100: "#DDF6D5"
      200: "#BFF1B2"
      300: "#93E580"
      400: "#68D763"
      500: "#35BF43"
      600: "#1DA132"
      700: "#0B7F24"
    orange:
      100: "#FFE7CE"
      200: "#FFD19D"
      300: "#FFB36A"
      400: "#FF9146"
      500: "#FF6A16"
      600: "#E7550D"
      700: "#B94308"
    blue:
      100: "#DDEFFF"
      200: "#B8DDFF"
      300: "#83C2FF"
      400: "#55A7FF"
      500: "#2F86FF"
      600: "#126CE6"
      700: "#0B55D8"
    purple:
      100: "#EEE3FF"
      200: "#D8C3FF"
      300: "#BC8EFF"
      400: "#A15BFA"
      500: "#8E42E6"
      600: "#7332C9"
      700: "#5D2CC6"
    yellow:
      100: "#FFF4C8"
      200: "#FFE999"
      300: "#FFE169"
      400: "#FFD23E"
      500: "#FFB800"
      600: "#D99400"
      700: "#AA6F00"
    teal:
      100: "#DDF5F2"
      200: "#B4ECE6"
      300: "#78DAD4"
      400: "#3CC9C1"
      500: "#19B8B3"
      600: "#0D9994"
      700: "#0A7B77"
    pink:
      100: "#FFE3EE"
      200: "#FFC1D9"
      300: "#FF8FBD"
      400: "#FF63A4"
      500: "#F63A87"
      600: "#D92772"
      700: "#AB1B58"
    indigo:
      100: "#E6E8FF"
      200: "#C8CDFF"
      300: "#9FA9FF"
      400: "#7585FF"
      500: "#5168FF"
      600: "#3650EA"
      700: "#2941D9"

gradients:
  primary_pill: "linear-gradient(135deg, #7048FF 0%, #5D32F4 100%)"
  primary_pill_pressed: "linear-gradient(135deg, #5F36F6 0%, #4726E6 100%)"
  hero_morning_overlay: "linear-gradient(180deg, rgba(224,243,255,0.18) 0%, rgba(255,246,223,0.42) 52%, rgba(255,253,252,1) 100%)"
  hero_reflective_overlay: "linear-gradient(180deg, rgba(218,232,255,0.22) 0%, rgba(255,238,218,0.42) 56%, rgba(255,253,252,1) 100%)"
  hero_evening_overlay: "linear-gradient(180deg, rgba(239,232,255,0.16) 0%, rgba(255,241,218,0.44) 60%, rgba(255,253,252,1) 100%)"
  wake_card: "linear-gradient(120deg, #FFF7DF 0%, #FFF0BE 56%, #FFFFFF 100%)"
  wind_down_card: "linear-gradient(120deg, #FFF9EC 0%, #FFFFFF 56%, #FFF2C9 100%)"
  task_card: "linear-gradient(100deg, #EFF9EC 0%, #FFFFFF 58%, #F4FCF1 100%)"
  meeting_card: "linear-gradient(100deg, #F4F0FF 0%, #FFFFFF 58%, #F7F3FF 100%)"
  personal_card: "linear-gradient(100deg, #FFF1E9 0%, #FFFFFF 58%, #FFF7F2 100%)"
  focus_card: "linear-gradient(100deg, #EAF6FF 0%, #FFFFFF 58%, #F5FBFF 100%)"
  assistant_card: "linear-gradient(100deg, #F6F2FF 0%, #FFFFFF 60%, #F1ECFF 100%)"
  glass_highlight: "linear-gradient(180deg, rgba(255,255,255,0.78) 0%, rgba(255,255,255,0.12) 100%)"

typography:
  fonts:
    brand: "New York, Cormorant Garamond, Fraunces, Georgia, serif"
    interface: "SF Pro Rounded, SF Pro Text, Avenir Next, Nunito Sans, system-ui, sans-serif"
    numeric: "SF Mono, SF Pro Rounded, ui-monospace, monospace"
  scale_ios_points:
    brand_wordmark:
      size: 48
      weight: 500
      line_height: 52
      tracking: -1.2
      font: "brand"
    screen_title:
      size: 31
      weight: 600
      line_height: 36
      tracking: -0.3
      font: "brand"
    section_title:
      size: 24
      weight: 600
      line_height: 29
      tracking: -0.2
      font: "brand"
    card_title:
      size: 16
      weight: 700
      line_height: 21
      tracking: -0.1
      font: "interface"
    body:
      size: 15
      weight: 500
      line_height: 21
      tracking: 0
      font: "interface"
    body_strong:
      size: 16
      weight: 700
      line_height: 22
      tracking: -0.1
      font: "interface"
    metadata:
      size: 13
      weight: 500
      line_height: 18
      tracking: 0.1
      font: "interface"
    chip_label:
      size: 17
      weight: 650
      line_height: 22
      tracking: -0.1
      font: "interface"
    overline:
      size: 12
      weight: 700
      line_height: 16
      tracking: 2.6
      font: "interface"
    date_number:
      size: 30
      weight: 700
      line_height: 32
      tracking: -0.3
      font: "numeric"
    timeline_time:
      size: 16
      weight: 650
      line_height: 20
      tracking: -0.1
      font: "numeric"

spacing:
  base: 4
  tokens:
    xxs: 2
    xs: 4
    sm: 8
    md: 12
    lg: 16
    xl: 20
    xxl: 24
    xxxl: 32
    section: 40
    hero_gap: 48
  layout:
    phone_horizontal_margin: 16
    phone_horizontal_margin_roomy: 20
    card_padding: 16
    large_card_padding: 22
    filter_gap: 10
    timeline_rail_width: 62
    timeline_card_gap: 12
    bottom_dock_safe_gap: 8
    sheet_padding: 20

radii:
  xs: 8
  sm: 12
  md: 16
  lg: 20
  xl: 24
  xxl: 30
  xxxl: 36
  pill: 999
  heatmap_cell: 2
  heatmap_selected_column: 18

sizes:
  touch_target_min: 44
  header_icon_button: 54
  date_pill_height: 54
  filter_chip_height: 50
  floating_add: 64
  bottom_dock_height: 92
  timeline_card_min_height: 66
  timeline_routine_card_min_height: 78
  timeline_icon_well: 42
  habit_row_height_full: 80
  habit_row_height_compact: 60
  habit_day_column_full: 46
  habit_day_column_preview: 38
  habit_label_column_full: 168
  habit_label_column_preview: 148

elevation:
  none: "none"
  hairline: "0 0 0 1px rgba(221,227,238,0.70)"
  glass_soft: "0 8px 24px rgba(7,27,82,0.08)"
  glass_card: "0 14px 40px rgba(7,27,82,0.10)"
  floating_control: "0 10px 26px rgba(7,27,82,0.14)"
  bottom_dock: "0 -8px 30px rgba(7,27,82,0.11)"
  violet_glow: "0 8px 24px rgba(104,66,255,0.24)"
  sun_glow: "0 6px 20px rgba(255,179,0,0.28)"
  selected_column: "0 10px 28px rgba(104,66,255,0.20)"

materials:
  glass_default:
    swiftui: ".regularMaterial"
    opacity: 0.92
    border: "border.glass"
    fallback: "surface.solid"
  glass_light:
    swiftui: ".ultraThinMaterial"
    opacity: 0.86
    border: "border.glass"
    fallback: "surface.glass_strong"
  glass_strong:
    swiftui: ".thinMaterial"
    opacity: 0.96
    border: "border.soft"
    fallback: "surface.solid"
  liquid_glass_ios26:
    use_for:
      - "floating controls"
      - "date navigator"
      - "bottom dock"
      - "small contextual action clusters"
    avoid_for:
      - "dense heatmaps"
      - "long text"
      - "error copy"
      - "forms with more than three fields"
    fallback_ios16_to_ios25: "Material plus subtle border plus soft shadow"

motion:
  timing:
    press: "90-140ms"
    chip_selection: "180-220ms"
    date_change: "240-320ms"
    card_entrance: "180-260ms"
    habit_fill: "160-220ms"
    sheet: "280-360ms"
  easing:
    standard: "cubic-bezier(0.16, 1, 0.3, 1)"
    spring_low_bounce: "interactive spring, damping 0.82-0.90"
  haptics:
    selection: "filter/date changes"
    light: "card press, habit hover/preview"
    success: "explicit completion only"
    warning: "destructive or irreversible confirmation only"

components:
  hero_header:
    height_phone: "250-330pt"
    background: "scenic sunrise illustration with vertical fade to background.base"
    content: "menu button, bell button, centered wordmark, greeting overline, date navigator, relative-day chip"
  icon_button:
    size: "54pt"
    radius: "pill"
    fill: "glass_default"
    icon_color: "brand.navy"
    shadow: "floating_control"
  date_navigator:
    pill_height: "54pt"
    pill_radius: "pill"
    fill: "glass_default"
    side_button_size: "54pt"
    icon: "calendar"
  filter_chip:
    inactive_fill: "glass_default"
    active_fill: "gradient.primary_pill"
    height: "50pt"
    radius: "pill"
    icon_size: "21pt"
  timeline_card:
    radius: "lg"
    fill: "semantic gradient by role"
    border: "semantic border"
    min_height: "66pt"
    padding: "14pt 16pt"
  meeting_flock:
    radius: "lg"
    fill: "meeting_card"
    nested_row_fill: "surface.glass_strong"
    max_visible_nested_rows_phone: 3
  habit_matrix:
    selected_column_border: "2pt border.violet"
    selected_column_shadow: "selected_column"
    cell_gap: "1pt white divider"
    no_activity_fill: "semantic.no_activity.soft"
  bottom_dock:
    height: "92pt plus safe area"
    fill: "glass_default"
    radius: "xxl"
    center_add_size: "64pt"
    active_color: "brand.violet"
---

# LifeBoard Sunrise Glass Design System

This file is the visual source of truth for LifeBoard. It intentionally replaces the current repo visual language with a new iOS-native, pastel, calm, premium direction called **Sunrise Glass**.

LifeBoard should feel like opening a quiet morning window onto the day: schedule reality is visible, tasks are actionable, habits are colorful but forgiving, and every screen helps the user understand what matters now without pressure.

## 0. Repo scan synthesis

The current repository already has useful product architecture. Keep the product model; replace the visual system.

### Keep from the current product model

- **Single day command center**: Home should continue to combine tasks, schedule context, routines, focus blocks, habit cues, and assistant guidance.
- **Task-first timeline**: The timeline should remain a readable day narrative, not a miniature calendar grid.
- **Read-only calendar boundary**: External calendar events are observed constraints. LifeBoard can explain, sequence, and propose changes to LifeBoard-owned items, but it must not imply it edited outside calendar events.
- **Habit truth model**: Keep explicit habit states such as completed, pending today, future, skipped, bridge, and missed. The redesign changes how they look, not the honest state model.
- **Confirmation-first assistant**: Assistant suggestions stay reviewable, sparse, and tied to visible schedule or task context.
- **SwiftUI-first implementation**: Rebuild new components in SwiftUI, with UIKit bridges only where existing surfaces require them.
- **Widget continuity**: Widgets should reuse LifeBoard semantic roles and typography, but become lighter and more sunrise-glass aligned.

### Discard from the current visual language

- Forest/ivory/magenta/marigold as the dominant brand look.
- Dark cinematic marketing as the primary expression of the product.
- Points, badges, levels, and achievement mechanics as the visual center of Home.
- Dense top chrome, hidden menus, and small utility controls that compete with the day.
- Heavy animated mesh backgrounds behind operational UI.
- Strong warning/error coloring for normal overload, misses, or carry-over.
- Generic list-card styling for tasks and habits.
- Mascot-first assistant placement that competes with the user's schedule and next action.

### Rewrite priority

1. **New token layer**: introduce LifeBoard color, typography, spacing, radius, material, elevation, semantic role, and habit palette tokens.
2. **New Home shell**: scenic hero, centered LifeBoard wordmark, date navigator, relative-day chip, filter row, timeline spine.
3. **New timeline cards**: semantic pastel cards for routine, task, meeting, personal, focus, meal, and wind-down.
4. **New habit matrix**: selected-day column, continuous heatmap, non-punitive no-activity states, stable color families.
5. **New bottom dock**: iOS-native glass navigation with raised central add action.
6. **New creation sheets**: calm bottom sheets with native date/time pickers and progressive disclosure.
7. **New widgets and marketing visuals**: same navy/violet/sunrise system, less dark chrome.

## 1. North Star

LifeBoard turns the day into a calm visual narrative. The user should know three things within two seconds:

1. What day they are looking at.
2. What is fixed versus flexible.
3. What the next small action is.

The design must create **clarity without pressure**. The screenshots define the target emotional world: sunrise landscapes, glass controls, deep navy type, warm rituals, pastel event cards, colorful habit heatmaps, and a sense of progress that accumulates gently.

Design mantra:

> Small steps, big changes.

## 2. iOS-native design laws

Sunrise Glass is expressive, but it must feel native on iPhone.

### 2.1 Hierarchy before decoration

Every screen needs one primary reading path. Scenic imagery sets the emotional atmosphere; it must never fight text, controls, or state. Decorative hills, birds, sparkles, and gradients are allowed only when they reinforce time of day, category, or progress.

### 2.2 Thumb-first reachability

Frequent actions belong in comfortable thumb zones:

- Add/create: bottom center floating action.
- Complete/check off: within timeline cards, with 44pt effective hit area.
- Filters: below date context, horizontally scrollable if needed.
- Date navigation: large pills and 54pt side buttons.
- Secondary tools: menus, sheets, or trailing icon controls.

Avoid packing critical controls in the top-right corner. Top chrome should orient; bottom chrome should act.

### 2.3 Familiar system behavior

Use native patterns unless there is a strong product reason not to:

- `NavigationStack` for hierarchy.
- `TabView` or a custom dock that preserves tab-bar mental model.
- Native sheets for scoped creation/editing.
- Menus for secondary filters and low-frequency settings.
- Native date/time pickers inside LifeBoard-styled sheets.
- SF Symbols for icons.
- System haptics for selection and completion.
- Dynamic Type and VoiceOver as default behaviors, not bolt-ons.

### 2.4 Progressive disclosure

The day view is not an analytics dashboard. Show the next useful layer, then reveal detail on tap.

- Collapse overlapping meetings into a flock.
- Put deep habit analytics behind the Habit Progress screen.
- Put full assistant reasoning behind a prompt card or chat surface.
- Keep filters simple at the top; move advanced filters into a sheet.
- Show only the most relevant metric on Home; summarize the rest.

### 2.5 Feedback and reversibility

Every mutation must produce a visible result:

- Completion: cell/card changes immediately, haptic success, undo when appropriate.
- Error: calm inline banner or snackbar explaining what stayed unchanged.
- Loading: skeletons or shimmer that preserve layout.
- Assistant proposal: explicit confirm/apply, no silent mutation.
- Calendar context: disclose missing, stale, or partial data.

### 2.6 Forgiving progress

LifeBoard must never make normal human drift feel like failure. Misses are information. Recovery is a first-class path.

Use supportive states:

- `No activity`
- `Due today`
- `Skipped`
- `Not scheduled`
- `Restarted`
- `Protected gap`
- `Moved with confirmation`

Avoid punitive labels, red failure blocks, and streak-loss drama.

## 3. Visual language: Sunrise Glass

### 3.1 Personality

Sunrise Glass is:

- Calm, luminous, and optimistic.
- Premium but not corporate.
- Warm enough for personal routines and reflective planning.
- Structured enough for work meetings and task execution.
- Colorful where progress matters, quiet where choices can overwhelm.

### 3.2 Signature ingredients

- **Scenic dawn headers**: soft illustrated landscapes with sun, clouds, mist, water, road, meadow, or hills.
- **Deep navy typography**: never default black for app UI.
- **Frosted glass controls**: large pills and circles with soft shadows and white borders.
- **Pastel semantic cards**: each role has a stable hue and soft gradient.
- **Left timeline spine**: the day reads vertically with colored dots and sparse curved connectors.
- **Habit heatmaps**: continuous color fields with a selected-day column.
- **Violet interaction layer**: active filters, selected dates, primary add, assistant sparkles.
- **Gold routine layer**: wake, wind-down, sun icons, notification dots, warm anchors.

### 3.3 What Sunrise Glass is not

- Not a dense calendar clone.
- Not a generic checklist app.
- Not a game dashboard.
- Not neon, cyber, dark SaaS, or enterprise gray.
- Not a mascot-centered experience.
- Not a punishment system.

## 4. Color system

### 4.1 Brand colors

- **Navy `#071B52`** is the LifeBoard ink: logo, headings, primary text, major icons.
- **Violet `#6842FF`** is selection and primary action: active chips, today column, add button, assistant hints.
- **Gold `#FFB300`** is ritual and optimism: sun, wake, wind-down, warm notifications.
- **Sky `#2F8CFF`** is focus and hydration calm.
- **Leaf `#28B53F`** is action completion and task momentum.
- **Peach `#FF7A3D`** is personal energy, movement, lunch, errands.
- **Sea `#14B8AE`** is creative practice, steady focus, secondary habit progress.
- **Rose `#F64F95`** is sparing delight for wellness rows, never primary navigation.

### 4.2 Semantic role mapping

Use semantic role colors everywhere: timeline dot, icon, time text, border, tag, and accessibility label.

| Role | Color | Soft surface | Use |
|---|---:|---:|---|
| Routine | `#FFB300` | `#FFF7DF` | Wake, wind-down, morning/evening anchors |
| Task | `#28B53F` | `#EFF9EC` | LifeBoard-owned actionable tasks |
| Meeting | `#6842FF` | `#F4F0FF` | External or fixed schedule commitments |
| Personal | `#FF6B2B` | `#FFF1E9` | Movement, errands, personal time |
| Focus | `#2F8CFF` | `#EAF6FF` | Deep work and protected focus blocks |
| Meal | `#F26C35` | `#FFF0E8` | Lunch, dinner, breaks |
| Assistant | `#6842FF` | `#F6F2FF` | Guidance prompts, sparkles, review cards |
| No activity | `#F4F5F8` | `#FFFFFF` | Empty habit cells and neutral states |

### 4.3 Color rules

- Never use red for ordinary habit misses or overdue pressure.
- Use red only for destructive confirmations, irreversible errors, or data loss risk.
- Do not use violet for every icon. Violet means selected, meeting, or assistant.
- Do not put low-contrast gray text on pastel cards. Use navy/secondary blue-gray.
- Habit colors must be stable per habit family; do not randomize on each render.
- Use opacity and fill intensity for streak strength, not moral judgment.

## 5. Typography

LifeBoard uses a refined serif for brand and editorial section titles, paired with rounded system typography for product UI.

### 5.1 Typeface stack

- **Brand and titles**: New York, Cormorant Garamond, Fraunces, Georgia, serif.
- **Interface**: SF Pro Rounded, SF Pro Text, Avenir Next, Nunito Sans, system sans.
- **Numbers**: monospaced digits where alignment matters: times, dates, streaks, percentages.

Use licensed custom fonts only if the app bundle has rights. The native fallback must look excellent.

### 5.2 Type hierarchy

| Token | iOS size | Weight | Use |
|---|---:|---:|---|
| Brand wordmark | 46-50pt | 500 | `LifeBoard` centered in header |
| Screen title | 30-32pt | 600 | Habits, Habit Progress, Today’s Plan |
| Section title | 22-24pt | 600 | Large card headers |
| Date selector | 20-21pt | 600 | `May 13, Tuesday` |
| Card title | 16-17pt | 700 | Timeline card titles |
| Card time | 14-15pt | 650 | Semantic time ranges |
| Body | 15pt | 500 | Descriptions |
| Metadata | 13pt | 500 | Team, attendees, helper text |
| Chip label | 16-17pt | 650 | Filter chips |
| Overline | 12pt | 700 | GOOD MORNING, LOOKING BACK |
| Date number | 28-30pt | 700 | Habit board date headers |

### 5.3 Dynamic Type rules

- Use scalable text styles or token wrappers that respect Dynamic Type.
- At accessibility sizes, the timeline becomes a stacked agenda with larger row heights.
- Hide decorative card art before truncating title or time.
- Never cap Dynamic Type globally. Limit only a specific decorative wordmark if necessary.
- Habit heatmap cells remain visual, but VoiceOver must provide full date + habit + state.

## 6. Layout system

### 6.1 Mobile shell

Primary target is iPhone portrait.

Recommended structure:

1. Status bar over scenic header.
2. Top left menu circle and top right bell circle.
3. Centered LifeBoard wordmark.
4. Greeting overline with small sun/sparkle.
5. Date navigator row.
6. Relative-day chip.
7. Filter row.
8. Main content: timeline or habit board.
9. Optional bottom dock.

### 6.2 Screen margins

- Standard phone margin: 16pt.
- Roomy phone margin: 20pt.
- Large card internal padding: 20-24pt.
- Timeline rail width: 62pt.
- Filter chip gap: 10-12pt.
- Timeline card gap: 12-16pt.

### 6.3 Safe areas

- Hero artwork can extend behind the status bar.
- Interactive controls respect safe areas.
- Bottom dock includes safe-area padding and never covers the last scrollable item.
- Sheets use 20pt horizontal padding and 28-32pt top radius.

### 6.4 Adaptive layout

Small iPhone:

- Reduce horizontal margin to 14-16pt.
- Hide secondary card subtitles first.
- Keep time, title, icon, and status visible.
- Allow filter row horizontal scrolling.

Large iPhone:

- Keep hero height generous.
- Add vertical breathing room between day zones.
- Show habit summary metrics inline.

Accessibility sizes:

- Stack card metadata vertically.
- Increase row heights.
- Use grouped habit-cell interaction instead of forcing tiny tap cells.

## 7. Materials, glass, and depth

### 7.1 Glass usage

Use glass on navigation and controls, not on dense data.

Good glass targets:

- Header menu and bell buttons.
- Date selector and side chevrons.
- Filter chips.
- Bottom dock.
- Floating add button rim.
- Small assistant prompt cards.
- Sheet headers.

Avoid glass for:

- Dense heatmap cells.
- Long paragraphs.
- Error messages.
- Multi-field forms.
- Any surface where background contrast would reduce readability.

### 7.2 iOS material strategy

- iOS 26+: use system Liquid Glass APIs on small controls where available.
- iOS 16-25: use `.regularMaterial`, `.thinMaterial`, or a custom white translucent fill with border and shadow.
- Reduce Transparency: replace glass with solid white, increase border opacity, remove refractive effects.

### 7.3 Shadows

Shadows should look like sunlight through glass:

- Controls: `0 10px 26px rgba(7,27,82,0.14)`.
- Large cards: `0 14px 40px rgba(7,27,82,0.10)`.
- Bottom dock: `0 -8px 30px rgba(7,27,82,0.11)`.
- Selected habit column: violet glow at low opacity.
- No harsh black shadows.

## 8. Iconography

Use SF Symbols or a visually equivalent rounded line set.

Rules:

- Stroke should feel 1.8-2.2pt.
- Icons inherit semantic color.
- Use icon wells for timeline cards: 40-44pt pale circle or squircle.
- Avoid emoji as production icons.
- Avoid mixing filled mascot-like illustrations into operational rows.
- Filled icons are allowed for active bottom navigation and success states only.

Suggested mapping:

| Concept | Symbol direction |
|---|---|
| All | 2x2 rounded grid |
| Meetings | Calendar outline |
| Tasks | Checkbox square |
| Habits | Sparkles or chart bars |
| Personal | Person outline |
| Filter | Horizontal sliders |
| Wake | Sun outline |
| Wind down | Moon with star |
| Lunch | Fork and knife |
| Workout | Running figure, shoe, or dumbbell |
| Read | Open book |
| Focus | Sparkles or target |
| Water | Droplet |
| Journal | Notebook |
| Edit | Pencil |
| Notifications | Bell with gold dot |
| Add | White plus in violet circle |

## 9. Core app chrome

### 9.1 Scenic hero header

Purpose: set mood and orient the date.

Specs:

- Height: 250-330pt on phone.
- Full-width soft illustration or painterly scene.
- Sun/horizon should sit center-right or upper-right.
- Fade to background over final 90-130pt.
- Content must remain readable over the image.
- No high-contrast photography behind text.

Scene variants:

- Current/future workday: ocean, cloud, sun, road, or sky.
- Weekend/relaxed planning: meadow, path, flowers, soft hills.
- Past day/review: misty lake, cooler dawn, reflective sky.
- Evening: warm cream/dusk with stars only if screen context is late-day.

### 9.2 Wordmark

- Text: `LifeBoard` exactly.
- Center aligned.
- Navy.
- 46-50pt on phone.
- Do not add gradients, glow, drop shadows, or extra logo marks.

### 9.3 Greeting overline

Examples:

- `GOOD MORNING`
- `LOOKING BACK`
- `GOOD EVENING`

Specs:

- Uppercase rounded sans.
- 12-13pt, 700 weight, 2.6-3.4pt tracking.
- Small semantic icon left, tiny sparkle/dot right.
- Centered under the wordmark.

### 9.4 Header buttons

- Size: 54pt circle.
- Fill: white glass.
- Icon: 22-24pt navy.
- Shadow: floating control.
- Pressed: scale 0.96, lower shadow, slight lavender tint.
- Notification badge: 10-12pt gold dot with 2pt white rim.

### 9.5 Date navigator

Composition:

- Left circular chevron.
- Center date pill with calendar icon, date text, down chevron.
- Right circular chevron.

Specs:

- Pill height: 54pt.
- Pill radius: full.
- Date text: 20-21pt, rounded, medium/semibold.
- Chevrons: 54pt circle.
- Tapping center opens native date picker in a LifeBoard sheet.
- Horizontal day swipe should match chevron direction.

### 9.6 Relative-day chip

Examples:

- `Ahead`
- `Upcoming`
- `Coming up`
- `Tomorrow`
- `Yesterday`
- `2 days ago`

Specs:

- Height: 24-30pt.
- Background: violet soft.
- Text/icon: violet deep.
- Icon: sparkle for future/current planning, clock/rewind for past.
- Keep copy short.

## 10. Filter and segment controls

Primary filter labels:

- All
- Meetings
- Tasks
- Habits
- Personal
- Settings/filter icon

Rules:

- Active chip uses violet gradient and white text.
- Inactive chip uses white glass and navy text.
- Only one chip gets filled violet.
- The settings/filter icon can show a tiny violet dot when non-default filters are active.
- Keep chip height 50-54pt with 44pt minimum hit area.
- Use a horizontal scroll view if the row does not fit.
- Advanced filters belong in a sheet, not in the top row.

## 11. Timeline system

The timeline is LifeBoard’s core product surface. It is a readable day story, not a precise overlapping calendar grid.

### 11.1 Timeline spine

- Left time labels every visible hour.
- Rail line: 1pt soft gray-blue.
- Dots: 8-9pt semantic role color.
- Major anchors: 12-15pt gold dot with white halo.
- Sparse curved connectors for meaningful busy windows only.
- Avoid drawing a heavy current-time rule through cards.

### 11.2 Card anatomy

Every timeline card has:

1. Leading icon well.
2. Time or time range in semantic color.
3. Title in navy.
4. Optional subtitle in secondary text.
5. Optional trailing tag, attendee count, or action.

Common specs:

- Radius: 18-20pt.
- Minimum height: 66pt.
- Padding: 14pt vertical, 16pt horizontal.
- Border: 1pt semantic border at 55-70% opacity.
- Background: semantic soft gradient.
- Pressed: scale 0.985 and reduce shadow.

### 11.3 Routine cards

Wake and wind-down cards are warm anchors.

Wake card:

- Gold sun icon.
- Sunrise gradient.
- Optional subtle hills/birds on right.
- Title: `Wake Up`.
- Copy: `Start your day with intention`.

Wind-down card:

- Moon/star icon in gold.
- Cream/gold gradient with tiny stars.
- Title: `Wind Down`.
- Copy: `Reflect, relax, and prepare for tomorrow`.

### 11.4 Task cards

- Green role.
- Checkbox icon.
- Time range in green.
- Trailing `Task` pill if helpful.
- Completion checkbox can be primary one-tap action.
- Completed tasks become subdued but still chronologically visible if useful.

### 11.5 Meeting cards

- Violet role.
- Calendar icon.
- Title + team/source context.
- Attendee count at trailing edge.
- Tap opens detail/read-only schedule context.
- No edit affordance for external calendar events.

### 11.6 Meeting flocks

Use when items overlap or form a tight busy block.

- Outer card: lavender-tinted group container.
- Header row: combined time, group title, source/context, attendee count.
- Nested rows: white/lavender glass mini-cards, 58-66pt high.
- Show maximum 3 nested rows on phone, then `+n more commitments`.
- Do not render horizontal overlap lanes on iPhone.

### 11.7 Focus cards

- Blue role.
- Sparkle or target icon.
- Title: `Deep Work Block`.
- Copy: `Focus time, no distractions`.
- Treat as protected, not pressured.

### 11.8 Personal and meal cards

Personal:

- Peach/orange role.
- Movement/person/book icon depending content.
- Trailing `Personal` pill.

Meal/break:

- Fork/knife icon.
- Warm peach card.
- Copy: `Recharge and reset`.

### 11.9 Empty gaps

Whitespace can be meaningful.

- Do not fill every free gap with advice.
- Optional assistant prompt can say `This gap is open` with actions like `Protect it`, `Add focus`, `Leave open`.
- Open time should feel restful, not unfinished.

## 12. Habit system visuals

Habits are recurring behaviors with honest, non-punitive streak visibility. The board should be beautiful at a glance and precise when inspected.

### 12.1 Habit board principles

- Progress is visual, not moral.
- Today is a column, not a trial.
- No activity is quiet, not shameful.
- Colors deepen as consistency strengthens.
- Future cells are low contrast.
- Missed states are visible but not red failure blocks.

### 12.2 Full habit board

Structure:

1. Header: `Habits`, subtitle `Small actions, big impact.`, `Edit Habits` pill.
2. Date header row with month, day number, weekday.
3. Left habit label rail with icon + two-line label.
4. Continuous heatmap matrix.
5. Selected/today column with lavender fill, violet border, and soft glow.
6. Legend card.
7. Summary stats card.

Specs:

- Label rail: 160-180pt.
- Row height: 76-84pt.
- Cell gap: 1pt white divider.
- Internal cell radius: 0-2pt.
- Selected column radius: 18pt.
- Selected border: 2pt violet.

### 12.3 Habit progress card

Use for Home or overview.

- White glass card, 24-30pt radius.
- Header: `Habit Progress`, subtitle, range dropdown.
- 7-day matrix.
- Optional right-side metrics on wide screens.
- Today column highlighted.
- Legend at bottom.
- Keep analytics glanceable; do not overload Home.

### 12.4 Home habit preview

- Title: `Habits`.
- Compact 7-day heatmap.
- 6-8 habit rows maximum.
- Today column highlighted.
- Footer: `Small steps, big changes.` and `View All Habits` link.
- No failure-heavy metrics.

### 12.5 Habit states

| State | Visual treatment |
|---|---|
| Completed early streak | Light family tint |
| Completed strong streak | Deep family color |
| New streak | Pale but visible family tint |
| Today pending | Soft outline or pale fill |
| Future | Low opacity, quiet cell |
| Skipped/not scheduled | Neutral or bridge pattern, not counted as success |
| Missed/lapsed | Calm neutral gap, not red |
| No activity | Near-white cell with subtle border |

### 12.6 Habit families

| Habit family | Color | Examples |
|---|---|---|
| Green | health basics | fruit, journal, reading |
| Orange | movement | workout, run, walk |
| Blue | hydration/focus | drink water, protected focus |
| Purple | reflection/learning | read, meditate, reflect |
| Yellow | morning/evening calm | meditation, ritual |
| Teal | creativity/practice | guitar, daily focus |
| Pink | wellness choices | nutrition, gentle boundaries |
| Indigo | sleep rhythm | sleep by 11pm |

## 13. Bottom navigation

The bottom dock is a familiar iOS tab bar translated into Sunrise Glass.

Items:

- Home
- Calendar
- Add
- Insights
- Profile

Specs:

- Height: 92pt plus safe area.
- Background: white glass.
- Top/floating radius: 30pt.
- Active icon/text: violet.
- Inactive icon/text: tertiary blue-gray.
- Center add button: 64pt violet gradient circle, white plus, white rim, violet glow.
- Add button sits above dock center by 8-14pt.
- Respect 44pt minimum target for every item.

Rules:

- Use the platform tab mental model.
- Do not hide primary app sections behind a hamburger.
- Do not put more than five top-level destinations in the dock.
- Secondary creation choices open from the add button in a sheet.

## 14. Sheets, forms, and creation

Creation surfaces should be calm and progressively disclosed.

### 14.1 Sheet anatomy

- Large top radius: 28-32pt.
- Header with title, close/done, optional subtitle.
- Primary action pinned near bottom when form is long.
- Use native date/time pickers with LifeBoard-styled wrappers.
- Use segmented chips for type/category selection.
- Use 56pt input height.
- Focused input: violet border + faint glow.

### 14.2 Add item flow

Default creation choices:

- Task
- Habit
- Focus block
- Personal routine
- Reflection note

Do not ask for every field upfront. Start with title and one optional timing cue. Reveal project, tags, recurrence, duration, and notes only when useful.

### 14.3 Error handling in forms

- Inline message next to the field when possible.
- Use warm amber for recoverable issues.
- Use red only for destructive or irreversible failures.
- Preserve user input on failure.

## 15. Assistant and guidance surfaces

The assistant is a calm planning partner, not an autonomous scheduler.

Visual rules:

- Use small violet sparkle accents.
- Use white/lavender glass cards.
- Place suggestions near the relevant schedule constraint or open gap.
- Keep prompts sparse.
- Avoid mascot dominance on primary planning screens.

Behavior rules:

- Suggestions are reviewable.
- Meaningful changes require explicit confirmation.
- Show undo where supported.
- Disclose incomplete calendar/task context.
- Do not auto-log habits.
- Do not imply external calendar edits.

Prompt pattern:

- Title: `This window looks tight.`
- Body: `Want help protecting focus or moving a flexible task?`
- Actions: `Ask Assistant`, `Move a task`, `Leave as is`.

## 16. Screen recipes

### 16.1 Daily Timeline

Structure:

1. Scenic hero header.
2. Date navigator and relative-day chip.
3. Filter row.
4. Timeline spine.
5. Semantic event cards.
6. Optional habit preview.
7. Bottom dock.

Success criteria:

- The next meaningful item is obvious.
- Meetings feel fixed.
- Tasks feel actionable.
- Routines create emotional rhythm.
- Gaps feel intentional.

### 16.2 Looking Back

Use for past dates.

- Cooler/misty header.
- Greeting: `LOOKING BACK`.
- Relative chip: `Yesterday`, `2 days ago`, etc.
- Completed content is visible but subdued.
- Add reflection/review affordance near evening.

### 16.3 Ahead / Future planning

Use for tomorrow and future dates.

- Warm optimistic header.
- Relative chip: `Ahead`, `Upcoming`, or `Tomorrow`.
- Gaps can offer planning prompts.
- Do not imply fixed events are editable.

### 16.4 Habit Progress

Structure:

1. Header shell.
2. `Habit Progress` glass card.
3. 7-day heatmap.
4. Streak/completed metrics.
5. Legend.
6. Today’s Plan card.
7. Bottom dock.

Success criteria:

- Today’s column stands out.
- The heatmap is readable without instruction.
- Metrics support recovery, not shame.

### 16.5 Dedicated Habits tab

Structure:

1. Header shell.
2. Filter row with Habits selected.
3. Title + subtitle + edit button.
4. Full heatmap board.
5. Streak strength legend.
6. Summary stats card.

Success criteria:

- Row labels stay understandable.
- Date columns scan quickly.
- Edit action is visible but secondary.

### 16.6 Calendar view

LifeBoard calendar surfaces provide orientation, not full external-calendar management.

- Use LifeBoard event colors and fixed/flexible distinction.
- Show day/week/month load with calm density indicators.
- External event detail is read-only.
- Add LifeBoard-owned tasks/focus blocks through LifeBoard sheets.

### 16.7 Insights

Insights should be reflective and actionable.

- Use navy editorial headings and pastel glass cards.
- Prioritize consistency, recovery, focus protection, and planning quality.
- Avoid making points, levels, or raw productivity totals the hero.
- Every insight should answer: `What can I do next?`

### 16.8 Profile and Settings

- More solid surfaces, less scenic art.
- Use grouped iOS settings patterns.
- Keep account, privacy, notifications, calendar, appearance, and assistant settings separated.
- Use destructive actions at the bottom with clear confirmation.

## 17. Empty, loading, and degraded states

### 17.1 Empty day

Copy: `A quiet day. Want to shape it?`

Actions:

- `Add task`
- `Plan focus`
- `Leave open`

### 17.2 Empty habits

Copy: `Start with one small rhythm.`

Actions:

- `Create habit`
- `Browse ideas`

### 17.3 Loading

- Use skeleton cards that preserve layout.
- Use low-contrast shimmer.
- Avoid full-screen spinners on Home.

### 17.4 Errors

- Use calm amber/coral panels.
- Explain what remains usable.
- Give a retry or repair action.

Example:

`Schedule context could not refresh. Showing your last saved view.`

### 17.5 Missing permissions

Calendar permission copy:

`Connect calendars to see fixed commitments in your day.`

Explain read-only behavior. Offer `Connect Calendar` and `Not Now`.

## 18. Motion and haptics

Motion should feel like gentle daylight, not arcade reward loops.

Rules:

- Date navigation: horizontal slide/fade, 240-320ms.
- Filter selection: low-bounce spring, 180-220ms.
- Timeline cards: fade + 8pt rise, 180-260ms, small stagger.
- Habit cell completion: color deepens + slight scale, 160-220ms.
- Add button: 0.96 press scale + haptic.
- Rare milestone celebration only; no frequent confetti.
- Reduce Motion: replace movement with opacity fades under 140ms.

## 19. Accessibility

Accessibility is part of the design system.

### 19.1 Contrast

- Primary text on light surfaces must meet WCAG AA.
- Time text must remain readable on pastel fills.
- Selected chips use white text on violet.
- Do not rely on transparency for legibility.

### 19.2 Touch targets

- Minimum: 44 x 44pt.
- Preferred header/filter controls: 50-56pt.
- Habit cells can be visually smaller only if grouped hit areas are larger.

### 19.3 VoiceOver

Timeline card label pattern:

`Task, 7:15 AM to 7:45 AM, Morning Movement, Energize your body and mind, double tap to mark done.`

Meeting label pattern:

`Meeting, 8:30 AM to 10:30 AM, Project Planning, 3 attendees, double tap for details.`

Habit cell pattern:

`Habit, Drink water, Tuesday May 13, completed, current streak 6 days.`

### 19.4 Reduce Transparency

- Use solid white surfaces.
- Increase borders.
- Remove busy background bleed.
- Preserve visual hierarchy without glass.

### 19.5 Differentiate Without Color

- Add labels, icons, patterns, or shape changes for habit states.
- Missed/skipped/bridge states need non-color cues.
- Selected chip must have filled shape and accessibility selected trait.

## 20. Implementation guidance

### 20.1 New token namespace

Create a new LifeBoard semantic layer. New UI code should not consume legacy color names directly.

Suggested Swift names:

```swift
enum LifeBoardRole {
    case routine
    case task
    case meeting
    case personal
    case focus
    case meal
    case assistant
    case neutral
}

struct LifeBoardRoleStyle {
    let base: Color
    let deep: Color
    let softSurface: Color
    let border: Color
    let gradient: LinearGradient
    let symbolName: String
}
```

Suggested token groups:

- `LifeBoardColor`
- `LifeBoardTypography`
- `LifeBoardSpacing`
- `LifeBoardRadius`
- `LifeBoardShadow`
- `LifeBoardMaterial`
- `LifeBoardGradient`
- `LifeBoardHabitPalette`
- `LifeBoardSemanticRole`

### 20.2 Component abstractions

Build these as reusable components:

- `LifeBoardHeroHeader`
- `LifeBoardDateNavigator`
- `LifeBoardRelativeDayChip`
- `LifeBoardFilterPill`
- `LifeBoardTimelineSpine`
- `LifeBoardTimelineCard`
- `LifeBoardMeetingFlockCard`
- `LifeBoardRoutineCard`
- `LifeBoardHabitMatrix`
- `LifeBoardHabitCell`
- `LifeBoardHabitProgressCard`
- `LifeBoardBottomDock`
- `LifeBoardFloatingAddButton`
- `LifeBoardAssistantPromptCard`
- `LifeBoardCreationSheet`

### 20.3 Migration order

1. Add token layer without changing screens.
2. Build Sunrise Glass component previews.
3. Replace Home header and date/filter controls.
4. Replace timeline card rendering.
5. Replace habit matrix and progress cards.
6. Replace bottom dock.
7. Replace creation/editing sheets.
8. Refresh widgets.
9. Refresh marketing site.
10. Delete or quarantine legacy visual tokens after parity.

### 20.4 Snapshot and lint checks

Add checks that fail when:

- Visible copy uses a previous product name.
- Clinical or diagnostic terms appear in user-facing design copy.
- New UI hardcodes colors outside LifeBoard tokens.
- Touch targets fall below 44pt.
- Timeline cards lack accessibility labels.
- Habit cells lack state labels.
- External calendar detail surfaces show edit/delete/RSVP affordances.

## 21. Copy voice

LifeBoard copy is calm, concise, and nonjudgmental.

Preferred phrases:

- `Start your day with intention`
- `Recharge and reset`
- `Focus time, no distractions`
- `Unwind and learn`
- `Reflect, relax, and prepare for tomorrow`
- `Small steps, big changes.`
- `Plan the week, set priorities`
- `Move your body`
- `Leave this gap open`
- `Try one small step`

Avoid:

- `You failed`
- `No excuses`
- `Crush your day`
- `Streak lost`
- `Fix your productivity`
- `You are behind`
- `Weak performance`

## 22. Marketing direction

Marketing should now match the app, not the previous dark cinematic style.

Use:

- Light dawn backgrounds.
- Navy serif LifeBoard wordmark.
- Violet primary CTAs.
- Real app screens in glass device frames.
- Calm claims around clarity, privacy, recovery, and planning.
- Soft timeline and habit-board product visuals.

Avoid:

- Dark hero video as the primary first impression.
- Heavy points/levels language.
- Aggressive productivity claims.
- Generic SaaS sections with dark cards and neon hover effects.

## 23. Do and Don't

### Do

- Make LifeBoard feel peaceful and capable.
- Keep the next action clear.
- Use sunrise scenery as atmosphere, not content.
- Use native iOS patterns first.
- Use semantic colors consistently.
- Distinguish fixed meetings from flexible tasks.
- Make habits colorful and forgiving.
- Show empty, loading, error, and degraded states honestly.
- Use explicit confirmation for meaningful assistant changes.
- Keep external calendar context read-only.

### Don't

- Do not preserve the current visual palette or achievement-heavy home hierarchy.
- Do not build a dense calendar grid on iPhone.
- Do not punish missed habits with red blocks.
- Do not overuse violet.
- Do not place small text directly over scenic art.
- Do not hide primary creation behind a menu.
- Do not make glass reduce readability.
- Do not rely on color alone.
- Do not let assistant prompts crowd the day.
- Do not imply LifeBoard silently changed anything.

## 24. Acceptance checklist

A new LifeBoard screen is acceptable only when:

- It uses the LifeBoard name in visible copy.
- It follows Sunrise Glass tokens.
- It feels like the provided screenshots.
- It uses native iOS interaction patterns where possible.
- It preserves 44pt minimum touch targets.
- It supports Dynamic Type, VoiceOver, Reduce Motion, and Reduce Transparency.
- It distinguishes tasks, meetings, habits, routines, focus, personal, and meals.
- It provides loading, empty, error, and degraded states.
- It keeps next action and date context obvious.
- It avoids shame-based or clinical framing.
- It keeps calendar trust boundaries clear.
- It does not hardcode legacy visual colors.

## 25. Quick reference

Primary palette:

- Navy: `#071B52`
- Violet: `#6842FF`
- Gold: `#FFB300`
- Green: `#28B53F`
- Sky: `#2F8CFF`
- Peach: `#FF7A3D`
- Glass: `#FFFFFFE8`

Core components:

- Scenic hero header
- LifeBoard wordmark
- Date navigator
- Relative-day chip
- Filter pills
- Timeline spine
- Semantic timeline cards
- Meeting flock
- Habit matrix
- Habit progress card
- Today’s Plan card
- Bottom dock
- Floating add button
- Assistant prompt card
- Creation sheet

Core promise:

LifeBoard makes the day understandable at a glance, helps the user act on the next small step, and makes recovery feel normal.

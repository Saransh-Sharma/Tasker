# LifeBoard Marketing Site Guide

> Classification: Canonical public design and content authority
> Audience: Marketing, product, design, engineering, accessibility, QA, support, and release teams
> Capability status: Current website contract
> Source authority: [Public Capability Matrix](../product/PUBLIC_CAPABILITY_MATRIX.md), [product design contract](../../DESIGN.md), and current marketing-site implementation
> Last verified: 2026-08-13

## Position and audience

LifeBoard is **a private, recovery-aware Life OS**. It is for people whose days
cross work, home, health, relationships, learning, creativity, and personal
administration—and who need continuity more than another isolated tracker.

The public promise is: **One place to run the life you actually have.**

The site should help a visitor recognize three things quickly:

1. LifeBoard connects the parts of life that are currently fragmented.
2. It helps the user act, recover, and adapt rather than chase a perfect score.
3. Personal context and consequential changes remain under the user’s control.

Primary jobs include orienting a high-context day, capturing input before it is
lost, planning around fixed commitments and capacity, sustaining care systems,
recovering after disruption, and learning from evidence without judgment.

## Message hierarchy

The homepage opens with:

- Eyebrow: “YOUR PRIVATE LIFE OS”
- Headline: “One place to run the life you actually have.”
- Support: “Bring your work, home, health, routines, plans, and reflections into one calm system that helps you decide, act, recover, and adapt.”
- Primary action: “Download LifeBoard”
- Secondary action: “Explore the Life OS”

The story then moves through fragmentation, the canonical eight-stage loop,
the five roots, a realistic day, seven life domains, feature proof, trust,
Apple ecosystem continuity, and a final download invitation. EVA and XP support
the story; neither replaces the broader Life OS position.

## Voice and terminology

Write with warm intelligence: clear, calm, specific, and quietly optimistic.
Lead with relief, agency, continuity, and believable outcomes. Prefer “recover
when the day changes” over “never fall behind,” and “evidence supports” over
“AI knows.” Make limitations legible without turning every sentence into a
disclaimer.

Use these names consistently:

- **LifeBoard** for the product;
- **Life OS** for the category in public prose;
- **EVA** for the assistant;
- `orient → capture → organize → plan → focus or track → recover → reflect → adapt` for the operating loop.

Do not use perfection pressure, fear, inflated urgency, fabricated social proof,
customer counts, ratings, productivity percentages, or unsupported comparisons.

## Visual direction

The site is warm celestial-editorial: cream and clay canvases, sunlit gold,
restrained life-domain colors, and dark earthy type. Instrument Serif carries
expressive display language; Geist carries body and interface copy. Composition
should feel authored through asymmetric product arrangements, generous space,
quiet rules, editorial numbering, and varied rhythm.

Real product UI is the primary proof. Celestial forms and EVA artwork may
reinforce orientation or assistance, but must never obscure the interface.
Avoid generic dark-indigo AI styling, excessive glass, repetitive equal-card
grids, decorative autoplay media, and ornamental hover movement.

## Route and chapter contract

The static site exposes `/LifeBoard/`, `/LifeBoard/features/`, seven feature
chapters under `/LifeBoard/features/`, plus privacy, terms, and support. Each
route gets a generated HTML entry with a unique title, description, canonical
URL, and share metadata so direct visits and refreshes remain meaningful.

Feature chapters lead with the outcome, then explain a realistic scenario,
capabilities, availability, degraded states, privacy boundaries, connected
areas, and a final App Store action. The feature hub behaves like an editorial
index with chapter navigation, not a uniform card catalogue.

## Calls to action

All download actions use the shared App Store constant and the label “Download
LifeBoard” or the compact “Download.” A nearby secondary action may open the
feature hub or a connected chapter. Do not introduce competing signup, account,
waitlist, or newsletter actions.

The canonical destination is:
`https://apps.apple.com/app/id1574046107`.

Support links use `support@lifeboard.app`. Public pages must not contain a
personal phone number, postal address, personal inbox, or conflicting account
deletion instructions.

## Screenshot policy

Screenshots are evidence, not decoration. Every published capture must:

- originate from a test-only deterministic scenario with a fixed clock, locale,
  timezone, appearance, text size, device, and stable identifiers;
- contain coherent synthetic records across a believable 28-day life history;
- use independent reset and seed stages and condition-based navigation;
- show enough data to explain the page’s claim while remaining legible at its
  rendered size;
- contain no real contacts, sensitive identifiers, clinical conclusions,
  placeholders, fixture terms, keyboard, permission alert, loader, debug probe,
  or error overlay;
- pass the screenshot manifest, checksum, dimension, and file-budget checks;
- preserve the last approved asset if the replacement capture fails.

The required scene list and its public use are governed by the [Public
Capability Matrix](../product/PUBLIC_CAPABILITY_MATRIX.md). Repository README
material uses a curated six-image subset. Watch, widget, and Mac visuals require
genuine populated capture environments; use accurate prose or restrained
diagrams until those exist.

## Accessibility and interaction

- Provide a skip link, semantic landmarks, one clear page heading, and logical heading order.
- Desktop navigation exposes the product, features, privacy, and download action; mobile navigation is operable by keyboard and assistive technology.
- Show the current page with more than color alone and restore scroll and focus after route navigation.
- Maintain at least 44×44 CSS-pixel touch targets, visible focus indicators, and WCAG 2.2 AA contrast.
- Screenshots need informative alternative text; decorative artwork uses empty alternative text or is hidden from the accessibility tree.
- Core content must remain present without reveal scripts. Motion must have a reduced-motion alternative and must not be necessary to understand or operate the page.
- Validate 320, 390, 768, 1024, and 1440 CSS pixels plus 200% browser zoom without clipping or horizontal overflow.

## Performance budgets

| Asset or experience | Budget |
|---|---:|
| 480-pixel screenshot variant | 100 KB maximum |
| 760-pixel screenshot variant | 200 KB maximum |
| Full-resolution screenshot variant | 400 KB maximum |
| Initial homepage image transfer | 1.2 MB maximum |
| Mobile Lighthouse Performance | 90 or higher |
| Accessibility, Best Practices, SEO | 95 or higher |

No autoplay network video is allowed. Lazy-load non-hero captures, prioritize
only the first meaningful product image, avoid duplicate initial screenshot
transfers, and keep route metadata available in static HTML.

## Publishing checklist

- [ ] The [Public Capability Matrix](../product/PUBLIC_CAPABILITY_MATRIX.md) supports every claim.
- [ ] Every route works by direct URL and refresh under the `/LifeBoard/` base.
- [ ] Current-page, keyboard, reduced-motion, responsive, and zoom behavior pass.
- [ ] Screenshot manifest and image budgets pass; every image shows realistic synthetic data.
- [ ] Privacy, terms, support, App Store URL, and contact details are consistent.
- [ ] No version number or pre-release language appears in public content.
- [ ] No future capability is framed as available.

# Home Timeline Curved Spine TODO

- [x] Scope the change to the timeline spine, current-time marker, gap CTA visibility, and stream accents only.
- [x] Replace the expanded Home timeline straight spine with a curved semantic day stream.
- [x] Replace the current-time rule with a reduced-motion-aware Now bead.
- [x] Preserve existing task, meeting, flock, wake, and wind-down visual components.
- [x] Add pure geometry coverage for stream pull, gap breathing, flock thickness, and Now bead clamping.
- [x] Run targeted Home timeline tests.

## Curving Day Stream Correction

- [x] Add a Curve Director pass so semantic anchors produce large alternating S-curves instead of local wiggles.
- [x] Use center-y semantic anchors for routine icons, cards, flocks, and open gaps.
- [x] Merge close semantic anchors into weighted composite cluster anchors with dominant-type priority.
- [x] Increase meeting, flock, task, routine, and gap curvature amplitudes within the responsive stream lane.
- [x] Generate cubic Bezier stream segments with horizontal control guidance and major-anchor overshoot.
- [x] Render glow, body, and inner-core stream layers with rounded caps and joins.
- [x] Compute the Now bead x-position from the final composed curve instead of treating Now as a curve anchor.
- [x] Keep Rise and Shine / Wind Down routine icons above the stream while leaving their content unchanged.
- [x] Add geometry coverage for lane sizing, clustering, direction assignment, visible sweep travel, Now lookup, and render layer specs.
- [x] Run correction-focused Home timeline regression tests.

## Density Mass-Field Algorithm

- [x] Replace directed decorative S-curves with sampled Gaussian mass-field curvature.
- [x] Treat wake/wind-down anchors as gentle mass and empty gaps as no-pull recovery space.
- [x] Collapse dense nearby task/meeting groups into cluster mass bodies for curvature.
- [x] Bend the spine toward right-side cards with smoothing, slope limiting, and lane-safe max offsets.
- [x] Update focused geometry tests for sparse, isolated, and clustered day behavior.
- [x] Run focused Home timeline layout regression tests.

# Ambient artwork direction

User feedback on 15 September supersedes the separate illustration-region design: artwork should inhabit the surface background, never append a footer or take a reading column. Normal-size visual quality, reuse across the app, and scrolling performance take priority over exhaustive accessibility/preset verification in this pass.

## Implementation

- `HomeCardIllustratedSurface` lays out native content at the complete available width. Existing minimum heights remain floors. The background cannot increase height.
- `HomeCardScene` fills the existing surface proportionally and clips decorative paint at its boundary. A directional gradient protects the reading field. Glance uses 18% opacity; other surfaces use 24% in light appearance and 28% in dark appearance before the reading mask.
- No animated blur, parallax, additional artwork row, or runtime original-source loading.
- `HomeSceneImageCache` coalesces preparation requests and uses a 32 MiB / 48-image NSCache budget for prepared pixels (an eviction policy, not a hard total-memory limit). UIKit prepares pixels asynchronously. Appearance is part of the cache identity.
- Protected/unavailable Home content and user media keep precedence. Metric feature heroes suppress artwork for stale, denied, or unavailable readings. Journal decorations require unlocked privacy state.

## Reuse outside pinnable Home cards

| Scene | Owning surface |
|---|---|
| Setup | Life Map product-preview header |
| Focus Now | Plan active-focus card |
| Life Snapshot | Track header and tracker overview |
| Care | Care area header |
| Tasks | Plan root header |
| Routines | Routines collection header |
| Schedule & Capacity | Plan capacity card |
| Quick Capture | Root capture palette |
| Day Shape | Plan date/lens orientation bar |
| Journal | Unlocked Journal section selector |
| Progress & Reflection | Insights root header |
| Active Fast | Track fasting section and fasting destination |
| Goals | Goals collection header |
| Saved Eva Insight | Eva root header |
| Body Metric | Wellness body-metric hero |
| Recent Workout | Wellness workout hero |
| Sleep Note | Wellness sleep hero |
| Movement | Wellness movement hero |
| Life Moment | Focused Life Moment detail |
| Nutrition Summary | Nutrition daily hero |
| Recent Meal | Nutrition meal section |
| Log Meal | Meal composer Food section |

Both appearances reuse the packaged asset catalog variants. Runtime exports remain separate from canonical transparent originals.

## Evidence status

Current card-local sample measurements and captures now use the ambient layout. Earlier generation attempts remain historical evidence. Twelve normal-size native exemplars, the passing targeted tests, simulator build, and three-cycle scrolling measurement are recorded in VALIDATION.md. Two regenerated ambient references were inspected and rejected for excessive artwork strength; Body Metric also adds an unwanted outer margin. The 184-reference and 92-combination release gates remain open.

## Dedicated feature headers

The user subsequently requested a distinct identity for each key feature. Seventeen header families now use 34 new panoramic appearance variants, separate from the original Home scenes. See [feature identities and validation](../ambient-surfaces/VALIDATION.md) and [the visual gallery](../ambient-surfaces/index.html). The surface map above describes the initial reuse pass; matching main feature headers now prefer their dedicated panorama. Existing Home card artwork is preserved.

# LifeBoard appearance and comfort evidence

Generated on 2026-07-22 from the same seeded iPhone 17 Pro Simulator build. These PNGs are non-shipping QA evidence.

The `LifeBoardVisualAppearanceFixture` launch contract covers:

- Light and Dark system appearance
- Increased Contrast in Light and Dark
- Reduce Transparency
- Reduce Motion
- Grayscale

Launch with `-LIFEBOARD_VISUAL_APPEARANCE=<appearance>`. Light/Dark and Increased Contrast captures also use the matching Simulator system setting so UIKit and SwiftUI dynamic tokens resolve through the same real trait collection. Reduce Transparency is routed through the shared glass/scenic policy, while grayscale is applied to the complete root composition.

All captures use a reset, seeded established workspace and `home:populated`; no personal content is present.

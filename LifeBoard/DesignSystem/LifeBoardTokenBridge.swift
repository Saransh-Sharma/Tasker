import UIKit

/// Maps every legacy colour accessor to its canonical `LifeBoardColorRole`.
///
/// The app grew **four** ways to name the same colour: `Color.lifeboard(_:)`
/// (semantic roles, ~818 refs), the `LifeBoardColorTokens` foundation statics
/// (~560), the legacy `LBColorTokens` (~621 across 81 files), and
/// `palette.color(for:)`. Four vocabularies for one palette means a change to
/// "the canvas colour" has to be made in four places, and a drift between any
/// two of them is invisible until someone screenshots the app.
///
/// **Canonical is `LifeBoardColorRole`.** It is the most-used path, the only one
/// resolved through `LifeBoardThreadSafeTokenResolver` (so the only one that is
/// both trait- and theme-aware), the only one already under contrast test, and
/// the one `DESIGN.md:263` already names as the implementation source of truth.
///
/// This is a **mapping, not a rename.** Several foundation statics have no role
/// equivalent at all — the settings-hero gradient stops, `foundationOnCelestialAccent`,
/// the metric-ring pair — and inventing roles for them would be worse than
/// recording honestly that they are unmapped. Those are `nil`, and `nil` means
/// "no equivalent yet", never "same as default".
///
/// **Measured 2026-08-01, and the result is the headline: of 13 statics with a
/// plausible role, only 2 actually resolve to the same colour.** These are not
/// two names for one palette — they are two palettes that drifted apart, mostly
/// in dark mode and under Increased Contrast, where nobody was looking.
///
/// So `role` here means *migration target*, *not* "same colour". Anything in
/// `divergentNames` changes pixels when migrated and needs a design decision
/// first. `TokenBridgeEquivalenceTests` pins both sets, so the day one of them
/// converges — or a new one drifts — the suite says so instead of letting a
/// "pure refactor" quietly restyle the app.
///
/// Two divergences are worth singling out:
/// - `foundationHairline` strengthens to `#A89572` under Increased Contrast
///   while `.strokeHairline` stays `#E9DFC6`. Only one vocabulary honours the
///   setting, so surfaces on the role are **not** currently respecting it.
/// - `foundationFocusRing` is opaque; `.actionFocus` is 42% alpha. A focus ring
///   is an accessibility affordance, and those are materially different rings.
enum LifeBoardTokenBridge {

    /// A legacy accessor, the role it should become, and how to resolve it today.
    struct Entry {
        let legacyName: String
        let role: LifeBoardColorRole?
        /// Non-`nil` when the two are *supposed* to be the same colour but
        /// measurably are not. Recorded rather than mapped away: a migration
        /// that silently changed these would be a visual change wearing a
        /// refactor's clothes.
        let divergence: String?
        let resolve: () -> UIColor

        init(
            legacyName: String,
            role: LifeBoardColorRole?,
            divergence: String? = nil,
            resolve: @escaping () -> UIColor
        ) {
            self.legacyName = legacyName
            self.role = role
            self.divergence = divergence
            self.resolve = resolve
        }

        /// Whether the two sides are measured to render identically.
        var isAssertable: Bool { LifeBoardTokenBridge.equivalentNames.contains(legacyName) }
    }

    /// The foundation statics on `LifeBoardColorTokens`.
    ///
    /// Note the two deliberate divergences, which are **not** bugs to "fix":
    /// `inkSecondary` and `inkTertiary` were darkened from the values the
    /// redesign brief specifies (`#746757` / `#9B8F7E`) because those measured
    /// 4.446:1 and ~2.95:1 — below the 4.5:1 body floor and the 3:1 non-text
    /// floor respectively. Adopting the brief verbatim would reintroduce a
    /// documented accessibility regression.
    static var foundationEntries: [Entry] {
        [
            Entry(legacyName: "foundationCanvas", role: .bgCanvas) { LifeBoardColorTokens.foundationCanvas },
            Entry(legacyName: "foundationCanvasSoft", role: .bgCanvasSecondary) { LifeBoardColorTokens.foundationCanvasSoft },
            Entry(legacyName: "foundationSurfaceRecessed", role: .surfaceSecondary) { LifeBoardColorTokens.foundationSurfaceRecessed },
            Entry(legacyName: "foundationSurfaceSelected", role: .surfaceTertiary) { LifeBoardColorTokens.foundationSurfaceSelected },
            Entry(legacyName: "foundationSurfaceSolid", role: .surfacePrimary) { LifeBoardColorTokens.foundationSurfaceSolid },
            Entry(legacyName: "foundationSunAccent", role: .accentSecondary) { LifeBoardColorTokens.foundationSunAccent },
            Entry(legacyName: "foundationApricotAccent", role: .accentSecondaryPressed) { LifeBoardColorTokens.foundationApricotAccent },
            Entry(legacyName: "foundationDanger", role: .statusDanger) { LifeBoardColorTokens.foundationDanger },
            Entry(legacyName: "foundationHairline", role: .strokeHairline) { LifeBoardColorTokens.foundationHairline },
            Entry(legacyName: "foundationFocusRing", role: .actionFocus) { LifeBoardColorTokens.foundationFocusRing },
            Entry(legacyName: "inkPrimary", role: .textPrimary) { LifeBoardColorTokens.inkPrimary },
            Entry(legacyName: "inkSecondary", role: .textSecondary) { LifeBoardColorTokens.inkSecondary },
            Entry(legacyName: "inkTertiary", role: .textTertiary) { LifeBoardColorTokens.inkTertiary },

            // Unmapped on purpose — no role expresses these, and inventing one
            // would be a design decision disguised as a refactor.
            Entry(legacyName: "foundationCanvasMuted", role: nil) { LifeBoardColorTokens.foundationCanvasMuted },
            Entry(legacyName: "foundationSageAccent", role: nil) { LifeBoardColorTokens.foundationSageAccent },
            Entry(legacyName: "foundationOnCelestialAccent", role: nil) { LifeBoardColorTokens.foundationOnCelestialAccent },
            Entry(legacyName: "foundationOnSettingsHero", role: nil) { LifeBoardColorTokens.foundationOnSettingsHero },
            Entry(legacyName: "foundationSettingsHeroStart", role: nil) { LifeBoardColorTokens.foundationSettingsHeroStart },
            Entry(legacyName: "foundationSettingsHeroMiddle", role: nil) { LifeBoardColorTokens.foundationSettingsHeroMiddle },
            Entry(legacyName: "foundationSettingsHeroEnd", role: nil) { LifeBoardColorTokens.foundationSettingsHeroEnd },
            Entry(legacyName: "foundationOnScenicDark", role: nil) { LifeBoardColorTokens.foundationOnScenicDark },
            Entry(legacyName: "foundationOnScenicDarkSecondary", role: nil) { LifeBoardColorTokens.foundationOnScenicDarkSecondary },
            Entry(legacyName: "foundationWarmShadow", role: nil) { LifeBoardColorTokens.foundationWarmShadow },
            Entry(legacyName: "metricRingFill", role: nil) { LifeBoardColorTokens.metricRingFill },
            Entry(legacyName: "metricRingTrack", role: nil) { LifeBoardColorTokens.metricRingTrack },
            Entry(legacyName: "metricRingTrackProminent", role: nil) { LifeBoardColorTokens.metricRingTrackProminent },
            Entry(legacyName: "warmMenuGlass", role: nil) { LifeBoardColorTokens.warmMenuGlass }
        ]
    }

    /// The only two pairs measured to resolve identically in all four
    /// appearances. Migrating these is a genuine rename.
    static let equivalentNames: Set<String> = ["foundationCanvas", "foundationDanger"]

    /// Everything else with a role: the migration target is known, but the two
    /// sides render differently today. Changing a call site moves pixels.
    static var divergentNames: Set<String> {
        Set(foundationEntries.compactMap { entry in
            guard entry.role != nil, equivalentNames.contains(entry.legacyName) == false else { return nil }
            return entry.legacyName
        })
    }

    static var assertableEntries: [Entry] {
        foundationEntries.filter { equivalentNames.contains($0.legacyName) }
    }

    static var divergentEntries: [Entry] {
        foundationEntries.filter { divergentNames.contains($0.legacyName) }
    }

    /// How far the migration has actually got, for the record rather than for a gate.
    static var mappedCount: Int { assertableEntries.count }
    static var unmappedCount: Int { foundationEntries.count - mappedCount }
}

import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// Home's presentation controls, as controls rather than menu rows.
///
/// The ⋯ menu carried Mode, Density and Atmosphere as nested `Picker`s, which
/// flattened three different kinds of choice into one grammar of lists. Mode is
/// a small set of named intents, density is a lens, and atmosphere is a
/// *sequence* — a day — that only reads as one when you can drag along it. A
/// SwiftUI `Menu` renders buttons, pickers and toggles and nothing else, so the
/// slider could not live there at all.
///
/// Bindings arrive from the shell rather than being rebuilt here: `density` is
/// backed by `@AppStorage` on the shell and both it and `mode` write inside a
/// `cardReflow` animation, which is what makes Home reflow rather than snap.
struct DisplayPanel: View {
    @Binding var density: DashboardDensity
    @Binding var daypart: DaypartSelection
    /// Passed in, never read from preferences: `resolvedDaypart(at:)` lapses
    /// expired overrides and writes to UserDefaults, so calling it from `body`
    /// would persist once per frame of a drag.
    let resolvedDaypart: ResolvedDaypart
    let activeOverride: DaypartOverride?
    let onDragStateChange: (Bool) -> Void
    let onOpenSettings: () -> Void
    let onMeasure: (CGFloat) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardMotionContext) private var motionContext

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.sectionGap) {
            Text("Display")
                .font(Typography.sectionTitle())
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))

            densitySection
            atmosphereSection

            Rectangle()
                .fill(Color(SemanticColorTokens.foundationHairline))
                .frame(height: 1)

            Button(action: onOpenSettings) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .frame(width: 24)
                    Text("Settings")
                        .font(.lifeboard(.body))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("foundation.display.settings")
        }
        .padding(SwiftUITokens.spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            // Drives the sheet's compact detent, so the panel is exactly as
            // tall as it needs to be and leaves the sky — and the celestial
            // body the slider is moving — visible above it. The margin covers
            // the drag indicator and the home indicator inset, nothing more.
            onMeasure(height + 24)
        }
        // Without `.contain` the panel's identifier stamps every child, and
        // the atmosphere slider loses `foundation.atmosphere.slider`.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.display.panel")
    }

    // Mode is not here. It rides Home's date line (`HomeModeMenu`), where the
    // day is named; a second control for the same choice in this panel meant
    // two places to look and two places to disagree.

    // MARK: Density

    private var densitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Density")
            LensPicker(
                "Density",
                selection: $density,
                values: DashboardDensity.allCases,
                identifierPrefix: "home.display.density",
                title: \.title,
                identifier: \.rawValue
            )
        }
    }

    // MARK: Atmosphere

    private var atmosphereSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Atmosphere")
            AtmosphereSlider(
                selection: $daypart,
                resolvedDaypart: resolvedDaypart,
                activeOverride: activeOverride,
                onDragStateChange: onDragStateChange
            )
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.lifeboard(.eyebrow))
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
    }

    private var motionPolicy: MotionPolicy {
        MotionPolicy.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active,
            comfortProfile: motionContext.comfortProfile
        )
    }
}

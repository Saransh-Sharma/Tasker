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
    @Binding var mode: DashboardMode
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

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.sectionGap) {
            Text("Display")
                .font(Typography.sectionTitle())
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))

            modeSection
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
        .accessibilityIdentifier("foundation.display.panel")
    }

    // MARK: Mode

    /// A grid, not a `LensPicker`: four segments in one row truncate
    /// "Low Energy" to an ellipsis, and each mode's `summary` is worth showing
    /// — these are intents, not lenses, and the names alone do not say what
    /// Smart or Low Energy will actually do to the screen.
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Mode")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DashboardMode.allCases, id: \.self) { candidate in
                    modeTile(candidate)
                }
            }
            Text(mode.summary)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    private func modeTile(_ candidate: DashboardMode) -> some View {
        let selected = candidate == mode
        return Button {
            guard selected == false else { return }
            Haptic.pick.play(policy: motionPolicy)
            mode = candidate
        } label: {
            HStack(spacing: 8) {
                Image(systemName: candidate.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(candidate.title)
                    // Weight carries selection alongside the fill, so the state
                    // survives Differentiate Without Colour.
                    .font(.lifeboard(selected ? .bodyStrong : .body))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(
                Color(selected ? SemanticColorTokens.inkPrimary : SemanticColorTokens.inkSecondary)
            )
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.compact, style: .continuous)
                    .fill(
                        Color(
                            selected
                                ? SemanticColorTokens.foundationSurfaceSelected
                                : SemanticColorTokens.foundationSurfaceRecessed
                        )
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.compact, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.display.mode.\(candidate.rawValue)")
        .accessibilityLabel(Text("\(candidate.title). \(candidate.summary)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

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
            sceneIsActive: scenePhase == .active
        )
    }
}

import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// The payoff, and the two optional extensions after it. Everything here runs
// *after* persistence has succeeded — the reveal is a report on what was
// written, never a promise about what might be.

// MARK: - Reveal

struct LifeMapRevealStep: View {
    let capture: LifeMapStagedCapture?
    let placements: [DashboardWidgetPlacementValue]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            LifeMapEyebrow("YOUR LIFE, CONNECTED")
            Text("A system shaped around\nthe life you actually have.")
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your areas, priorities, capacity, and Home are saved. Rotate the map, inspect a root, or step inside.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            if let capture, capture.isReviewed {
                Label("“\(capture.text)” is saved as a \(capture.kind.title.lowercased())", systemImage: "checkmark.seal.fill")
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .padding(Theme.Spacing.md + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lifeBoardClaySurface(.resting, cornerRadius: 18)
            }

            LifeMapHomePreview(placements: placements)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.reveal))
    }
}

/// The Home the user is about to land on, read back from the layout that was
/// actually persisted.
///
/// Deliberately derived from `placements` rather than from the module selection:
/// if `homePlacements(for:)` and the commit ever disagree, this preview shows
/// the truth and the bug becomes visible instead of cosmetic.
private struct LifeMapHomePreview: View {
    let placements: [DashboardWidgetPlacementValue]

    private var sections: [(role: HomeSectionRole, titles: [String])] {
        let registry = DefaultDashboardWidgetRegistry.shared
        let descriptors = placements
            .filter(\.isVisible)
            .sorted { $0.ordinal < $1.ordinal }
            .compactMap { registry.descriptor(for: DashboardWidgetKind(rawValue: $0.widgetKind)) }

        return HomeSectionRole.allCases.compactMap { role in
            let titles = descriptors.filter { $0.sectionRole == role }.map(\.title)
            return titles.isEmpty ? nil : (role, titles)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Your Home", systemImage: "rectangle.grid.1x2")
                .font(.lifeboard(.eyebrow))
                .foregroundStyle(Color.lifeboard(.textSecondary))

            ForEach(sections, id: \.role) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.role.title)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                    Text(onboardingNaturalLanguageList(section.titles, fallback: "nothing yet"))
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 22)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeMapAccessibilityID.homePreview)
    }
}

// MARK: - Assembly

/// The transient "Connecting your Life Map…" phase.
///
/// Floating clay, not glass: the capture review card already claimed the hero on
/// the step this covers, and `DESIGN.md` forbids stacking glass on glass. It is
/// also not a navigable page — there is no back affordance, because the commit
/// underneath it is not cancellable once started.
struct LifeMapAssemblyOverlay: View {
    var body: some View {
        ZStack {
            Color.lifeboard(.overlayScrim)
                .ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.lifeboard(.accentPrimary))
                Text("Connecting your Life Map…")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
            }
            .padding(Theme.Spacing.xxxl - 2)
            .lifeBoardClaySurface(.floating, cornerRadius: 28)
            .lifeboardLiquidGlassRefract(center: .center, radius: 0.7, strength: 0.65)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting your Life Map")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

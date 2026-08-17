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

// MARK: - Permissions power-up

struct LifeMapPermissionsStep: View {
    let permissions: [PermissionKind]
    let grantedIDs: [String]
    let inFlight: PermissionKind?
    let onRequest: (PermissionKind) -> Void
    let onDefer: (PermissionKind) -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "Power it up",
            support: "Optional. Connect only what makes your map more useful — declining never blocks LifeBoard."
        ) {
            if permissions.isEmpty {
                Text("Nothing to connect for the modules you chose. You're all set.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lifeBoardClaySurface(.resting, cornerRadius: 20)
            }
            ForEach(permissions) { kind in
                LifeMapPermissionRow(
                    kind: kind,
                    isGranted: grantedIDs.contains(kind.id),
                    isBusy: inFlight != nil,
                    onRequest: { onRequest(kind) },
                    onDefer: { onDefer(kind) }
                )
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.permissionsPowerUp))
    }
}

private struct LifeMapPermissionRow: View {
    let kind: PermissionKind
    let isGranted: Bool
    let isBusy: Bool
    let onRequest: () -> Void
    let onDefer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: kind.symbolName)
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title)
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(kind.blurb)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.lifeboard(.title3))
                        .foregroundStyle(Color.lifeboard(.statusSuccess))
                        .accessibilityLabel("Connected")
                }
            }
            if isGranted == false {
                HStack(spacing: Theme.Spacing.sm) {
                    Button(kind.allowTitle, action: onRequest)
                        .buttonStyle(LifeMapPrimaryButtonStyle())
                        .disabled(isBusy)
                        .accessibilityIdentifier(LifeMapAccessibilityID.permission(kind.id))
                    Button("Skip", action: onDefer)
                        .buttonStyle(LifeMapSecondaryButtonStyle())
                        .accessibilityIdentifier(LifeMapAccessibilityID.permissionSkip(kind.id))
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: 20)
    }
}

// MARK: - EVA power-up

struct LifeMapEvaStep: View {
    let isAuthenticated: Bool
    let isAdultEligible: Bool
    let isCloudReady: Bool
    let isWorking: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            LifeMapEyebrow("OPTIONAL · PRIVATE · RESUMABLE")
            Text(isCloudReady ? "EVA is connected." : "Enable EVA with Apple.")
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text(isCloudReady
                 ? "Your private cloud session is ready. Continue to choose how EVA should work with you and try your first useful prompt."
                 : "Sign in with Apple enables Cloud EVA without sharing your name or email. Apple confirms an 18+ age range; LifeBoard never asks for your birth date.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                LifeMapEvaRequirement(
                    symbol: "apple.logo",
                    title: "Sign in privately with Apple",
                    detail: "A nonce-bound session for this device",
                    isComplete: isAuthenticated
                )
                LifeMapEvaRequirement(
                    symbol: "checkmark.shield.fill",
                    title: "Confirm adult eligibility",
                    detail: "Apple shares only an 18+ result",
                    isComplete: isAdultEligible
                )
                LifeMapEvaRequirement(
                    symbol: "hand.raised.fill",
                    title: "Choose EVA’s boundaries",
                    detail: "You approve any sensitive context",
                    isComplete: isCloudReady
                )
            }
            .padding(Theme.Spacing.lg)
            .lifeBoardClaySurface(.resting, cornerRadius: 22)

            if isWorking {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                        .tint(Color.lifeboard(.accentPrimary))
                    Text("Securing your EVA session…")
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Prefer everything on-device? Finish later and choose Offline EVA from EVA setup. Core LifeBoard never requires an account.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.evaPowerUp))
    }
}

private struct LifeMapEvaRequirement: View {
    let symbol: String
    let title: String
    let detail: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(isComplete ? .statusSuccess : .accentPrimary))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(detail)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            Spacer(minLength: Theme.Spacing.sm)
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(Color.lifeboard(isComplete ? .statusSuccess : .textQuaternary))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isComplete ? "Complete" : "Not complete")
    }
}

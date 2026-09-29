import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The Life Map as a permanent destination, not an onboarding souvenir.
///
/// Everything here derives from canonical records — active life areas and their
/// `sortOrder`, the default working-hours profile, and the small Life Map
/// profile. Archive an area or reorder it in Life Management and this map
/// changes with it, because there is no second copy of that state to fall out
/// of sync.
struct LifeMapManagementView: View {
    let areaRows: [LifeManagementAreaRow]

    /// Injected so the view does not reach through `UIApplication.shared.delegate`
    /// for a persistent container. That reach-through is why this screen showed a
    /// hardcoded capacity in every test and preview.
    var loadWeeklyMinutes: () async -> Int? = LifeMapManagementView.defaultWeeklyMinutes

    @State private var capacityFraction: Double?
    @State private var profile: LifeMapProfile?

    private var activeRows: [LifeManagementAreaRow] {
        areaRows
            .filter { $0.lifeArea.isArchived == false }
            .sorted {
                if $0.lifeArea.sortOrder != $1.lifeArea.sortOrder {
                    return $0.lifeArea.sortOrder < $1.lifeArea.sortOrder
                }
                return $0.lifeArea.name.localizedCaseInsensitiveCompare($1.lifeArea.name) == .orderedAscending
            }
    }

    private var scene: LifeMapSceneModel {
        LifeMapSceneModel(
            lifeAreas: activeRows.enumerated().map { index, row in
                LifeMapSceneNode(
                    id: row.id.uuidString,
                    title: row.lifeArea.name,
                    symbol: row.lifeArea.icon ?? "circle.grid.2x2.fill",
                    colorHex: row.lifeArea.color,
                    kind: .lifeArea,
                    emphasis: max(0.82, 1 - Double(index) * 0.045)
                )
            },
            capacityFraction: capacityFraction ?? 0,
            centerPromise: LifeMapDesiredChange(rawValue: profile?.desiredChangeID ?? "")?.title ?? String(localized: "Your day"),
            captureTitle: nil
        )
    }

    private var hasBuiltMap: Bool { profile != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl - 2) {
                header
                canvas
                actions
                Text("Rerun setup to finish permissions or Eva.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Life map")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            profile = LifeMapProfileStore.shared.load()
            if let minutes = await loadWeeklyMinutes() {
                capacityFraction = LifeMapCapacity.fraction(forTotalMinutes: minutes)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(hasBuiltMap ? "Your life areas" : "Build your life map")
                .font(.lifeboard(.title1))
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text(hasBuiltMap
                ? String(localized: "Edit your areas in Settings to change it.")
                : String(localized: "Takes a few minutes. Your existing data stays."))
                .font(.lifeboard(.support))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canvas: some View {
        LifeMapOrbitCanvas(
            scene: scene,
            step: .reveal,
            selectedRoot: nil,
            isInteractive: false
        )
        .frame(maxWidth: 560)
        .padding(Theme.Spacing.lg + 2)
        .lifeBoardClaySurface(.raised, cornerRadius: 30)
    }

    private var actions: some View {
        Button {
            NotificationCenter.default.post(name: .lifeboardStartOnboardingRequested, object: nil)
        } label: {
            Label(
                hasBuiltMap ? String(localized: "Update map") : String(localized: "Build map"),
                systemImage: hasBuiltMap ? "arrow.triangle.2.circlepath" : "sparkles"
            )
        }
        .buttonStyle(LifeMapPrimaryButtonStyle())
        .accessibilityIdentifier("settings.lifeMap.refresh")
    }

    /// Reads the default working-hours profile through the app's persistent
    /// container. Kept as a static default rather than inlined so tests and
    /// previews can substitute a value without a Core Data stack.
    @MainActor
    static func defaultWeeklyMinutes() async -> Int? {
        guard let container = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer,
              let profiles = try? await CoreDataPlanningRepository(container: container).fetchWorkingHoursProfiles(),
              let profile = profiles.first(where: \.isDefault) ?? profiles.first
        else { return nil }
        return profile.intervalsByWeekday.values
            .flatMap { $0 }
            .reduce(0) { $0 + max(0, $1.endMinute - $1.startMinute) }
    }
}

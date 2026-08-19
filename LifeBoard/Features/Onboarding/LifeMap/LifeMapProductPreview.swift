import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Read-only previews of what each app root does, opened by tapping a root in
/// the orbit.
///
/// Deliberately plain descriptions of real capabilities — no invented metrics,
/// no fabricated streaks, no screenshots of data the user does not have. A
/// preview that shows numbers nobody earned is a lie the product has to keep.
struct LifeMapProductPreview: View {
    let destination: Destination

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        ForEach(rows) { row in
                            Label(row.text, systemImage: row.symbol)
                                .font(.lifeboard(.body))
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                                .padding(Theme.Spacing.md + 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lifeBoardClaySurface(.raised, cornerRadius: 18)
                        }
                    }
                    Text("This is a read-only preview. Your Home uses only the areas and modules you chose.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.xl)
            }
            .background(Color.lifeboard(.bgCanvas))
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md + 2) {
            Image(systemName: destination.systemImage)
                .font(.lifeboard(.title1))
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 62, height: 62)
                .lifeBoardClaySurface(.well, cornerRadius: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.lifeboard(.title2))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(subtitle)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String { LifeMapRootCopy.subtitle(for: destination) }

    private var rows: [LifeMapRootCopy.Row] { LifeMapRootCopy.rows(for: destination) }
}

/// What each application root is for, in one place.
///
/// Lifted out of `LifeMapProductPreview` so the orientation tour reads the same
/// sentences the inspect-a-root sheet does. Two copies would drift, and the
/// tour is the first description of the app most users will ever read.
enum LifeMapRootCopy {
    struct Row: Identifiable {
        let symbol: String
        let text: String
        var id: String { symbol }
    }

    static func subtitle(for destination: Destination) -> String {
        switch destination {
        case .home: "Your calm starting point"
        case .plan: "Time shaped around capacity"
        case .track: "Routines and health in context"
        case .insights: "Reflection without judgment"
        case .eva: "Private guidance across the system"
        }
    }

    static func rows(for destination: Destination) -> [Row] {
        switch destination {
        case .home:
            [
                Row(symbol: "sun.max", text: "Today’s orientation"),
                Row(symbol: "checklist", text: "Your next useful actions"),
                Row(symbol: "rectangle.grid.1x2", text: "A Home tailored to your modules")
            ]
        case .plan:
            [
                Row(symbol: "calendar", text: "Week and schedule"),
                Row(symbol: "gauge.with.dots.needle.33percent", text: "Capacity-aware planning"),
                Row(symbol: "timer", text: "Focus sessions")
            ]
        case .track:
            [
                Row(symbol: "repeat", text: "Routines that bend with the day"),
                Row(symbol: "heart", text: "Health and care"),
                Row(symbol: "chart.xyaxis.line", text: "Progress you can understand")
            ]
        case .insights:
            [
                Row(symbol: "book.closed", text: "Reflection"),
                Row(symbol: "sparkles", text: "Patterns worth noticing"),
                Row(symbol: "arrow.triangle.2.circlepath", text: "Recovery and adaptation")
            ]
        case .eva:
            [
                Row(symbol: "lock.shield", text: "Private by design"),
                Row(symbol: "point.3.filled.connected.trianglepath.dotted", text: "Connect context across modules"),
                Row(symbol: "bubble.left.and.bubble.right", text: "Think through what comes next")
            ]
        }
    }
}

/// The "Tune" sheet behind the connections step, for users who want module-level
/// control rather than the four recommended groups.
struct LifeMapModuleTuneSheet: View {
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(OnboardingModuleCatalog.all) { module in
                Button {
                    onToggle(module.id)
                } label: {
                    HStack {
                        Label(module.title, systemImage: module.symbolName)
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Spacer()
                        Image(systemName: selectedIDs.contains(module.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.lifeboard(
                                selectedIDs.contains(module.id) ? .accentPrimary : .textQuaternary
                            ))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedIDs.contains(module.id) ? .isSelected : [])
                .accessibilityIdentifier(LifeMapAccessibilityID.module(module.id))
            }
            .navigationTitle("Your modules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Choose exactly what belongs on Home. You can change this later.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .padding()
            }
        }
    }
}

extension Destination: Identifiable {
    public var id: String { rawValue }
}

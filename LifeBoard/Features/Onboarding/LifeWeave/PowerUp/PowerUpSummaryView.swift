import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The receipt.
///
/// Deliberately not "3 of 3 connected". A denominator turns three independent,
/// optional choices into a score the user has just failed two-thirds of, and it
/// cannot express the states that actually matter here — syncing, reviewed with
/// no data yet, offline by choice, later by choice. Each row says what is
/// genuinely true of that connector instead.
///
/// Every status is read back from the connector's own resolver rather than from
/// a flag written when the screen was left, so a sync that finished while the
/// user was on the next screen is reflected here.
struct PowerUpSummaryView: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var completionTrigger = 0
    /// Guards replay. Restoring a finished summary is not new work, and firing
    /// the burst again would celebrate something that already happened.
    @State private var hasCelebrated = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LifeMapEyebrow(model.draft.evaCloudReady ? "POWERED UP" : "POWER-UP SUMMARY")
            Text(title)
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(LifeWeavePowerUpStep.connectors) { connector in
                    PowerUpSummaryRow(
                        symbolName: symbolName(for: connector),
                        name: connector.spokenName,
                        status: status(for: connector)
                    )
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 20)
            .accessibilityIdentifier("onboarding.lifeweave.powerup.summary.rows")

            if model.draft.evaCloudReady {
                evaGrounding
            }

            Text("You can change any of this later in Settings.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("onboarding.lifeweave.powerup.summary")
        // The one completion in this phase worth marking, and only once the
        // journey has actually resolved to a persisted state.
        .lifeboardCompletionBurst(trigger: completionTrigger)
        .task {
            guard hasCelebrated == false else { return }
            hasCelebrated = true
            completionTrigger &+= 1
        }
    }

    private var title: String {
        model.draft.evaCloudReady
            ? "Your LifeBoard is ready for real life."
            : "Your LifeBoard is ready."
    }

    /// Says what EVA has actually been given, not what it might do. The claim is
    /// checkable against the receipt on the reveal two screens ago.
    private var evaGrounding: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("EVA already knows")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            ForEach(groundingLines, id: \.self) { line in
                Text("• \(line)")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.lifeweave.powerup.summary.grounding")
    }

    private var groundingLines: [String] {
        var lines: [String] = []
        if let primary = model.draft.primaryLifeAreaTemplateID,
           let name = StarterWorkspaceCatalog.allLifeAreas.first(where: { $0.id == primary })?.name {
            lines.append("\(name) needs the clearest path")
        }
        if model.draft.stagedCapture?.isReviewed == true {
            lines.append("what you captured")
        }
        if model.draft.selectedCalendarIDs.isEmpty == false {
            lines.append("the shape of your day")
        }
        lines.append("only the context you approved")
        return lines
    }

    private func symbolName(for connector: LifeWeavePowerUpStep) -> String {
        switch connector {
        case .calendar: "calendar"
        case .health: "heart.fill"
        case .eva: "sparkles"
        case .complete: "circle"
        }
    }

    /// One word per connector, taken from that connector's own resolver.
    private func status(for connector: LifeWeavePowerUpStep) -> String {
        if model.draft.resolvedDeferredPowerUps.contains(connector) { return "Later" }
        switch connector {
        case .calendar: return calendarStatus
        case .health: return healthStatus
        case .eva: return evaStatus
        case .complete: return ""
        }
    }

    private var calendarStatus: String {
        switch model.calendarStage {
        case .proof:
            let count = model.selectedCalendarCount
            return "Ready · \(count) selected"
        case .chooser: return "No calendars chosen"
        case .primer: return "Not set up"
        case .recovery: return "Needs attention"
        }
    }

    /// "Syncing" and "reviewed, no data yet" are both honest endings. Neither is
    /// a failure, and neither may be dressed up as ready.
    private var healthStatus: String {
        switch model.healthFirstSyncOutcome {
        case .ready(let metricCount, _): "Ready · \(metricCount) metrics"
        case .syncing, .requesting: "Syncing in background"
        case .reviewedNoDataYet: "Access reviewed · no data yet"
        case .partial: "Needs attention"
        case .protectedDataLocked: "Waiting · device locked"
        case .unavailable: "Not available here"
        case .notRequested: "Not set up"
        }
    }

    private var evaStatus: String {
        if model.evaPrefersOffline { return "Offline EVA" }
        switch evaAccess.state {
        case .ready: return "Ready"
        case .activating, .hydrating: return "Connecting"
        case .quotaExhausted: return "Limited"
        case .ageBlocked, .temporarilyUnavailable, .appleReauthenticationRequired: return "Needs attention"
        case .needsDisclosure: return "Not set up"
        }
    }
}

/// Text and icon, never tint alone — the status has to survive greyscale.
private struct PowerUpSummaryRow: View {
    let symbolName: String
    let name: String
    let status: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: symbolName)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .accessibilityHidden(true)
            Text(name)
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Spacer(minLength: Theme.Spacing.sm)
            Text(status)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(status)")
    }
}

import SwiftUI

// The Health hub's two capture sheets.
//
// Both were `NavigationStack { Form { TextField(text: String) } }` with a
// toolbar Save — the incantation `ComposerScaffold` exists to delete. They are
// extracted from `HealthHubView` rather than converted in place because the hub
// is close to its size ceiling and the conversion adds a section struct each.
//
// Neither sheet had a single accessibility identifier. The ones here are new and
// follow the `track.hydration.*` naming the Track suite already uses.

// MARK: - Water

struct HealthWaterLogSheet: View {
    let repository: CoreDataTrackFoundationRepository

    @State private var amount: Double = 250
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComposerScaffold(
            title: "Log water",
            subtitle: "A number you chose, not one the app decided.",
            identifier: "health.water.composer"
        ) {
            HealthWaterAmountSection(amount: $amount)
        } commit: {
            ComposerCommitBar(
                title: "Log water",
                phase: commitPhase,
                isEnabled: amount > 0,
                identifier: "health.water.commit",
                action: commit
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func commit() {
        guard case .running = commitPhase else {
            commitPhase = .running(progress: nil)
            Task { await persist() }
            return
        }
    }

    private func persist() async {
        do {
            try await repository.saveHydrationLog(.init(
                amount: amount,
                unit: .milliliters,
                source: .manual
            ))
            SystemSurfaceRefresher.requestRefreshSoon()
            commitPhase = .success(receipt: ComposerReceipt())
            successTrigger &+= 1
            dismiss()
        } catch {
            // The banner belongs to the commit bar, which also offers the retry
            // the inline red `Text` never did.
            commitPhase = .recoverableFailure(.init(
                message: "Water could not be saved locally.",
                recovery: .retry
            ))
        }
    }
}

private struct HealthWaterAmountSection: View {
    @Binding var amount: Double

    /// The amounts a person actually logs, replacing the "250" that used to be
    /// hidden in a `@State` initialiser as an invisible default.
    private static let presets: [Double] = [150, 250, 500, 750]

    var body: some View {
        ComposerSection(
            "How much",
            footer: "Recorded locally, and mirrored to Apple Health if you allowed write-back."
        ) {
            ValueDrum(
                "Amount",
                value: $amount,
                in: 0...2_000,
                step: 50,
                coarseStep: 250,
                unit: "mL",
                fractionDigits: 0,
                identifier: "health.water.value"
            )
            OptionRail(
                "Common amounts",
                selection: $amount,
                values: Self.presets,
                identifierPrefix: "health.water.preset",
                title: { "\(Int($0).formatted()) mL" },
                showsLabel: false
            )
        }
    }
}

// MARK: - Weight

struct HealthWeightLogSheet: View {
    let repository: any WellnessRepository

    /// A neutral midpoint, not a reading. Seeding this with a plausible weight
    /// would put a number on screen that the person never recorded.
    @State private var kilograms: Double = 70
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComposerScaffold(
            title: "Log weight",
            subtitle: "A number you chose, not one the app decided.",
            identifier: "health.weight.composer"
        ) {
            HealthWeightAmountSection(kilograms: $kilograms)
        } commit: {
            ComposerCommitBar(
                title: "Log weight",
                phase: commitPhase,
                isEnabled: kilograms > 0,
                identifier: "health.weight.commit",
                action: commit
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func commit() {
        guard case .running = commitPhase else {
            commitPhase = .running(progress: nil)
            Task { await persist() }
            return
        }
    }

    private func persist() async {
        guard let sample = try? BodyMetricSample(
            kind: .bodyMass,
            value: kilograms,
            unit: .kilograms,
            source: .manual
        ) else {
            commitPhase = .recoverableFailure(.init(
                message: "That weight could not be recorded.",
                recovery: .retry
            ))
            return
        }

        do {
            try await repository.save(sample)
            SystemSurfaceRefresher.requestRefreshSoon()
            commitPhase = .success(receipt: ComposerReceipt())
            successTrigger &+= 1
            dismiss()
        } catch {
            commitPhase = .recoverableFailure(.init(
                message: "Weight could not be saved locally.",
                recovery: .retry
            ))
        }
    }
}

private struct HealthWeightAmountSection: View {
    @Binding var kilograms: Double

    var body: some View {
        // No presets. There is no sensible preset for a body weight, and
        // offering one would be the app deciding.
        ComposerSection(
            "Today's weight",
            footer: "Recorded locally, and mirrored to Apple Health if you allowed write-back."
        ) {
            ValueDrum(
                "Weight",
                value: $kilograms,
                in: 20...300,
                step: 0.1,
                coarseStep: 1,
                unit: "kg",
                fractionDigits: 1,
                identifier: "health.weight.value"
            )
        }
    }
}

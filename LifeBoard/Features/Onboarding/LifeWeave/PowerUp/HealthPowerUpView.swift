import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Power Up 2 of 3 — read-first primer and the first-sync receipt.
///
/// Owned by E4. Never claims a read grant from the system sheet returning;
/// readiness comes from observed data, not from the sheet closing.
///
/// The screen renders exactly one state at a time, and that state comes from
/// `LifeWeaveHealthFirstSync.resolve` — a pure function over the connection
/// store. Nothing here asks HealthKit anything, and nothing here keeps its own
/// copy of what Health said.
struct HealthPowerUpView: View {
    @ObservedObject var model: LifeWeaveOnboardingModel

    /// The same store Setup Center and the Health hub observe. Held so this
    /// screen can seed it from cache on appear; never mutated from here beyond
    /// the read-only connect the dock's primary performs.
    @State private var healthStore = HealthCoordinator.shared.connectionStore

    private var powerUpState: LifeWeaveHealthPowerUpState { .shared }

    private var outcome: HealthFirstSyncOutcome { model.healthFirstSyncOutcome }

    private var isFirstSyncRunning: Bool { outcome == .syncing }

    private var settledSummary: String? {
        LifeWeaveHealthFirstSync.settledAnnouncement(for: outcome)
    }

    @State private var syncPulseTrigger = 0
    /// Fires on observed data, never on the system sheet closing — the whole
    /// point of this screen is that those are not the same event.
    @State private var hasPulsed = false

    /// True only once readable Health data has actually been observed.
    private var isFirstSyncSucceeded: Bool {
        if case .ready = model.healthFirstSyncOutcome { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header
            stateContent
            privacyNote
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeboardHealthSyncPulse(trigger: syncPulseTrigger)
        .onChange(of: isFirstSyncSucceeded) { _, succeeded in
            guard succeeded, hasPulsed == false else { return }
            hasPulsed = true
            syncPulseTrigger &+= 1
        }
        .task {
            // A visit, not a launch: the back affordance can bring someone here
            // twice, and a stale spinner from the first visit would describe a
            // sync that already finished.
            powerUpState.resetForVisit()
            // Cached aggregates and the durable "we have asked" flag. Someone who
            // connected Health from a just-in-time prompt before reaching this
            // screen should see their receipt, not a primer for work they did.
            await healthStore.bootstrap()
            if isFirstSyncRunning {
                powerUpState.beginHandoffDeadline()
            }
        }
        .onChange(of: isFirstSyncRunning) { _, isRunning in
            if isRunning == false {
                powerUpState.cancelHandoffDeadline()
            }
        }
        .onChange(of: settledSummary) { _, summary in
            // One announcement when the screen settles. Announcing each metric as
            // it arrived turned a background import into a stream of
            // interruptions, none of which was a decision anyone could act on.
            guard let summary, summary != powerUpState.lastAnnouncedSummary else { return }
            powerUpState.lastAnnouncedSummary = summary
            AccessibilityNotification.Announcement(summary).post()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            LifeMapEyebrow("POWER UP · APPLE HEALTH")
            Text("Bring your health in.")
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text("See patterns from what you already log in Apple Health — without logging twice.")
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stateContent: some View {
        switch outcome {
        case .unavailable:
            HealthPowerUpNote(
                symbolName: "heart.slash",
                tone: .neutral,
                title: "Apple Health isn't available on this device.",
                detail: "There is nothing to set up here. The rest of your LifeBoard works exactly the same.",
                identifier: HealthPowerUpID.unavailableNote
            )
        case .notRequested:
            HealthPowerUpPrimer()
        case .requesting, .syncing:
            HealthFirstSyncChecklist(outcome: outcome)
        case .ready(let metricCount, let lastSync):
            HealthPowerUpReceipt(
                metricCount: metricCount,
                areaCount: LifeWeaveHealthFirstSync.observedDomainCount(aggregates: healthStore.aggregates),
                lastSync: lastSync
            )
        case .reviewedNoDataYet:
            // The exact sentence, split across title and detail so VoiceOver and
            // the eye read the same two claims: access was reviewed, and nothing
            // readable has been seen. Neither sentence says "denied", because
            // HealthKit never tells us that.
            HealthPowerUpNote(
                symbolName: "info.circle",
                tone: .neutral,
                title: "Health access was reviewed.",
                detail: "LifeBoard has not observed readable Health data yet. If something is recorded in Apple Health later, it will appear here on its own.",
                identifier: HealthPowerUpID.reviewedNote
            )
        case .partial(let errorCode):
            HealthPowerUpNote(
                symbolName: "exclamationmark.triangle",
                tone: .attention,
                title: "Health access was reviewed.",
                detail: Self.partialDetail(for: errorCode),
                identifier: HealthPowerUpID.partialNote
            )
        case .protectedDataLocked:
            HealthPowerUpNote(
                symbolName: "lock",
                tone: .attention,
                title: "This iPhone locked while Health was being read.",
                detail: "Health data can't be read while the device is locked. LifeBoard will pick it up the next time you are here and unlocked.",
                identifier: HealthPowerUpID.lockedNote
            )
        }
    }

    /// The store's error codes are non-sensitive by construction, but they are
    /// also meaningless to read, so each one becomes a sentence about what
    /// happened rather than a code to quote back at us.
    private static func partialDetail(for errorCode: String?) -> String {
        switch errorCode {
        case "authorization_request":
            "The request didn't finish, so nothing has been read yet. You can review Health access again any time from Settings."
        case "local_migration":
            "LifeBoard is still preparing its own storage, so nothing has been read yet. It will try again on its own."
        default:
            "Some of it couldn't be read just now. LifeBoard will try the rest in the background."
        }
    }

    private var privacyNote: some View {
        Text(LifeWeaveHealthCopy.privacyLine)
            .lifeboardFont(.caption1)
            .foregroundStyle(Color.lifeboard(.textTertiary))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(HealthPowerUpID.privacyLine)
    }
}

/// Stable identifiers for this screen.
///
/// Local rather than added to `LifeWeaveAccessibilityID`, because that file is
/// shared with the other two connectors and three people are writing at once.
enum HealthPowerUpID {
    static let primer = "onboarding.lifeweave.health.primer"
    static let dataTypes = "onboarding.lifeweave.health.dataTypes"
    static let privacyLine = "onboarding.lifeweave.health.privacy"
    static let progress = "onboarding.lifeweave.health.progress"
    static let receipt = "onboarding.lifeweave.health.receipt"
    static let reviewedNote = "onboarding.lifeweave.health.reviewedNoData"
    static let partialNote = "onboarding.lifeweave.health.partial"
    static let lockedNote = "onboarding.lifeweave.health.locked"
    static let unavailableNote = "onboarding.lifeweave.health.unavailable"

    static func benefit(_ id: String) -> String { "onboarding.lifeweave.health.benefit.\(id)" }
}

// MARK: - Primer

/// Why someone would want this, before what it costs.
///
/// Grouped by benefit. The retired screen opened with a flat list of read and
/// write categories, which asked people to understand LifeBoard's data model
/// before they had been given a single reason to care — and put the two scariest
/// words (write access) in front of the first useful one.
private struct HealthPowerUpPrimer: View {
    @State private var showsExactTypes = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(LifeWeaveHealthCopy.benefitGroups) { group in
                HealthBenefitRow(group: group)
            }

            Divider()
                .overlay(Color.lifeboard(.textTertiary).opacity(0.25))

            DisclosureGroup(isExpanded: $showsExactTypes) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(LifeWeaveHealthCopy.benefitGroups) { group in
                        // Named per group, so the exact types stay attached to the
                        // benefit they belong to instead of collapsing back into
                        // the flat list this disclosure exists to replace.
                        Text("\(group.title): \(group.readTypeNames.joined(separator: " · "))")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Says what LifeBoard will *use*, not what Apple's sheet will
                    // look like. We ask for read access only, and the sheet is
                    // Apple's screen to word.
                    Text("LifeBoard asks to read these. It does not ask to add anything to Apple Health during setup.")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Spacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.Spacing.xs)
            } label: {
                Text("See exact data types")
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
            }
            .tint(Color.lifeboard(.accentPrimary))
            .accessibilityIdentifier(HealthPowerUpID.dataTypes)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityIdentifier(HealthPowerUpID.primer)
    }
}

private struct HealthBenefitRow: View {
    let group: HealthBenefitGroup

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: group.symbolName)
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(group.promise)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(HealthPowerUpID.benefit(group.id))
    }
}

// MARK: - First sync

/// What is actually happening, in the order it happens.
///
/// Every row is driven by the resolver rather than by a timer, so a row that
/// says "done" is reporting an observation and not an elapsed second.
private struct HealthFirstSyncChecklist: View {
    let outcome: HealthFirstSyncOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HealthChecklistRow(
                title: "Health access reviewed",
                state: outcome == .requesting ? .active : .done
            )
            HealthChecklistRow(
                title: "Reading recent activity",
                state: outcome == .syncing ? .active : .pending
            )
            HealthChecklistRow(
                title: "Building today's context",
                state: .pending
            )
            Text("This keeps running in the background — you don't have to wait for it.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(HealthPowerUpID.progress)
    }
}

/// State is carried by a symbol *and* a word, never by colour: the spoken state
/// is part of the row's accessibility label, and the three symbols differ in
/// shape rather than only in tint.
private enum HealthChecklistState: Equatable {
    case pending
    case active
    case done

    var symbolName: String {
        switch self {
        case .pending: "circle"
        case .active: "circle.dotted"
        case .done: "checkmark.circle.fill"
        }
    }

    var spoken: String {
        switch self {
        case .pending: "Waiting"
        case .active: "In progress"
        case .done: "Done"
        }
    }
}

private struct HealthChecklistRow: View {
    let title: String
    let state: HealthChecklistState

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Group {
                if state == .active {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: state.symbolName)
                        .lifeboardFont(.body)
                        .foregroundStyle(
                            state == .done
                                ? Color.lifeboard(.statusSuccess)
                                : Color.lifeboard(.textTertiary)
                        )
                }
            }
            .frame(width: 24)
            .accessibilityHidden(true)

            Text(title)
                .lifeboardFont(.body)
                .foregroundStyle(
                    state == .pending
                        ? Color.lifeboard(.textTertiary)
                        : Color.lifeboard(.textPrimary)
                )
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(state.spoken).")
    }
}

// MARK: - Receipt

/// Counts and a time, and nothing else.
///
/// No health value ever appears during onboarding: a number here would be the
/// first thing a person reads about their own body, out of context, on a setup
/// screen — and it would also be the first place a shoulder-surfer reads it.
private struct HealthPowerUpReceipt: View {
    let metricCount: Int
    let areaCount: Int
    let lastSync: Date?

    private var countLine: String {
        let metrics = "\(metricCount) data type\(metricCount == 1 ? "" : "s")"
        guard areaCount > 0 else { return "\(metrics) available" }
        return "\(metrics) across \(areaCount) area\(areaCount == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.statusSuccess))
                    .accessibilityHidden(true)
                Text("LifeBoard can read your Health data.")
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(countLine)
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            if let lastSync {
                Text("Last updated \(lastSync.formatted(date: .omitted, time: .shortened))")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(HealthPowerUpID.receipt)
    }
}

// MARK: - Notes

/// Every settled state that is not a receipt. None of them is an error screen,
/// and none of them offers a retry that would only present the same sheet again.
private struct HealthPowerUpNote: View {
    enum Tone: Equatable {
        case neutral
        case attention
    }

    let symbolName: String
    let tone: Tone
    let title: String
    let detail: String
    let identifier: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: symbolName)
                .lifeboardFont(.body)
                .foregroundStyle(
                    tone == .attention
                        ? Color.lifeboard(.statusWarning)
                        : Color.lifeboard(.textTertiary)
                )
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

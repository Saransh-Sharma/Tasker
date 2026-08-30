import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Every stable accessibility identifier published by the EVA power-up.
///
/// The reveal's `onboarding.lifeWeave.eva.*` identifiers went away with the
/// screen that owned them; these are their replacements, under the power-up
/// namespace so a test can tell the two eras apart.
enum EvaPowerUpAccessibilityID {
    static let disclosure = "onboarding.lifeweave.powerup.eva.disclosure"
    static let baseContext = "onboarding.lifeweave.powerup.eva.baseContext"
    static let optionalContext = "onboarding.lifeweave.powerup.eva.optionalContext"
    static let reviewGrants = "onboarding.lifeweave.powerup.eva.reviewGrants"
    static let processing = "onboarding.lifeweave.powerup.eva.processing"
    static let offline = "onboarding.lifeweave.powerup.eva.offline"
    static let offlineCard = "onboarding.lifeweave.powerup.eva.offlineCard"
    static let cloud = "onboarding.lifeweave.powerup.eva.cloud"
    static let activating = "onboarding.lifeweave.powerup.eva.activating"
    static let ready = "onboarding.lifeweave.powerup.eva.ready"
    static let protectWithApple = "onboarding.lifeweave.powerup.eva.protectWithApple"
    static let failure = "onboarding.lifeweave.powerup.eva.failure"
    static let error = "onboarding.lifeweave.powerup.eva.error"
    static let grantSheet = "onboarding.lifeweave.powerup.eva.grantSheet"
    static let grantSheetDone = "onboarding.lifeweave.powerup.eva.grantSheet.done"

    static func stage(_ id: String) -> String { "onboarding.lifeweave.powerup.eva.stage.\(id)" }
    static func grant(_ id: String) -> String { "onboarding.lifeweave.powerup.eva.grant.\(id)" }
}

/// Power Up 3 of 3 — compact disclosure, grant review, activation stages.
///
/// Owned by E5. Drives every state from `EvaCloudAccessCoordinator`; retry goes
/// through the coordinator so single-use cloud routes are never replayed.
///
/// The four protected-context toggles are deliberately *not* on this frame. On
/// the old reveal they were, and the screen became four large switches with a
/// disclosure, a spinner, and an error line stacked around them — nobody read
/// any of it. Here the frame carries one summary row and the toggles live one
/// tap away, which is also where the granular decision actually belongs.
struct EvaPowerUpView: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared

    /// Mirrors the stored preference, the way Setup Center does. The preference
    /// lives in defaults rather than in a published property, so the view keeps
    /// its own copy and updates it in the same action that writes it.
    @State private var prefersOffline = EvaProviderRouter.Preference.resolvedStoredPreference() == .offline
    @State private var showsGrantReview = false
    @State private var showsProcessingDetail = false

    /// VoiceOver hears one line per real stage change, never one per frame.
    @State private var announcedStageIndex: Int?

    /// Linking Apple is optional, so its failure is reported here instead of
    /// being allowed to replace a working EVA with an error screen.
    @State private var appleLinkMessage: String?
    @State private var readyTrigger = 0
    /// EVA violet is identity, never success, so readiness is marked with the
    /// ordinary first-light bloom rather than an assistant-coloured wash.
    @State private var hasMarkedReady = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            // Hydration is a refresh, not an activation — it spends nothing and
            // is single-flight inside the coordinator. Skipped when the user has
            // already chosen offline, so a dead network cannot paint a cloud
            // failure over a screen that is not asking for the cloud.
            guard prefersOffline == false else { return }
            _ = await evaAccess.hydrate()
        }
        .onChange(of: currentStageIndex) { _, newIndex in announceStage(newIndex) }
        // Fires on the real readiness boundary — a resolved activation — not on
        // the activation request being sent.
        .onChange(of: evaAccess.state == .ready) { _, isReady in
            guard isReady, hasMarkedReady == false else { return }
            hasMarkedReady = true
            readyTrigger &+= 1
        }
        .lifeboardFirstLight(trigger: readyTrigger, tint: Color.lifeboard(.accentPrimary))
        .sheet(isPresented: $showsGrantReview) {
            EvaPowerUpGrantSheet(model: model, isLocked: isGrantSelectionLocked)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapEyebrow("POWER UP · EVA")
            Text("Give your LifeBoard a planning partner.")
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text("EVA can use the LifeBoard you just built to help you decide what to do first, plan a week that survives contact with real life, and break big things down.")
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var content: some View {
        if prefersOffline {
            offlineCard
        } else {
            switch evaAccess.state {
            case .hydrating, .needsDisclosure:
                EvaPowerUpDisclosureSection(
                    model: model,
                    isHydrating: evaAccess.state == .hydrating,
                    isWorking: evaAccess.isWorking,
                    showsGrantReview: $showsGrantReview,
                    showsProcessingDetail: $showsProcessingDetail,
                    onChooseOffline: selectOffline
                )
            case .activating:
                activationCard
            case .ready:
                readyCard
            case .temporarilyUnavailable(let message):
                failureCard(
                    title: "EVA couldn't finish connecting.",
                    detail: resolvedDetail(message, fallback: "The connection didn't complete. Nothing was lost."),
                    recovery: "Tap Retry Cloud EVA to pick up where this stopped."
                )
            case .quotaExhausted(let nextAvailableAt):
                failureCard(
                    title: "Today's included answers are used up.",
                    detail: quotaDetail(nextAvailableAt),
                    recovery: "You can wait for the allowance to reset, or use Offline EVA now."
                )
            case .ageBlocked(let message):
                failureCard(
                    title: "Cloud EVA isn't available for this account.",
                    detail: resolvedDetail(message, fallback: "Your account isn't eligible for Cloud EVA."),
                    recovery: "Offline EVA has no account and no age requirement."
                )
            case .appleReauthenticationRequired:
                failureCard(
                    title: "EVA needs your Apple sign-in again.",
                    detail: resolvedDetail(nil, fallback: "Your saved EVA session expired, so EVA can't prove this is still you."),
                    recovery: "Reconnecting with Apple restores the same EVA, with the same settings."
                )
            }
        }
    }

    // MARK: - Offline chosen

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapEyebrow("OFFLINE EVA")
            Text("EVA will run on this device.")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text("Nothing you write leaves this iPhone. You may need to pick a local model in Settings before EVA can answer, and you can switch to Cloud EVA whenever you want.")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            Button("Use Cloud EVA instead") { selectCloud() }
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier(EvaPowerUpAccessibilityID.cloud)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.offlineCard)
    }

    // MARK: - Activation

    /// A checklist of the real chain, not a spinner.
    ///
    /// Naming the current step is the difference between "this is slow" and
    /// "this is broken", and it costs nothing: the stage is already published.
    private var activationCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapEyebrow("CONNECTING")
            ForEach(activationStages) { stage in
                EvaPowerUpStageRow(
                    title: stage.title,
                    status: status(for: stage),
                    identifier: EvaPowerUpAccessibilityID.stage(stage.identifierSuffix)
                )
            }
            Text("Your LifeBoard is already safe. If this doesn't work, you can keep using it.")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            Text("Leaving is fine too — \"Finish later\" hands this to Settings, and you won't be asked to agree again.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.activating)
    }

    /// The real execution order, which is not the order the stages are declared
    /// in: age is confirmed *before* the device is verified.
    ///
    /// The age step is skipped outright when the signed configuration does not
    /// ask for a decision, so the row is dropped rather than drawn as complete —
    /// a checklist that ticks a step nobody ran is worse than a shorter list.
    private var activationStages: [EvaPowerUpStage] {
        var stages: [EvaPowerUpStage] = [.session]
        if evaAccess.account.configuration?.requiresAgeDecision == true {
            stages.append(.ageRange)
        }
        stages.append(contentsOf: [.device, .securing])
        return stages
    }

    private var currentStageIndex: Int? {
        switch evaAccess.account.activationStage {
        case .idle: nil
        case .creatingGuest: EvaPowerUpStage.session.rawValue
        case .confirmingAge: EvaPowerUpStage.ageRange.rawValue
        case .verifyingDevice: EvaPowerUpStage.device.rawValue
        case .finalizing: EvaPowerUpStage.securing.rawValue
        }
    }

    /// Position in the real chain decides the mark.
    ///
    /// Deliberately not "every stage this view happened to observe": SwiftUI can
    /// coalesce two updates, and a stage that genuinely ran would then sit at
    /// pending forever — which reads as a stall rather than as progress.
    private func status(for stage: EvaPowerUpStage) -> EvaPowerUpStageStatus {
        guard let current = currentStageIndex else { return .pending }
        if current > stage.rawValue { return .done }
        return current == stage.rawValue ? .active : .pending
    }

    private func announceStage(_ index: Int?) {
        guard let index, index != announcedStageIndex else { return }
        announcedStageIndex = index
        guard let caption = evaAccess.account.activationStage.progressCaption else { return }
        AccessibilityNotification.Announcement(caption).post()
    }

    // MARK: - Ready

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapEyebrow("CLOUD EVA IS ON")
            Text("EVA can plan with you now.")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text(readyDetail)
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            if isAppleRecoveryOffered {
                appleRecovery
            }
            if let appleLinkMessage {
                Text(appleLinkMessage)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(EvaPowerUpAccessibilityID.error)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.ready)
    }

    private var readyDetail: String {
        let selected = model.draft.resolvedEvaGrants.count
        guard selected > 0 else {
            return "It works from your life areas, tasks, and plans. You allowed none of the optional categories, and EVA will not ask for them mid-answer."
        }
        return "It works from your life areas, tasks, and plans, plus the \(selected) optional \(selected == 1 ? "category" : "categories") you allowed. You can change those any time in EVA settings."
    }

    /// Only for a guest session — an Apple-backed one already has recovery.
    private var isAppleRecoveryOffered: Bool {
        evaAccess.account.identityKind != .apple
    }

    private var appleRecovery: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button("Protect with Apple") { linkApple() }
                .buttonStyle(.lifeBoardChip)
                .disabled(evaAccess.isWorking)
                .accessibilityIdentifier(EvaPowerUpAccessibilityID.protectWithApple)
            Text("Optional. It lets this EVA come back if you reinstall LifeBoard or move to a new iPhone. Skipping it changes nothing today.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Failure

    /// Every failure says the same three things: what happened, that the
    /// LifeBoard is untouched, and what the one button will do about it.
    private func failureCard(title: String, detail: String, recovery: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapEyebrow("NOT CONNECTED")
            Text(title)
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.statusWarning))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(EvaPowerUpAccessibilityID.error)
            Text("Your LifeBoard is finished and saved. Nothing here changes it.")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            Text(recovery)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
            if isOfflineOfferedOnFailure {
                Button("Use Offline EVA instead") { selectOffline() }
                    .buttonStyle(.lifeBoardChip)
                    .accessibilityIdentifier(EvaPowerUpAccessibilityID.offline)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.failure)
    }

    /// Not offered where the dock's own primary already says "Use Offline EVA" —
    /// two buttons with one verb is a choice the user does not have.
    private var isOfflineOfferedOnFailure: Bool {
        switch evaAccess.state {
        case .quotaExhausted, .ageBlocked: false
        default: true
        }
    }

    private func resolvedDetail(_ message: String?, fallback: String) -> String {
        if let message, message.isEmpty == false { return message }
        if let errorMessage = evaAccess.errorMessage, errorMessage.isEmpty == false { return errorMessage }
        return fallback
    }

    private func quotaDetail(_ nextAvailableAt: Date?) -> String {
        let base = "Cloud EVA includes a set number of answers a day, and today's are gone."
        guard let nextAvailableAt else { return base }
        return "\(base) More become available \(nextAvailableAt.formatted(date: .omitted, time: .shortened))."
    }

    // MARK: - Actions

    /// Grants are confirmed with activation, so they stop being editable the
    /// moment the request is in flight. After success the server holds the
    /// consent revision, and changing it belongs to EVA settings.
    private var isGrantSelectionLocked: Bool {
        evaAccess.isWorking || evaAccess.state == .ready
    }

    private func selectOffline() {
        model.chooseOfflineEva()
        prefersOffline = true
    }

    private func selectCloud() {
        model.chooseCloudEva()
        prefersOffline = false
        appleLinkMessage = nil
        Task { _ = await evaAccess.hydrate() }
    }

    /// Recovery must never cost the user a working EVA.
    ///
    /// `reconnectApple()` drives the coordinator through `activating`, and a
    /// failure there leaves a failure state behind — which would replace this
    /// ready screen with an error for an action that was explicitly optional.
    /// Re-hydrating puts the real readiness back, and the reason is reported
    /// inline instead.
    private func linkApple() {
        appleLinkMessage = nil
        Task {
            let succeeded = await evaAccess.reconnectApple()
            guard succeeded == false else { return }
            let reason = evaAccess.errorMessage
            _ = await evaAccess.hydrate()
            appleLinkMessage = reason ?? "That didn't finish. EVA still works — you can protect it later in Settings."
        }
    }
}

// MARK: - Stage checklist

/// The disclosure frame, lifted out of `EvaPowerUpView`.
///
/// Its own type for two reasons: the parent's largest type was over the
/// file-size guardrail, and this codebase has already been bitten by god-view
/// bodies blowing the SwiftUI stack budget at `-Onone`. A section that owns its
/// own body is the fix for both.
private struct EvaPowerUpDisclosureSection: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let isHydrating: Bool
    let isWorking: Bool
    @Binding var showsGrantReview: Bool
    @Binding var showsProcessingDetail: Bool
    let onChooseOffline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            baseContextCard
            optionalContextRow
            processingDisclosure
            offlineAlternative
            if isHydrating {
                Text("Checking EVA…")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
        }
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.disclosure)
    }

    /// The base context is not a permission and is not offered as one.
    ///
    /// Presenting it as a fifth toggle would be a lie — EVA cannot plan your
    /// week without knowing what is in it — and it also made the four real
    /// choices look like formalities. It is stated, once, as what EVA works with.
    private var baseContextCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("What EVA works with")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text("Your life areas, tasks, and plans — the LifeBoard you just built. That is what EVA reasons about when you ask it something.")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.baseContext)
    }

    private var optionalContextRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Optional private context")
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text(grantSummary)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button("Review") { showsGrantReview = true }
                    .buttonStyle(.lifeBoardChip)
                    .accessibilityIdentifier(EvaPowerUpAccessibilityID.reviewGrants)
            }
            Text("These four categories never travel with a normal request. They go only if you allow them, and turning one off takes effect before EVA's next answer.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.optionalContext)
    }

    private var grantSummary: String {
        let selected = model.draft.resolvedEvaGrants.count
        let total = EvaConsentPolicy.Grant.allCases.count
        return selected == 0
            ? "None selected · EVA sees your LifeBoard only"
            : "\(selected) of \(total) selected"
    }

    /// Infrastructure detail, collapsed. It matters to some people and to no
    /// one else, and putting it inline is what buried the actual decision.
    private var processingDisclosure: some View {
        DisclosureGroup(isExpanded: $showsProcessingDetail) {
            Text("Your question and the context you allowed go to LifeBoard's own service on Cloudflare, which passes them to OpenAI and returns the answer. They are not used to train models, and are not kept after the answer comes back.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
        } label: {
            Text("How cloud processing works")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .tint(Color.lifeboard(.accentPrimary))
        .padding(Theme.Spacing.md)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.processing)
    }

    /// Offered, never imposed. A fallback the user did not choose is a downgrade
    /// they were not told about.
    private var offlineAlternative: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button("Use Offline EVA instead") { onChooseOffline() }
                .buttonStyle(.lifeBoardChip)
                .disabled(isWorking)
                .accessibilityIdentifier(EvaPowerUpAccessibilityID.offline)
            Text("Runs on this device. No account, nothing sent anywhere — slower, and it can't reason as well.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

private enum EvaPowerUpStage: Int, Identifiable, CaseIterable {
    // Raw values are the real execution order, which is why `ageRange` sits
    // between the session and the device check rather than after them.
    case session = 0
    case ageRange = 1
    case device = 2
    case securing = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .session: "Starting your EVA session"
        case .ageRange: "Confirming your age range"
        case .device: "Verifying this device"
        case .securing: "Securing your EVA session"
        }
    }

    var identifierSuffix: String {
        switch self {
        case .session: "session"
        case .ageRange: "ageRange"
        case .device: "device"
        case .securing: "securing"
        }
    }
}

private enum EvaPowerUpStageStatus {
    case pending
    case active
    case done
}

private struct EvaPowerUpStageRow: View {
    let title: String
    let status: EvaPowerUpStageStatus
    let identifier: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: symbolName)
                .lifeboardFont(.caption1)
                .foregroundStyle(markColor)
                .accessibilityHidden(true)
            Text(title)
                .lifeboardFont(.support)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(spokenStatus)")
        .accessibilityIdentifier(identifier)
    }

    private var symbolName: String {
        switch status {
        case .pending: "circle"
        case .active: "circle.dotted"
        case .done: "checkmark.circle.fill"
        }
    }

    private var markColor: Color {
        status == .pending ? Color.lifeboard(.textTertiary) : Color.lifeboard(.accentPrimary)
    }

    private var textColor: Color {
        status == .pending ? Color.lifeboard(.textTertiary) : Color.lifeboard(.textPrimary)
    }

    private var spokenStatus: String {
        switch status {
        case .pending: "waiting"
        case .active: "in progress"
        case .done: "done"
        }
    }
}

// MARK: - Grant review

/// The granular consent, one tap off the main frame.
///
/// Reads and writes the draft rather than the coordinator's `selectedGrants`:
/// that property defaults to every category when no receipt exists, so a screen
/// bound to it would show four switches the user never set and then send them.
private struct EvaPowerUpGrantSheet: View {
    @ObservedObject var model: LifeWeaveOnboardingModel
    let isLocked: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(EvaConsentPolicy.Grant.allCases, id: \.rawValue) { grant in
                        Toggle(isOn: binding(for: grant)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grant.onboardingTitle)
                                    .lifeboardFont(.bodyStrong)
                                    .foregroundStyle(Color.lifeboard(.textPrimary))
                                Text(grant.onboardingBlurb)
                                    .lifeboardFont(.caption1)
                                    .foregroundStyle(Color.lifeboard(.textTertiary))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(Color.lifeboard(.accentPrimary))
                        .disabled(isLocked)
                        .accessibilityIdentifier(EvaPowerUpAccessibilityID.grant(grant.rawValue))
                    }
                } header: {
                    Text("EVA may also look at")
                        .lifeboardFont(.eyebrow)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                } footer: {
                    Text(footerText)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                }
            }
            .navigationTitle("Optional context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(EvaPowerUpAccessibilityID.grantSheetDone)
                }
            }
        }
        .accessibilityIdentifier(EvaPowerUpAccessibilityID.grantSheet)
    }

    private var footerText: String {
        isLocked
            ? "These were sent with your confirmation. Change them any time in EVA settings — it takes effect before EVA's next answer, on every device."
            : "Nothing here is sent until you tap Enable Cloud EVA. Turning one off later takes effect before EVA's next answer, on every device."
    }

    private func binding(for grant: EvaConsentPolicy.Grant) -> Binding<Bool> {
        Binding(
            get: { model.draft.resolvedEvaGrants.contains(grant) },
            set: { model.toggleEvaGrant(grant, enabled: $0) }
        )
    }
}

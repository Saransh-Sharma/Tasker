import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct EvaDestination: View {
    @Environment(\.evaComposerBottomClearance) private var composerBottomClearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPrivacyDetailExpanded = false
    /// The badge must say where Eva's context actually goes: when cloud Eva is
    /// active, "on-device" is false.
    @ObservedObject private var cloudAccess = EvaCloudAccessCoordinator.shared

    @StateObject private var appManager: AppManager
    @StateObject private var activationCoordinator: EvaActivationCoordinator
    @State private var evidenceStore: TrackFoundationStore
    @State private var evidenceContext = EvaAuthorizedEvidenceContext.loading
    @State private var sharingPolicy: EvaEvidenceSharingPolicy
    private let planningRepository: CoreDataPlanningRepository?
    private let evidenceDefaults: UserDefaults
    let router: AppRouter
    let onComposerFocusChange: ((Bool) -> Void)?

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        planningRepository: CoreDataPlanningRepository?,
        habitProjectionService: (any TrackHabitProjectionService)?,
        goalSampleProvider: (any GoalSampleRepository)?,
        router: AppRouter,
        onComposerFocusChange: ((Bool) -> Void)? = nil
    ) {
        let manager = AppManager()
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
        _appManager = StateObject(wrappedValue: manager)
        _activationCoordinator = StateObject(wrappedValue: EvaActivationCoordinator(appManager: manager))
        _evidenceStore = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            habitProjectionService: habitProjectionService
        ))
        _sharingPolicy = State(initialValue: EvaEvidenceSharingPolicyPersistence.load(from: defaults))
        self.planningRepository = planningRepository
        self.evidenceDefaults = defaults
        self.router = router
        self.onComposerFocusChange = onComposerFocusChange
    }

    var body: some View {
        LLMStoreContainerHost(
            onLoadingAppear: {
                EvaNavigationPerformanceTrace.markInteractive()
            }
        ) { container in
            AnyView(
                EvaActivationRootView(
                    coordinator: activationCoordinator,
                    onDismiss: { router.select(.home) },
                    onComposerFocusChange: onComposerFocusChange,
                    onOpenTaskDetail: { router.push(.taskDetail($0.id), in: .eva) },
                    onOpenHabitDetail: { router.push(.habitDetail($0), in: .eva) },
                    onOpenRecordFromCard: { RecordRouteResolver.open($0, with: router) },
                    onOpenNavigationTargetFromCard: { EvaNavigationTargetResolver.open($0, with: router) }
                )
                .environmentObject(appManager)
                .environment(LLMRuntimeCoordinator.shared.evaluator)
                .environment(\.evaAuthorizedEvidenceContext, evidenceContext)
                .environment(\.evaEvidenceOpenAction, EvaEvidenceOpenAction(open: openEvidence))
                .modelContainer(container)
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            evaTopStrip
        }
        .navigationTitle(AssistantIdentitySnapshot.current.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.eva")
        .task { await loadAuthorizedEvidence() }
        .task {
            _ = await EvaCloudAccessCoordinator.shared.ensureActivated(source: .evaEntry)
        }
        .task {
            // The derived journal pipeline broadcasts after commits and
            // deletions; refresh Eva's authorized evidence live instead of
            // waiting for a manual pull.
            let updates = await JournalProjectionInvalidationService.shared.updates()
            for await event in updates {
                guard case .projectionsInvalidated = event else { continue }
                await loadAuthorizedEvidence()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if composerBottomClearance > 0 {
                Color.clear
                    .frame(height: composerBottomClearance + Theme.Spacing.xs)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: sharingPolicy) { _, policy in
            do {
                try EvaEvidenceSharingPolicyPersistence.save(policy, to: evidenceDefaults)
                Task { await loadAuthorizedEvidence() }
            } catch {
                evidenceContext = EvaAuthorizedEvidenceContext(
                    availability: .failed,
                    failureMessage: String(localized: "Couldn’t save sharing settings.")
                )
            }
        }
    }

    /// Eva's privacy disclosure — a badge, not a banner.
    ///
    /// It used to be a permanently pinned full-width row carrying a sentence
    /// and a menu, which spent a whole band of a chat screen restating
    /// something that does not change between sessions. Collapsed it is one
    /// lock; tapping it expands the sentence and the evidence controls to the
    /// right, in place, and tapping it again puts them away.
    ///
    /// The way *out* of Eva is not here — it is the chevron beside the title in
    /// the shared root header, which is where a back control belongs and where
    /// it stays legible while the keyboard covers everything below it.
    ///
    /// Clay rather than glass: `DESIGN.md` allows one hero glass object per
    /// screen and Eva's composer is it. This is chrome, not a decision surface.
    private var evaTopStrip: some View {
        HStack(spacing: Theme.Spacing.xs) {
            privacyBadge

            if isPrivacyDetailExpanded {
                Spacer(minLength: Theme.Spacing.xs)
                evidenceSharingMenu
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .frame(minHeight: 40)
        .lifeboardChromeSurface(cornerRadius: Theme.CornerRadius.lg, level: .e1, useNativeGlass: false)
        .fixedSize(horizontal: isPrivacyDetailExpanded == false, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var privacyBadge: some View {
        Button {
            appManager.playHaptic()
            withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                isPrivacyDetailExpanded.toggle()
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: usesCloudEva ? "cloud" : "lock.shield")
                    .font(.lifeboard(.caption1))
                if isPrivacyDetailExpanded {
                    Text(privacyBadgeTitle)
                        .font(.lifeboard(.caption1))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(minWidth: 40, minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(privacyBadgeTitle)
        .accessibilityHint(
            isPrivacyDetailExpanded
                ? "Hides sharing options"
                : "Shows sharing options"
        )
        .accessibilityIdentifier("eva.privacy.badge")
        .lifeboardPressFeedback()
    }

    private var usesCloudEva: Bool {
        cloudAccess.state == .ready && cloudAccess.automaticActivationAllowed
    }

    private var privacyBadgeTitle: String {
        usesCloudEva ? String(localized: "Cloud · only what you allow") : String(localized: "On \(DeviceNoun.this)")
    }

    private var evidenceSharingMenu: some View {
        Menu {
            Toggle("Body data", isOn: $sharingPolicy.permitsBody)
            Toggle("Mood check-ins", isOn: $sharingPolicy.permitsMood)
            Toggle("Medication and care", isOn: $sharingPolicy.permitsCare)
            Divider()
            Text("Journal access is in Journal settings.")
        } label: {
            Label("Sharing", systemImage: "checkmark.shield")
                .font(.lifeboard(.caption1))
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(minHeight: 44)
        }
        .accessibilityLabel("What \(AssistantIdentityText.currentSnapshot().displayName) can use")
    }

    private func loadAuthorizedEvidence() async {
        await evidenceStore.load()
        var rawEvents = evidenceStore.snapshot.normalizedEvents
        var planningFailure: String?

        if let planningRepository {
            do {
                async let records = planningRepository.fetchMutationReceipts(since: nil)
                async let sessions = planningRepository.sessions(since: nil)
                async let commands = planningRepository.commandReceipts(since: nil)
                let (resolvedRecords, resolvedSessions, resolvedCommands) = try await (records, sessions, commands)
                let sessionsWithDurableCommands = Set(resolvedCommands.map(\.sessionID))
                // Appended one source at a time. As a single three-way `+` of
                // mapped arrays this ran the type checker out of budget.
                let planningEvents = resolvedRecords.compactMap(InsightsLifeEventMappers.planningEvent)
                let focusEvents = resolvedSessions.flatMap { session in
                    InsightsLifeEventMappers.focusEvents(
                        session,
                        includesLegacyStateFallback: sessionsWithDurableCommands.contains(session.id) == false
                    )
                }
                let commandEvents = resolvedCommands.map(InsightsLifeEventMappers.focusCommandEvent)
                rawEvents += planningEvents
                rawEvents += focusEvents
                rawEvents += commandEvents
            } catch {
                planningFailure = error.localizedDescription
            }
        }

        var effectiveSharingPolicy = sharingPolicy
        effectiveSharingPolicy.permitsJournal = JournalPrivacyPolicyPersistence
            .load(from: evidenceDefaults)
            .permitsJournalEvidenceForEva
        let projected = SnapshotLifeEventProjectionRepository(events: rawEvents)
            .authorizedEvents(for: .eva, sharingPolicy: effectiveSharingPolicy)
        let projectedIDs = Set(projected.map(\.id))
        let withheld = rawEvents
            .filter { projectedIDs.contains($0.id) == false }
            .map(\.domain)

        let failures = [evidenceStore.errorMessage, planningFailure].compactMap { $0 }
        if projected.isEmpty, let failure = failures.first {
            evidenceContext = EvaAuthorizedEvidenceContext(
                availability: .failed,
                withheldDomains: withheld,
                failureMessage: failure
            )
        } else {
            evidenceContext = EvaAuthorizedEvidenceContext(
                availability: .ready,
                events: projected,
                withheldDomains: withheld,
                failureMessage: failures.first
            )
        }
    }

    private func openEvidence(_ evidence: EvidenceReference) {
        guard let reference = RecordRouteResolver.reference(for: evidence) else {
            router.select(.track)
            return
        }
        RecordRouteResolver.open(reference, with: router)
    }
}

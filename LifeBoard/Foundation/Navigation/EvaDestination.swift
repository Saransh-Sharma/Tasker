import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct EvaDestination: View {
    @Environment(\.evaComposerBottomClearance) private var composerBottomClearance

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
                    onOpenHabitDetail: { router.push(.habitDetail($0), in: .eva) }
                )
                .environmentObject(appManager)
                .environment(LLMRuntimeCoordinator.shared.evaluator)
                .environment(\.evaAuthorizedEvidenceContext, evidenceContext)
                .environment(\.evaEvidenceOpenAction, EvaEvidenceOpenAction(open: openEvidence))
                .modelContainer(container)
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 10) {
                    Label("Private on-device context", systemImage: "lock.shield")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Spacer(minLength: 8)
                    evidenceSharingMenu
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .navigationTitle("Eva")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.eva")
        .task { await loadAuthorizedEvidence() }
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
        .refreshable { await loadAuthorizedEvidence() }
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
                    failureMessage: "Evidence sharing preferences could not be saved."
                )
            }
        }
    }

    private var evidenceSharingMenu: some View {
        Menu {
            Toggle("Body signals", isOn: $sharingPolicy.permitsBody)
            Toggle("Mood check-ins", isOn: $sharingPolicy.permitsMood)
            Toggle("Medication and care", isOn: $sharingPolicy.permitsCare)
            Divider()
            Text("Journal sharing is managed in Journal Privacy")
        } label: {
            Label("Evidence", systemImage: "checkmark.shield")
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Eva evidence sharing")
        .accessibilityHint("Choose which sensitive LifeBoard evidence Eva may use")
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
        let id = evidence.routeID ?? evidence.sourceID
        switch evidence.kind {
        case "habit": router.push(.habitDetail(id), in: .eva)
        case "tracker": router.push(.trackerDetail(id), in: .eva)
        case "routine": router.push(.routine(id), in: .eva)
        case "goal": router.push(.goal(id), in: .eva)
        case "journal": router.openProtectedJournalRoute(.journalDay(id), in: .eva)
        case "focus": router.push(.focusSession(id), in: .eva)
        case "plan", "task": router.select(.plan)
        case "hydration", "mood", "sleep", "medication", "care": router.select(.track)
        default: router.select(.track)
        }
    }
}

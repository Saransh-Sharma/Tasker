import SwiftUI

struct SetupCenterHomeCard: View {
    let onOpen: () -> Void

    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var healthStore: HealthConnectionStore
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
    @State private var isDismissed = SetupCenterHomeCardPreference.isDismissed
    @State private var interrupted = ConnectionResumeStore.pending

    init(
        calendarIntegrationService: CalendarIntegrationService,
        healthStore: HealthConnectionStore,
        onOpen: @escaping () -> Void
    ) {
        _settingsViewModel = StateObject(
            wrappedValue: SettingsViewModel(
                calendarIntegrationService: calendarIntegrationService
            )
        )
        _healthStore = State(initialValue: healthStore)
        self.onOpen = onOpen
    }

    private var status: SetupCenterStatus {
        SetupCenterStatus.resolve(
            calendarAuthorization: settingsViewModel.calendarAuthorizationStatus,
            selectedCalendarCount: SetupCenterStatus.validCalendarSelectionCount(
                selectedIDs: settingsViewModel.selectedCalendarIDs,
                availableIDs: settingsViewModel.calendarService.snapshot.availableCalendars.map(\.id)
            ),
            calendarIsLoading: settingsViewModel.calendarService.snapshot.isLoading,
            calendarError: settingsViewModel.calendarService.snapshot.errorMessage,
            healthStatuses: healthStore.statuses,
            healthHasObservableData: healthStore.aggregates.isEmpty == false,
            healthIsRefreshing: healthStore.isRefreshing,
            healthErrorCode: healthStore.nonSensitiveErrorCode,
            healthPresentation: healthStore.presentation,
            evaAccessState: evaAccess.state,
            evaUsesOfflineProvider: providerPreference == .offline,
            offlineModelReady: offlineModelReady
        )
    }

    private var offlineModelReady: Bool {
        guard let current = settingsViewModel.assistantAppManager.currentModelName else { return false }
        return settingsViewModel.assistantAppManager.installedModels.contains(current)
    }

    var body: some View {
        Group {
        if (AppOnboardingStateStore.shared.load().hasOptionalJourneyToResume || !interrupted.isEmpty), !isDismissed, !status.allRowsHandled {
            HStack(spacing: SwiftUITokens.spacing.s12) {
                Button(action: onOpen) {
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        SettingsRowIcon(iconName: "slider.horizontal.3", tone: .accent)

                        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s4) {
                            Text("Resume connections")
                                .lifeboardFont(.bodyStrong)
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                            Text("Pick up an interrupted connection whenever you’re ready.")
                                .lifeboardFont(.caption2)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.lifeboard(.textQuaternary))
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.setupCenter.open")

                Button {
                    SetupCenterHomeCardPreference.dismiss()
                    isDismissed = true
                    Task { await ProductTelemetry.shared.record(.setupCenterDismissed, outcome: "home_card") }
                } label: {
                    Image(systemName: "xmark")
                        .lifeboardFont(.meta)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss Resume connections")
                .accessibilityIdentifier("home.setupCenter.dismiss")
            }
            .padding(SwiftUITokens.spacing.s12)
            // Clay, never glass — this invitation sits on Home, which already
            // owns the screen's hero.
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.hero)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.setupCenter.card")
            .task {
                settingsViewModel.reload()
                providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
                await healthStore.bootstrap()
                _ = await evaAccess.hydrate()
            }
            .onReceive(NotificationCenter.default.publisher(for: SetupCenterHomeCardPreference.didChange)) { _ in
                isDismissed = SetupCenterHomeCardPreference.isDismissed
            }
        }
        }
        .onReceive(NotificationCenter.default.publisher(for: ConnectionResumeStore.didChange)) { _ in
            interrupted = ConnectionResumeStore.pending
        }
    }
}

struct OnboardingFirstAction: Codable {
    let taskID: UUID?
    let title: String
    static let key = "onboarding.firstAction"

    static func save(from draft: LifeWeaveDraft) {
        guard draft.entryContext == .freshFlow else { return }
        let task = draft.stagedCapture.flatMap { $0.isReviewed && $0.kind == .task ? $0 : nil }
        let value = OnboardingFirstAction(taskID: task?.id, title: task?.text ?? "Capture your first task")
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct OnboardingFirstActionCard: View {
    let onOpenTask: (UUID) -> Void
    let onCreateTask: () -> Void
    @AppStorage(OnboardingFirstAction.key) private var receipt = Data()

    var body: some View {
        if let action = try? JSONDecoder().decode(OnboardingFirstAction.self, from: receipt) {
            HStack {
                Button {
                    receipt = Data()
                    if let id = action.taskID { onOpenTask(id) } else { onCreateTask() }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.taskID == nil ? "Start with one thing" : "Your first task is ready").lifeboardFont(.bodyStrong)
                        Text(action.title).lifeboardFont(.support)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button { receipt = Data() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Dismiss first task suggestion")
            }
            .padding(16)
            .lifeBoardClaySurface(.raised, cornerRadius: 16)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("home.onboarding.firstAction")
        }
    }
}

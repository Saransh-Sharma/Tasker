import SwiftUI

struct SetupCenterHomeCard: View {
    let onOpen: () -> Void

    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var healthStore: HealthConnectionStore
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
    @State private var isDismissed = SetupCenterHomeCardPreference.isDismissed
    @State private var interrupted = ConnectionResumeStore.pending
    /// Read once per view identity, not on every body pass: the store decodes
    /// JSON from defaults.
    @State private var hasOptionalJourneyToResume = AppOnboardingStateStore.shared.load().hasOptionalJourneyToResume

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
        if (hasOptionalJourneyToResume || !interrupted.isEmpty), !isDismissed, !status.allRowsHandled {
            HStack(spacing: SwiftUITokens.spacing.s12) {
                Button(action: onOpen) {
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        SettingsRowIcon(iconName: "slider.horizontal.3", tone: .accent)

                        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s4) {
                            Text("Resume setup")
                                .lifeboardFont(.bodyStrong)
                                .foregroundStyle(Color.lifeboard(.textPrimary))
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("home.setupCenter.dismiss")
            }
            .padding(SwiftUITokens.spacing.s12)
            // Clay, never glass — this invitation sits on Home, which already
            // owns the screen's hero.
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
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
            hasOptionalJourneyToResume = AppOnboardingStateStore.shared.load().hasOptionalJourneyToResume
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
        let value = OnboardingFirstAction(taskID: task?.id, title: task?.text ?? String(localized: "Add your first task"))
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
}

/// A one-shot highlight for the first-action card, armed when the first run
/// finishes so Home greets the user's own thing exactly once.
@MainActor
enum OnboardingFirstActionSpotlight {
    private(set) static var isArmed = false
    static func arm() { isArmed = true }
    static func consume() -> Bool {
        defer { isArmed = false }
        return isArmed
    }
}

struct OnboardingFirstActionCard: View {
    let onOpenTask: (UUID) -> Void
    let onCreateTask: () -> Void
    @AppStorage(OnboardingFirstAction.key) private var receipt = Data()
    @State private var spotlight = 0
    /// Decoded once when the card is created rather than on every body pass.
    @State private var decoded: OnboardingFirstAction?

    init(onOpenTask: @escaping (UUID) -> Void, onCreateTask: @escaping () -> Void) {
        self.onOpenTask = onOpenTask
        self.onCreateTask = onCreateTask
        let data = UserDefaults.standard.data(forKey: OnboardingFirstAction.key) ?? Data()
        _decoded = State(initialValue: try? JSONDecoder().decode(OnboardingFirstAction.self, from: data))
    }

    private func clear() {
        receipt = Data()
        decoded = nil
    }

    var body: some View {
        if let action = decoded {
            HStack(spacing: 12) {
                Button {
                    clear()
                    if let id = action.taskID { onOpenTask(id) } else { onCreateTask() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.taskID == nil ? "plus.circle.fill" : "circle")
                            .lifeboardFont(.title3)
                            .foregroundStyle(Color.lifeboard(.accentPrimary))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.taskID == nil ? String(localized: "Get started") : String(localized: "Your first task"))
                                .lifeboardFont(.caption1)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                            Text(action.title)
                                .lifeboardFont(.bodyStrong)
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button { clear() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .accessibilityLabel(String(localized: "Dismiss"))
            }
            .padding(16)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            .lifeboardFirstLight(trigger: spotlight, tint: Color.lifeboard(.accentPrimary))
            .accessibilityIdentifier("home.onboarding.firstAction")
            .onAppear {
                if OnboardingFirstActionSpotlight.consume() { spotlight &+= 1 }
            }
        }
    }
}

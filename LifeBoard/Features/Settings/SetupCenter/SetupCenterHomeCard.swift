import SwiftUI

struct SetupCenterHomeCard: View {
    let onOpen: () -> Void

    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var healthStore: HealthConnectionStore
    @StateObject private var evaAccess = EvaCloudAccessCoordinator.shared
    @State private var providerPreference = EvaProviderRouter.Preference.resolvedStoredPreference()
    @State private var isDismissed = SetupCenterHomeCardPreference.isDismissed

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
        if isDismissed == false, status.allRowsHandled == false {
            HStack(spacing: SwiftUITokens.spacing.s12) {
                Button(action: onOpen) {
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        SettingsRowIcon(iconName: "slider.horizontal.3", tone: .accent)

                        VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s4) {
                            Text("Finish personalizing")
                                .lifeboardFont(.bodyStrong)
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                            Text("Connect optional services or set up EVA when you’re ready.")
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
                .accessibilityLabel("Dismiss Finish personalizing")
                .accessibilityIdentifier("home.setupCenter.dismiss")
            }
            .padding(SwiftUITokens.spacing.s12)
            // Clay, never glass — this invitation sits on Home, which already
            // owns the screen's hero.
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.hero)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
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
}

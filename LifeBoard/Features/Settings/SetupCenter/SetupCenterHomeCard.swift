import SwiftUI

struct SetupCenterHomeCard: View {
    let onOpen: () -> Void

    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var healthStore: HealthConnectionStore
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
            notificationPermissionRequested: PermissionPromptState.hasRequested(.notifications),
            notificationPermissionDenied: settingsViewModel.isPermissionDenied,
            healthStatuses: healthStore.statuses,
            healthHasObservableData: healthStore.aggregates.isEmpty == false,
            evaIsActivated: EvaActivationDefaultsStore.load().isComplete
        )
    }

    var body: some View {
        if isDismissed == false, status.allRowsHandled == false {
            HStack(spacing: SwiftUITokens.spacing.s12) {
                Button(action: onOpen) {
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        Image(systemName: "slider.horizontal.3")
                            .lifeboardFont(.headline)
                            .foregroundStyle(Color.lifeboard(.accentPrimary))
                            .frame(width: 38, height: 38)
                            .background(Color.lifeboard(.accentWash), in: RoundedRectangle(cornerRadius: 12))

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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss Finish personalizing")
                .accessibilityIdentifier("home.setupCenter.dismiss")
            }
            .padding(SwiftUITokens.spacing.s12)
            .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.lifeboard(.borderSubtle), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.setupCenter.card")
            .task {
                settingsViewModel.reload()
                await healthStore.bootstrap()
            }
            .onReceive(NotificationCenter.default.publisher(for: SetupCenterHomeCardPreference.didChange)) { _ in
                isDismissed = SetupCenterHomeCardPreference.isDismissed
            }
        }
    }
}

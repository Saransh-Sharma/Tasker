import SwiftUI
#if os(iOS)
import UIKit
#endif
struct SettingsRootView: View {
    private enum NotificationExpansion: Hashable {
        case dueSoon
        case morning
        case nightly
        case quietHours
    }
    @ObservedObject var viewModel: SettingsViewModel
    let destination: SettingsDetailRoute?
    let presentationPreferences: PresentationPreferences?
    let onNavigate: ((SettingsDetailRoute) -> Void)?
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.openURL) var openURL
    @State private var expandedNotificationRow: NotificationExpansion?
    @State private var selectedPadCategory: SettingsDetailRoute?
    @State private var timelineAnchorDraft = TimelineAnchorDraft(preferences: WorkspacePreferences())
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @AppStorage("healthPrivacyLocalOnlyNoticeAcknowledged") private var didAcknowledgeHealthPrivacyNotice = false; @AppStorage(ProductTelemetry.enabledKey) private var productTelemetryEnabled = true
    @State private var showsHealthPrivacyNotice = false
    /// E5: Eva is the companion; the sprite personas are an opt-in under a closed disclosure.
    @State private var showsPersonaPicker = false
    /// Resolved on appear rather than recomputed per render: opening a SQLite
    /// index is not something a view body should do on every layout pass.
    @State private var recoveryStatus = RecoveryStatusService.live().status()
    @State private var showsCalendarChooser = false
    @State private var calendarChooserRequiresSelection = false
    @State var copiedVersion = false
    init(
        viewModel: SettingsViewModel,
        destination: SettingsDetailRoute? = nil,
        presentationPreferences: PresentationPreferences? = nil,
        onNavigate: ((SettingsDetailRoute) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.destination = destination
        self.presentationPreferences = presentationPreferences
        self.onNavigate = onNavigate
    }
    private let dueSoonLeadOptions: [(value: Int, label: String)] = [
        (15, String(localized: "15 min")),
        (30, String(localized: "30 min")),
        (45, String(localized: "45 min")),
        (60, String(localized: "1 hr")),
        (90, String(localized: "90 min")),
        (120, String(localized: "2 hr")),
    ]
    private let weekStartOptions: [(value: Weekday, label: String)] = Weekday.allCases.map {
        ($0, $0.displayTitle)
    }
    var spacing: SemanticSpacingTokens {
        tokens.spacing
    }
    /// The two-pane layout needs room for both panes. The layout class now
    /// follows the window's width, so a ½ Split View or a narrow window gets
    /// the single-column hub instead of a 390-point sidebar beside a sliver.
    private var isPadLayout: Bool {
        layoutClass == .padRegular || layoutClass == .padExpanded
    }
    var sectionTopPadding: CGFloat {
        SettingsMetrics.sectionSpacing
    }
    /// A deliberate tail below the last setting.
    ///
    /// This used to be a hard-coded 172 on phone, chosen to clear the floating
    /// dock and composer. The shell already measures that chrome and reserves it
    /// as a bottom safe-area inset for every destination
    /// (`FoundationShell.reservedChromeHeight`), so the constant reserved it a
    /// second time and left a dead band under the list that grew or shrank with
    /// nothing. What remains is breathing room, the same on both layouts.
    private var premiumBottomClearance: CGFloat {
        spacing.s32
    }

    private var setupStatus: SettingsSetupStatus {
        SettingsSetupStatusResolver.resolve(
            notificationPermissionGranted: viewModel.isPermissionGranted,
            notificationPermissionDenied: viewModel.isPermissionDenied,
            enabledNotificationCount: viewModel.enabledNotificationCount,
            calendarConnected: viewModel.calendarAuthorizationStatus.isAuthorizedForRead,
            healthConnected: healthStore.lastSuccessfulSync != nil,
            recoveryHealth: recoveryStatus.worstHealth
        )
    }
    private var overviewStatusItems: [SettingsStatusDescriptor] {
        [
            .init(
                id: "notifications",
                title: "Notifications",
                value: viewModel.notificationEnabledSummary,
                systemImage: viewModel.isPermissionGranted ? "bell.badge.fill" : "bell.slash.fill",
                tone: viewModel.notificationTone
            ),
            .init(
                id: "model",
                title: "Eva",
                value: viewModel.chiefOfStaffSummary,
                systemImage: "brain.head.profile",
                tone: .accent
            ),
            .init(
                id: "setup",
                title: "Setup",
                value: viewModel.setupStatusLabel,
                systemImage: "slider.horizontal.3",
                tone: .neutral
            ),
        ]
    }

    var body: some View {
        experienceBody
            .task {
                guard V2FeatureFlags.lifeBoardTrustClosureV1Enabled else { return }
                let journal = await RecoveryServices.journalIndexState()
                recoveryStatus = RecoveryStatusService.live(
                    journalIndexState: { journal }
                ).status()
            }
            .onAppear {
                viewModel.reload()
                timelineAnchorDraft = TimelineAnchorDraft(preferences: viewModel.workspacePreferences)
                // "Now stays on this device" is news only to someone whose
                // data moved; a new install never had it anywhere else.
                showsHealthPrivacyNotice = V2FeatureFlags.healthIntegrationsV1Enabled
                    && UserDefaults.standard.bool(forKey: "healthPrivacyMigrationAffectedUser")
                    && didAcknowledgeHealthPrivacyNotice == false
                Task { await healthStore.refreshAuthorization() }
            }
            .onDisappear {
                viewModel.commitTimelineAnchorDraft(timelineAnchorDraft)
            }
            .accessibilityIdentifier("settings.root")
            .alert("Health data stays on this device", isPresented: $showsHealthPrivacyNotice) {
                Button("Got it") {
                    didAcknowledgeHealthPrivacyNotice = true
                }
            } message: {
                Text("Health, mood and water logs aren’t synced to iCloud or analytics.")
            }
            .sheet(isPresented: $showsCalendarChooser, onDismiss: {
                calendarChooserRequiresSelection = false
            }) {
                EventKitCalendarChooserContainerView(
                    service: viewModel.calendarService,
                    initialSelectedCalendarIDs: viewModel.selectedCalendarIDs,
                    requiresAtLeastOneSelection: calendarChooserRequiresSelection,
                    onCancel: {
                        guard calendarChooserRequiresSelection else { return }
                        Task { await ProductTelemetry.shared.record(.connectorResult, outcome: "calendar_chooser_cancelled") }
                    },
                    onCommit: viewModel.updateSelectedCalendarIDs
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var experienceBody: some View {
        if V2FeatureFlags.lifeBoardPremiumIAV5Enabled {
            if let destination {
                premiumDestination(destination)
            } else if isPadLayout {
                premiumPadExperience
            } else {
                premiumHub
            }
        } else {
            legacyExperience
        }
    }

    private var legacyExperience: some View {
        ScreenScaffold(mode: .utility, placement: .focusedPresentation, readableWidth: 1180) {
            ScrollView {
                VStack(spacing: 0) {
                    overviewSection
                        .padding(.horizontal, spacing.screenHorizontal)
                        .padding(.top, spacing.s16)

                    if isPadLayout {
                        iPadSettingsBody
                    } else {
                        phoneSettingsBody
                    }

                    SettingsFooterView()
                }
                .padding(.bottom, spacing.s24)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var premiumHub: some View {
        ScreenScaffold(mode: .utility, placement: .focusedPresentation, readableWidth: 720) {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s20) {
                    SettingsHubHeading()
                    SettingsSetupStatusCard(status: setupStatus, onNavigate: navigate)
                    SettingsCategoryGroup(selectedRoute: nil, onNavigate: navigate)
                }
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
                .padding(.bottom, premiumBottomClearance)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var premiumPadExperience: some View {
        ScreenScaffold(mode: .utility, placement: .focusedPresentation, readableWidth: 1180) {
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s20) {
                        SettingsHubHeading()
                        SettingsSetupStatusCard(status: setupStatus, onNavigate: selectPadCategory)
                        SettingsCategoryGroup(selectedRoute: selectedPadCategory, onNavigate: selectPadCategory)
                    }
                    .padding(spacing.s20)
                }
                .scrollIndicators(.hidden)
                .frame(width: layoutClass == .padExpanded ? 390 : 320)

                Divider()
                    .overlay(Color.lifeboard(.borderSubtle))

                if let selectedPadCategory {
                    premiumCategoryScroll(selectedPadCategory)
                        .id(selectedPadCategory)
                        .transition(.opacity)
                } else {
                    SettingsPadWelcome(status: setupStatus)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(spacing.s32)
                }
            }
            .animation(
                LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.roleLocalState,
                value: selectedPadCategory
            )
        }
    }

    @ViewBuilder
    private func premiumDestination(_ route: SettingsDetailRoute) -> some View {
        switch route {
        case .setupCenter:
            SetupCenterView(settingsViewModel: viewModel, onNavigate: navigate)
        case .llm:
            LLMSettingsView(currentThread: .constant(nil))
                .environmentObject(viewModel.assistantAppManager)
                .environment(LLMRuntimeCoordinator.shared.evaluator)
        case .chats:
            ChatsSettingsView(currentThread: .constant(nil))
                .environmentObject(viewModel.assistantAppManager)
                .environment(LLMRuntimeCoordinator.shared.evaluator)
        case .models:
            ModelsSettingsView()
                .environmentObject(viewModel.assistantAppManager)
                .environment(LLMRuntimeCoordinator.shared.evaluator)
        case .recovery:
            RecoveryCenterView(
                status: recoveryStatus,
                onRecover: { recovery in
                    _ = recovery
                    return String(localized: "Open Journal to rebuild search.")
                },
                onExportDiagnostics: viewModel.copyRecoveryDiagnostics
            )
        case .notices:
            CreditsView()
        case .lifeManagement:
            StatusSurface(
                state: .unavailable,
                title: "Life management",
                message: "Go back and open it again."
            )
        default:
            premiumCategoryScroll(route)
        }
    }

    private func premiumCategoryScroll(_ route: SettingsDetailRoute) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsCategoryHeading(route: route)
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.top, spacing.s16)
                premiumCategoryContent(route)
                if route == .dataAndHelp {
                    SettingsFooterView()
                }
            }
            .padding(.bottom, premiumBottomClearance)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(isPadLayout && destination == nil ? "Settings" : route.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func premiumCategoryContent(_ route: SettingsDetailRoute) -> some View {
        switch route {
        case .setupCenter:
            EmptyView()
        case .planAndOrganize:
            workspaceSection(baseIndex: 0)
            timelineSection(baseIndex: 2)
        case .calendarAndHealth:
            calendarSection(baseIndex: 0)
            healthSection(baseIndex: 3)
        case .eva:
            aiAssistantSection(baseIndex: 0)
        case .reminders:
            notificationsSection(baseIndex: 0)
        case .lookAndFeel:
            if let presentationPreferences {
                SettingsLookAndFeelView(
                    preferences: presentationPreferences,
                    decorativeEffectsEnabled: Binding(
                        get: { viewModel.decorativeButtonEffectsEnabled },
                        set: { isEnabled in
                            viewModel.setDecorativeButtonEffectsEnabled(isEnabled)
                        }
                    )
                )
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)
            } else {
                appearanceSection(baseIndex: 0)
            }
        case .dataAndHelp:
            if V2FeatureFlags.lifeBoardTrustClosureV1Enabled {
                dataSection(baseIndex: 0)
            }
            helpSection(baseIndex: 1)
        default:
            EmptyView()
        }
    }

    private func selectPadCategory(_ route: SettingsDetailRoute) {
        if route == .setupCenter {
            navigate(route)
            return
        }
        if route.isCategory {
            selectedPadCategory = route
            Haptic.pick.play()
        } else {
            navigate(route)
        }
    }

    func navigate(_ route: SettingsDetailRoute) {
        if let onNavigate {
            onNavigate(route)
            return
        }
        switch route {
        case .lifeManagement:
            viewModel.onNavigateToLifeManagement?()
        case .llm:
            viewModel.onNavigateToAISettings?()
        case .chats:
            viewModel.onNavigateToChats?()
        case .models:
            viewModel.onNavigateToModels?()
        default:
            break
        }
    }
}

private extension SettingsRootView {
    private var overviewSection: some View {
        SettingsHeroCard(
            eyebrow: "LifeBoard",
            title: "Settings",
            subtitle: "",
            statusItems: overviewStatusItems,
            accessibilityIdentifier: "settings.hero.card"
        )
    }

    private var phoneSettingsBody: some View {
        VStack(spacing: 0) {
            // baseIndex controls stagger ordering; gaps leave room for expanded card content.
            workspaceSection(baseIndex: 1)
            calendarSection(baseIndex: 4)
            healthSection(baseIndex: 7)
            timelineSection(baseIndex: 8)
            aiAssistantSection(baseIndex: 10)
            notificationsSection(baseIndex: 12)
            appearanceSection(baseIndex: 20)
            if V2FeatureFlags.lifeBoardTrustClosureV1Enabled {
                dataSection(baseIndex: 21)
            }
            helpSection(baseIndex: 22)
        }
    }

    private var iPadSettingsBody: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: spacing.sectionGap) {
                VStack(spacing: 0) {
                    // Keep the same stagger ordering across compact and regular layouts.
                    workspaceSection(baseIndex: 1, includeHorizontalPadding: false)
                    calendarSection(baseIndex: 4, includeHorizontalPadding: false)
                    healthSection(baseIndex: 7, includeHorizontalPadding: false)
                    timelineSection(baseIndex: 8, includeHorizontalPadding: false)
                    aiAssistantSection(baseIndex: 10, includeHorizontalPadding: false)
                    appearanceSection(baseIndex: 20, includeHorizontalPadding: false)
                    if V2FeatureFlags.lifeBoardTrustClosureV1Enabled {
                        dataSection(baseIndex: 21, includeHorizontalPadding: false)
                    }
                    helpSection(baseIndex: 22, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)

                VStack(spacing: 0) {
                    notificationsSection(baseIndex: 12, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, spacing.screenHorizontal)
        }
    }

    private func healthSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Apple Health",
            subtitle: "Saves new logs to Apple Health.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard(active: healthStore.lastSuccessfulSync != nil) {
                    VStack(spacing: SettingsMetrics.cardInnerPadding) {
                        ForEach(HealthDomain.allCases.filter(\.supportsWriteBack)) { domain in
                            SettingsToggleRow(
                                iconName: domain.symbolName,
                                title: domain.title,
                                subtitle: domain.shareBlurb,
                                isOn: Binding(
                                    get: { healthStore.statuses[domain]?.writeEnabled ?? false },
                                    set: { enabled in
                                        Task { await healthStore.setWriteEnabled(enabled, for: domain) }
                                    }
                                ),
                                tone: healthTone(for: domain),
                                summaryText: healthWriteSummary(for: domain),
                                accessibilityIdentifier: "settings.health.\(domain.rawValue).toggle"
                            )
                            if domain != HealthDomain.allCases.filter(\.supportsWriteBack).last {
                                Divider()
                            }
                        }
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsCard {
                    VStack(spacing: SettingsMetrics.cardInnerPadding) {
                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "arrow.triangle.2.circlepath",
                                title: healthStore.isRefreshing ? "Syncing…" : "Sync now",
                                subtitle: healthSyncSubtitle,
                                trailingStatus: healthStore.lastSuccessfulSync?.formatted(date: .abbreviated, time: .shortened),
                                tone: .accent,
                                accessibilityIdentifier: "settings.health.sync"
                            ),
                            action: { Task { await healthStore.syncNow() } }
                        )

                        Divider()

                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "gear",
                                title: "Health access",
                                subtitle: "Opens the Settings app.",
                                tone: .neutral,
                                accessibilityIdentifier: "settings.health.recovery"
                            ),
                            action: openAppSettings
                        )
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
            }
        }
    }

    private func healthWriteSummary(for domain: HealthDomain) -> String {
        guard let status = healthStore.statuses[domain] else { return "Not connected" }
        if status.hasPartialWriteAuthorization { return "Partial" }
        if status.writeAuthorizations.values.contains(.denied) { return "Denied" }
        if status.writeAuthorizations.values.allSatisfy({ $0 == .authorized }) { return "Allowed" }
        return "Not requested"
    }

    private func healthTone(for domain: HealthDomain) -> SettingsTone {
        let summary = healthWriteSummary(for: domain)
        if summary == "Allowed" { return .success }
        if summary == "Denied" || summary == "Partial" { return .warning }
        return .neutral
    }

    private var healthSyncSubtitle: String {
        if healthStore.nonSensitiveErrorCode != nil {
            return String(localized: "Couldn’t finish the last sync. Nothing was lost.")
        }
        return String(localized: "Works offline.")
    }

    private func openAppSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func openCalendarChooser() {
        guard viewModel.calendarAuthorizationStatus.isAuthorizedForRead else {
            viewModel.requestCalendarPermission()
            return
        }
        calendarChooserRequiresSelection = false
        showsCalendarChooser = true
    }

    private func workspaceSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Workspace",
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "square.grid.2x2.fill",
                            title: "Life management",
                            subtitle: "Areas, projects and habits",
                            accessibilityIdentifier: "settings.workspace.lifeManagement.row"
                        ),
                        action: { navigate(.lifeManagement) }
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsCard {
                    VStack(alignment: .leading, spacing: SettingsMetrics.cardInnerPadding) {
                        SettingsInfoRow(
                            iconName: "calendar",
                            title: "Week starts on",
                            subtitle: "",
                            accessibilityIdentifier: "settings.workspace.weekStart.row"
                        )

                        // The row above names the choice; the chips are it.
                        SettingsChipSelector(
                            title: "",
                            options: weekStartOptions,
                            selectedValue: viewModel.workspacePreferences.weekStartsOn,
                            onSelect: viewModel.updateWeekStartsOn,
                            accessibilityIdentifier: "settings.workspace.weekStart.selector"
                        )
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
            }
        }
    }

    private func calendarSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: String(localized: "Calendar"),
            subtitle: String(localized: "Read-only. Events show next to your tasks."),
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard(active: viewModel.calendarAuthorizationStatus.isAuthorizedForRead) {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: viewModel.calendarAuthorizationStatus.isAuthorizedForRead ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark",
                            title: String(localized: "Calendar access"),
                            subtitle: viewModel.calendarAccessSubtitle,
                            trailingStatus: viewModel.calendarAccessStatusLabel,
                            tone: viewModel.calendarAccessTone,
                            accessibilityIdentifier: "settings.calendar.access.row"
                        ),
                        action: viewModel.requestCalendarPermission
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "slider.horizontal.3",
                            title: String(localized: "Calendars"),
                            subtitle: viewModel.calendarAuthorizationStatus.isAuthorizedForRead
                                ? ""
                                : String(localized: "Turn on calendar access first."),
                            trailingStatus: viewModel.calendarStatusSummary,
                            tone: viewModel.calendarAuthorizationStatus.isAuthorizedForRead ? .accent : .warning,
                            accessibilityIdentifier: "settings.calendar.selection.row"
                        ),
                        action: openCalendarChooser
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                SettingsCard {
                    VStack(spacing: SettingsMetrics.cardInnerPadding) {
                        SettingsToggleRow(
                            iconName: "person.crop.circle.badge.xmark",
                            title: String(localized: "Show declined events"),
                            subtitle: nil,
                            isOn: Binding(
                                get: { viewModel.includeDeclinedCalendarEvents },
                                set: { viewModel.setIncludeDeclinedCalendarEvents($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeDeclined.toggle"
                        )

                        Divider()

                        SettingsToggleRow(
                            iconName: "calendar.badge.exclamationmark",
                            title: String(localized: "Show canceled events"),
                            subtitle: nil,
                            isOn: Binding(
                                get: { viewModel.includeCanceledCalendarEvents },
                                set: { viewModel.setIncludeCanceledCalendarEvents($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeCanceled.toggle"
                        )

                        Divider()

                        SettingsToggleRow(
                            iconName: "sun.max",
                            title: String(localized: "All-day events in lists"),
                            subtitle: nil,
                            isOn: Binding(
                                get: { viewModel.includeAllDayInAgenda },
                                set: { viewModel.setIncludeAllDayInAgenda($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeAllDayAgenda.toggle"
                        )

                        Divider()

                        SettingsToggleRow(
                            iconName: "chart.bar.xaxis",
                            title: String(localized: "All-day events as busy"),
                            subtitle: nil,
                            isOn: Binding(
                                get: { viewModel.includeAllDayInBusyStrip },
                                set: { viewModel.setIncludeAllDayInBusyStrip($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeAllDayBusy.toggle"
                        )
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)
            }
        }
    }

    private func aiAssistantSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: viewModel.chiefOfStaffSummary,
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard(active: true) {
                    chiefOfStaffIdentityCard
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsCard(active: true) {
                    DisclosureGroup(isExpanded: $showsPersonaPicker) {
                        MascotPersonaSelector(
                            selectedID: viewModel.selectedMascotID,
                            cardAccessibilityPrefix: "settings.chiefOfStaff.persona",
                            onSelect: viewModel.selectChiefOfStaffMascot
                        )
                        .padding(.top, 8)
                    } label: {
                        Text("Change companion")
                            .font(.lifeboard(.bodyEmphasis))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                    }
                    .tint(Color.lifeboard(.accentPrimary))
                    .accessibilityIdentifier("settings.chiefOfStaff.persona.disclosure")
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                SettingsCard(active: viewModel.memoryItemCount > 0) {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "sparkles.rectangle.stack.fill",
                            title: String(localized: "\(viewModel.chiefOfStaffSummary) settings"),
                            subtitle: "",
                            trailingStatus: viewModel.aiAssistantSummary,
                            inlineBadge: viewModel.memoryItemCount == 0 ? SettingsInlineBadge(title: String(localized: "No memories")) : nil,
                            tone: .accent,
                            accessibilityIdentifier: "settings.aiAssistant.row"
                        ),
                        action: { navigate(.llm) }
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)

                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "bubble.left.and.bubble.right.fill",
                            title: "Chat behavior",
                            subtitle: "",
                            tone: .accent,
                            accessibilityIdentifier: "settings.aiAssistant.chats.row"
                        ),
                        action: { navigate(.chats) }
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 3)
            }
        }
    }

    private var chiefOfStaffIdentityCard: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            DecorImage(asset: .thinkingCup, size: 58, opacity: 0.92)
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(viewModel.selectedMascotPersona.displayName)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .accessibilityIdentifier("settings.chiefOfStaff.name")
                Text("Your assistant")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.chiefOfStaff.card")
        .accessibilityLabel("\(viewModel.selectedMascotPersona.displayName), your assistant")
    }

    private func timelineSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: String(localized: "Timeline"),
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard {
                    SettingsToggleRow(
                        iconName: "calendar.badge.clock",
                        title: String(localized: "Show events in timeline"),
                        subtitle: String(localized: "On Home and in the week view."),
                        isOn: Binding(
                            get: { viewModel.showCalendarEventsInTimeline },
                            set: { viewModel.setShowCalendarEventsInTimeline($0) }
                        ),
                        tone: .neutral,
                        accessibilityIdentifier: "settings.timeline.showCalendarEvents.toggle"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsFieldCard(
                    title: String(localized: "Day start and end"),
                    subtitle: "",
                    footer: String(localized: "Wind down can fall after midnight."),
                    accessibilityIdentifier: "settings.timeline.anchors.card"
                ) {
                    VStack(spacing: spacing.s12) {
                        HStack(spacing: spacing.s12) {
                            Text(String(localized: "Rise and shine"))
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { timelineAnchorDraft.time(for: .wake) },
                                    set: { timelineAnchorDraft.setTime($0, for: .wake) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.lifeboard(.accentPrimary))
                            .accessibilityIdentifier("settings.timeline.riseAndShine.picker")
                            .accessibilityValue(timelineRiseAndShineDraftSummary)
                        }

                        HStack(spacing: spacing.s12) {
                            Text(String(localized: "Wind down"))
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { timelineAnchorDraft.time(for: .windDown) },
                                    set: { timelineAnchorDraft.setTime($0, for: .windDown) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.lifeboard(.accentPrimary))
                            .accessibilityIdentifier("settings.timeline.windDown.picker")
                            .accessibilityValue(timelineWindDownDraftSummary)
                        }
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
            }
        }
    }

    private func notificationsSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Notifications",
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                // iOS has recorded a refusal: nothing below can reach the
                // person until it is turned on in Settings, so say so first.
                if viewModel.isPermissionDenied {
                    PermissionRecoveryCard(
                        kind: .notifications,
                        detail: "Notifications are off. Turn them on in Settings."
                    )
                    .enhancedStaggeredAppearance(index: baseIndex)
                }

                SettingsCard {
                    SettingsToggleRow(
                        iconName: "bell.badge.fill",
                        title: "Task reminders",
                        subtitle: nil,
                        isOn: Binding(
                            get: { viewModel.preferences.taskRemindersEnabled },
                            set: { viewModel.togglePreference(\.taskRemindersEnabled, value: $0) }
                        ),
                        accessibilityIdentifier: "settings.notifications.taskReminders.row"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsCard {
                    SettingsToggleSummaryRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "clock.badge.exclamationmark",
                            title: "Due soon reminders",
                            subtitle: "",
                            rowType: .toggleSummary,
                            summaryText: viewModel.dueSoonLeadTimeSummary,
                            accessibilityIdentifier: "settings.notifications.dueSoon.row"
                        ),
                        isOn: Binding(
                            get: { viewModel.preferences.dueSoonEnabled },
                            set: {
                                viewModel.togglePreference(\.dueSoonEnabled, value: $0)
                                if $0 == false, expandedNotificationRow == .dueSoon {
                                    expandedNotificationRow = nil
                                }
                            }
                        ),
                        isExpanded: notificationExpansionBinding(for: .dueSoon)
                    ) {
                        if viewModel.preferences.dueSoonEnabled {
                            SettingsChipSelector(
                                title: "Lead time",
                                options: dueSoonLeadOptions,
                                selectedValue: viewModel.preferences.dueSoonLeadMinutes,
                                onSelect: { viewModel.updateDueSoonLeadMinutes($0) },
                                accessibilityIdentifier: "settings.notifications.dueSoon.leadTime"
                            )
                        }
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                SettingsCard {
                    SettingsToggleRow(
                        iconName: "exclamationmark.triangle.fill",
                        title: "Tasks from earlier",
                        subtitle: nil,
                        isOn: Binding(
                            get: { viewModel.preferences.overdueNudgesEnabled },
                            set: { viewModel.togglePreference(\.overdueNudgesEnabled, value: $0) }
                        ),
                        tone: .warning,
                        accessibilityIdentifier: "settings.notifications.overdue.row"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)

                SettingsCard {
                    SettingsToggleSummaryRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "sunrise.fill",
                            title: "Morning agenda",
                            subtitle: "",
                            rowType: .toggleSummary,
                            summaryText: viewModel.morningAgendaSummary,
                            tone: .warning,
                            accessibilityIdentifier: "settings.notifications.morningAgenda.row"
                        ),
                        isOn: Binding(
                            get: { viewModel.preferences.morningAgendaEnabled },
                            set: { viewModel.togglePreference(\.morningAgendaEnabled, value: $0) }
                        ),
                        isExpanded: notificationExpansionBinding(for: .morning)
                    ) {
                        summaryTimePicker(
                            label: "Time",
                            selection: Binding(
                                get: { viewModel.morningTime },
                                set: { viewModel.morningTime = $0 }
                            )
                        )
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 3)

                SettingsCard {
                    SettingsToggleSummaryRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "moon.stars.fill",
                            title: "Close the day",
                            subtitle: "",
                            rowType: .toggleSummary,
                            summaryText: viewModel.nightlyRetrospectiveSummary,
                            tone: .accent,
                            accessibilityIdentifier: "settings.notifications.nightly.row"
                        ),
                        isOn: Binding(
                            get: { viewModel.preferences.nightlyRetrospectiveEnabled },
                            set: { viewModel.togglePreference(\.nightlyRetrospectiveEnabled, value: $0) }
                        ),
                        isExpanded: notificationExpansionBinding(for: .nightly)
                    ) {
                        summaryTimePicker(
                            label: "Time",
                            selection: Binding(
                                get: { viewModel.nightlyTime },
                                set: { viewModel.nightlyTime = $0 }
                            )
                        )
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 4)

                SettingsCard {
                    SettingsToggleSummaryRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "moon.zzz.fill",
                            title: "Quiet hours",
                            subtitle: "",
                            rowType: .toggleSummary,
                            summaryText: viewModel.quietHoursSummary,
                            tone: .neutral,
                            accessibilityIdentifier: "settings.notifications.quietHours.row"
                        ),
                        isOn: Binding(
                            get: { viewModel.preferences.quietHoursEnabled },
                            set: { viewModel.togglePreference(\.quietHoursEnabled, value: $0) }
                        ),
                        isExpanded: notificationExpansionBinding(for: .quietHours)
                    ) {
                        quietHoursControls
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 5)
            }
        }
    }

    private func appearanceSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Appearance",
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard {
                    SettingsToggleRow(
                        iconName: "sparkles",
                        title: "Button shimmer",
                        subtitle: nil,
                        isOn: Binding(
                            get: { viewModel.decorativeButtonEffectsEnabled },
                            set: { viewModel.setDecorativeButtonEffectsEnabled($0) }
                        ),
                        accessibilityIdentifier: "settings.appearance.decorativeButtonEffects.toggle"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)
                .accessibilityIdentifier("settings.appearance.decorativeButtonEffects.card")
            }
        }
    }

    /// Data ownership and recovery.
    ///
    /// Placed above Help rather than inside it because "is my work safe?" is not
    /// a support question — someone who suspects data loss should not have to
    /// look under "About" to find out.
    private func dataSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Data",
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "lifepreserver.fill",
                            title: "Recovery",
                            subtitle: "Sync, search and diagnostics",
                            trailingStatus: recoveryStatus.worstHealth == .healthy ? "Ready" : "Review",
                            tone: recoveryStatus.worstHealth == .healthy ? .success : .warning,
                            accessibilityIdentifier: "settings.recoveryCenterRow"
                        ),
                        action: { navigate(.recovery) }
                    )
                }
                ProductTelemetrySettingsCard(isEnabled: $productTelemetryEnabled)
            }
            .enhancedStaggeredAppearance(index: baseIndex)
        }
    }

    private func summaryTimePicker(label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: spacing.s12) {
            Text(label)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))

            Spacer()

            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.lifeboard(.accentPrimary))
        }
    }

    private var timelineRiseAndShineDraftSummary: String {
        formattedTimelineSummary(for: .wake)
    }

    private var timelineWindDownDraftSummary: String {
        formattedTimelineSummary(for: .windDown)
    }

    private func formattedTimelineSummary(for selection: TimelineAnchorSelection) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let time = formatter.string(from: timelineAnchorDraft.time(for: selection))
        guard selection == .windDown, timelineAnchorDraft.windDownOccursNextDay else {
            return time
        }
        return "\(time) next day"
    }

    private var quietHoursControls: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("Start")
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard(.textTertiary))

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.quietHoursStartTime },
                            set: { viewModel.quietHoursStartTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color.lifeboard(.accentPrimary))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: spacing.s4) {
                    Text("End")
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard(.textTertiary))

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { viewModel.quietHoursEndTime },
                            set: { viewModel.quietHoursEndTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Color.lifeboard(.accentPrimary))
                }
            }

            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Applies to")
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard(.textTertiary))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing.s8) {
                        Chip(
                            title: "Task alerts",
                            isSelected: viewModel.preferences.quietHoursAppliesToTaskAlerts,
                            selectedStyle: .tinted,
                            action: {
                                viewModel.togglePreference(
                                    \.quietHoursAppliesToTaskAlerts,
                                    value: !viewModel.preferences.quietHoursAppliesToTaskAlerts
                                )
                            }
                        )

                        Chip(
                            title: "Daily summaries",
                            isSelected: viewModel.preferences.quietHoursAppliesToDailySummaries,
                            selectedStyle: .tinted,
                            action: {
                                viewModel.togglePreference(
                                    \.quietHoursAppliesToDailySummaries,
                                    value: !viewModel.preferences.quietHoursAppliesToDailySummaries
                                )
                            }
                        )
                    }
                    .padding(.horizontal, 1)
                }

                if viewModel.preferences.quietHoursAppliesToTaskAlerts == false &&
                    viewModel.preferences.quietHoursAppliesToDailySummaries == false {
                    Text("Quiet hours don’t apply to any notifications yet.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func notificationExpansionBinding(for row: NotificationExpansion) -> Binding<Bool> {
        Binding(
            get: { expandedNotificationRow == row },
            set: { isExpanded in
                expandedNotificationRow = isExpanded ? row : nil
            }
        )
    }
}

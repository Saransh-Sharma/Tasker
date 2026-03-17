import SwiftUI

struct SettingsRootView: View {
    private enum NotificationExpansion: Hashable {
        case dueSoon
        case morning
        case nightly
        case quietHours
    }

    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.taskerLayoutClass) private var layoutClass
    @State private var expandedNotificationRow: NotificationExpansion?

    private let dueSoonLeadOptions: [(value: Int, label: String)] = [
        (15, "15m"),
        (30, "30m"),
        (45, "45m"),
        (60, "1h"),
        (90, "1.5h"),
        (120, "2h"),
    ]

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var isPadLayout: Bool {
        layoutClass.isPad
    }

    private var sectionTopPadding: CGFloat {
        TaskerSettingsMetrics.sectionSpacing
    }

    private var overviewStatusItems: [TaskerSettingsStatusDescriptor] {
        [
            TaskerSettingsStatusDescriptor(
                id: "notifications",
                title: "Notifications",
                value: viewModel.notificationEnabledSummary,
                systemImage: viewModel.isPermissionGranted ? "bell.badge.fill" : "bell.slash.fill",
                tone: viewModel.notificationTone
            ),
            TaskerSettingsStatusDescriptor(
                id: "model",
                title: "AI model",
                value: viewModel.aiAssistantSummary,
                systemImage: "brain.head.profile",
                tone: .accent
            ),
            TaskerSettingsStatusDescriptor(
                id: "setup",
                title: "Setup",
                value: viewModel.setupStatusLabel,
                systemImage: "slider.horizontal.3",
                tone: .neutral
            ),
        ]
    }

    var body: some View {
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
        .background(Color.tasker(.bgCanvas))
        .onAppear {
            viewModel.reload()
        }
    }

    private var overviewSection: some View {
        TaskerSettingsHeroCard(
            eyebrow: "Tasker Settings",
            title: "Tune your workspace",
            subtitle: "Manage reminders, AI, and workspace preferences in one place.",
            statusItems: overviewStatusItems,
            accessibilityIdentifier: "settings.hero.card"
        )
    }

    private var phoneSettingsBody: some View {
        VStack(spacing: 0) {
            workspaceSection(baseIndex: 1)
            aiAssistantSection(baseIndex: 3)
            notificationsSection(baseIndex: 5)
            appearanceSection(baseIndex: 12)
            helpSection(baseIndex: 14)
        }
    }

    private var iPadSettingsBody: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: spacing.sectionGap) {
                VStack(spacing: 0) {
                    workspaceSection(baseIndex: 1, includeHorizontalPadding: false)
                    aiAssistantSection(baseIndex: 3, includeHorizontalPadding: false)
                    appearanceSection(baseIndex: 12, includeHorizontalPadding: false)
                    helpSection(baseIndex: 14, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)

                VStack(spacing: 0) {
                    notificationsSection(baseIndex: 5, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, spacing.screenHorizontal)
        }
    }

    private func workspaceSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Workspace",
            subtitle: "Manage life areas, projects, and structure.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            TaskerSettingsCard {
                SettingsNavigationRow(
                    descriptor: TaskerSettingsDestinationDescriptor(
                        iconName: "square.grid.2x2.fill",
                        title: "Life Management",
                        subtitle: "Review life areas, projects, and daily structure.",
                        accessibilityIdentifier: "settings.workspace.lifeManagement.row"
                    ),
                    action: viewModel.onNavigateToLifeManagement
                )
            }
            .enhancedStaggeredAppearance(index: baseIndex)
        }
    }

    private func aiAssistantSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "AI Assistant",
            subtitle: "Configure models, memory, and privacy.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            TaskerSettingsCard(active: viewModel.memoryItemCount > 0) {
                SettingsNavigationRow(
                    descriptor: TaskerSettingsDestinationDescriptor(
                        iconName: "sparkles.rectangle.stack.fill",
                        title: "AI Assistant",
                        subtitle: "Manage chat behavior, models, memory, and privacy.",
                        trailingStatus: viewModel.aiAssistantSummary,
                        inlineBadge: viewModel.memoryItemCount == 0 ? TaskerSettingsInlineBadge(title: "Memory empty") : nil,
                        tone: .accent,
                        accessibilityIdentifier: "settings.aiAssistant.row"
                    ),
                    action: viewModel.onNavigateToAISettings
                )
            }
            .enhancedStaggeredAppearance(index: baseIndex)
        }
    }

    private func notificationsSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Notifications & Focus",
            subtitle: "Control reminders, summaries, and quiet hours.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                TaskerSettingsCard {
                    TaskerSettingsToggleRow(
                        iconName: "bell.badge.fill",
                        title: "Task Reminders",
                        subtitle: "Get alerts for scheduled tasks.",
                        isOn: Binding(
                            get: { viewModel.preferences.taskRemindersEnabled },
                            set: { viewModel.togglePreference(\.taskRemindersEnabled, value: $0) }
                        ),
                        accessibilityIdentifier: "settings.notifications.taskReminders.row"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                TaskerSettingsCard {
                    TaskerSettingsToggleSummaryRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "clock.badge.exclamationmark",
                            title: "Due Soon Nudges",
                            subtitle: "Remind me before a task is due.",
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

                TaskerSettingsCard {
                    TaskerSettingsToggleRow(
                        iconName: "exclamationmark.triangle.fill",
                        title: "Overdue Nudges",
                        subtitle: "Get reminders when tasks become overdue.",
                        isOn: Binding(
                            get: { viewModel.preferences.overdueNudgesEnabled },
                            set: { viewModel.togglePreference(\.overdueNudgesEnabled, value: $0) }
                        ),
                        tone: .warning,
                        accessibilityIdentifier: "settings.notifications.overdue.row"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)

                TaskerSettingsCard {
                    TaskerSettingsToggleSummaryRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "sunrise.fill",
                            title: "Morning Agenda",
                            subtitle: "Daily planning summary.",
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

                TaskerSettingsCard {
                    TaskerSettingsToggleSummaryRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "moon.stars.fill",
                            title: "Nightly Retrospective",
                            subtitle: "End-of-day reflection summary.",
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

                TaskerSettingsCard {
                    TaskerSettingsToggleSummaryRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "moon.zzz.fill",
                            title: "Quiet Hours",
                            subtitle: "Pause notifications during selected hours.",
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
            subtitle: "Personalize visual polish and feedback.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            TaskerSettingsCard {
                TaskerSettingsToggleRow(
                    iconName: "sparkles",
                    title: "Decorative Button Effects",
                    subtitle: "Add visual accents to primary buttons.",
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

    private func helpSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Help & About",
            subtitle: "Replay setup and view app details.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                TaskerSettingsCard {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "arrow.clockwise.circle.fill",
                            title: "Guided Setup",
                            subtitle: "Replay onboarding any time.",
                            accessibilityIdentifier: "settings.onboarding.restartButton"
                        ),
                        action: viewModel.restartOnboarding
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                TaskerSettingsCard {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "info.circle.fill",
                            title: "App Version",
                            subtitle: "View version and build details.",
                            trailingStatus: "v\(viewModel.appVersion) (\(viewModel.buildNumber))",
                            tone: .neutral,
                            accessibilityIdentifier: "settings.appVersionRow"
                        ),
                        action: {}
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
            }
        }
    }

    private func summaryTimePicker(label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: spacing.s12) {
            Text(label)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))

            Spacer()

            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Color.tasker(.accentPrimary))
        }
    }

    private var quietHoursControls: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HStack(spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("Start")
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker(.textTertiary))

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
                    .tint(Color.tasker(.accentPrimary))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: spacing.s4) {
                    Text("End")
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker(.textTertiary))

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
                    .tint(Color.tasker(.accentPrimary))
                }
            }

            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Applies to")
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker(.textTertiary))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing.s8) {
                        TaskerChip(
                            title: "Task Alerts",
                            isSelected: viewModel.preferences.quietHoursAppliesToTaskAlerts,
                            selectedStyle: .tinted,
                            action: {
                                viewModel.togglePreference(
                                    \.quietHoursAppliesToTaskAlerts,
                                    value: !viewModel.preferences.quietHoursAppliesToTaskAlerts
                                )
                            }
                        )

                        TaskerChip(
                            title: "Daily Summaries",
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

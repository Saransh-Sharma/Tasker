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

    private let weekStartOptions: [(value: Weekday, label: String)] = Weekday.allCases.map {
        ($0, $0.displayTitle)
    }

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
            // baseIndex controls stagger ordering; gaps leave room for expanded card content.
            workspaceSection(baseIndex: 1)
            calendarSection(baseIndex: 4)
            timelineSection(baseIndex: 8)
            aiAssistantSection(baseIndex: 10)
            notificationsSection(baseIndex: 12)
            appearanceSection(baseIndex: 20)
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
                    timelineSection(baseIndex: 8, includeHorizontalPadding: false)
                    aiAssistantSection(baseIndex: 10, includeHorizontalPadding: false)
                    appearanceSection(baseIndex: 20, includeHorizontalPadding: false)
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

    private func workspaceSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Workspace",
            subtitle: "Manage life areas, projects, habits, and structure.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
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

                TaskerSettingsCard {
                    VStack(alignment: .leading, spacing: TaskerSettingsMetrics.cardInnerPadding) {
                        TaskerSettingsInfoRow(
                            iconName: "calendar",
                            title: "Start of week",
                            subtitle: "This sets when weekly planning rolls over and when upcoming-week planning appears.",
                            value: viewModel.weekStartsOnSummary,
                            accessibilityIdentifier: "settings.workspace.weekStart.row"
                        )

                        SettingsChipSelector(
                            title: "Week starts on",
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
            title: String(localized: "Calendar & Schedule"),
            subtitle: String(localized: "Read-only calendar context for Home, Today/Week agenda, and task-fit hints."),
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                TaskerSettingsCard(active: viewModel.calendarAuthorizationStatus.isAuthorizedForRead) {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
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

                TaskerSettingsCard {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "slider.horizontal.3",
                            title: String(localized: "Calendar selection"),
                            subtitle: viewModel.calendarAuthorizationStatus.isAuthorizedForRead
                                ? String(localized: "Choose calendars for Home and the schedule view.")
                                : String(localized: "Connect calendar access before selecting calendars."),
                            trailingStatus: viewModel.calendarStatusSummary,
                            tone: viewModel.calendarAuthorizationStatus.isAuthorizedForRead ? .accent : .warning,
                            accessibilityIdentifier: "settings.calendar.selection.row"
                        ),
                        action: viewModel.openCalendarChooser
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                TaskerSettingsCard {
                    VStack(spacing: TaskerSettingsMetrics.cardInnerPadding) {
                        TaskerSettingsToggleRow(
                            iconName: "person.crop.circle.badge.xmark",
                            title: String(localized: "Include declined events"),
                            subtitle: String(localized: "Show declined meetings in agenda and Home context."),
                            isOn: Binding(
                                get: { viewModel.includeDeclinedCalendarEvents },
                                set: { viewModel.setIncludeDeclinedCalendarEvents($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeDeclined.toggle"
                        )

                        Divider()

                        TaskerSettingsToggleRow(
                            iconName: "calendar.badge.exclamationmark",
                            title: String(localized: "Include canceled events"),
                            subtitle: String(localized: "Show canceled events in Home, schedule, and task-fit context."),
                            isOn: Binding(
                                get: { viewModel.includeCanceledCalendarEvents },
                                set: { viewModel.setIncludeCanceledCalendarEvents($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeCanceled.toggle"
                        )

                        Divider()

                        TaskerSettingsToggleRow(
                            iconName: "sun.max",
                            title: String(localized: "Include all-day events in agenda"),
                            subtitle: String(localized: "Show all-day events in Today/Week lists."),
                            isOn: Binding(
                                get: { viewModel.includeAllDayInAgenda },
                                set: { viewModel.setIncludeAllDayInAgenda($0) }
                            ),
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendar.includeAllDayAgenda.toggle"
                        )

                        Divider()

                        TaskerSettingsToggleRow(
                            iconName: "chart.bar.xaxis",
                            title: String(localized: "Include all-day events in busy strip"),
                            subtitle: String(localized: "Use all-day events when calculating compact busy blocks."),
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
            title: "AI Assistant",
            subtitle: "Configure models, memory, and privacy.",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
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

                TaskerSettingsCard {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "cpu.fill",
                            title: "Models",
                            subtitle: "Review installed models and choose Eva’s default runtime.",
                            trailingStatus: viewModel.modelsSummary,
                            tone: .accent,
                            accessibilityIdentifier: "settings.aiAssistant.models.row"
                        ),
                        action: viewModel.onNavigateToModels
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
            }
        }
    }

    private func timelineSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: String(localized: "Timeline"),
            subtitle: String(localized: "Control timeline calendar overlays and daily start/end anchors."),
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                TaskerSettingsCard {
                    TaskerSettingsToggleRow(
                        iconName: "calendar.badge.clock",
                        title: String(localized: "Show calendar events in timeline"),
                        subtitle: String(localized: "Affects Home timeline rows and weekly timeline markers. The calendar card stays unchanged."),
                        isOn: Binding(
                            get: { viewModel.showCalendarEventsInTimeline },
                            set: { viewModel.setShowCalendarEventsInTimeline($0) }
                        ),
                        tone: .neutral,
                        accessibilityIdentifier: "settings.timeline.showCalendarEvents.toggle"
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                TaskerSettingsFieldCard(
                    title: String(localized: "Timeline Anchors"),
                    subtitle: String(localized: "Set the start and wind-down times shown in your Home timeline."),
                    footer: String(localized: "If Wind Down is earlier than Rise & Shine, the timeline carries into the next day."),
                    accessibilityIdentifier: "settings.timeline.anchors.card"
                ) {
                    VStack(spacing: spacing.s12) {
                        HStack(spacing: spacing.s12) {
                            Text(String(localized: "Rise & Shine"))
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textSecondary))

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.timelineRiseAndShineTime },
                                    set: { viewModel.timelineRiseAndShineTime = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.tasker(.accentPrimary))
                            .accessibilityIdentifier("settings.timeline.riseAndShine.picker")
                            .accessibilityValue(viewModel.timelineRiseAndShineSummary)
                        }

                        HStack(spacing: spacing.s12) {
                            Text(String(localized: "Wind Down"))
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textSecondary))

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.timelineWindDownTime },
                                    set: { viewModel.timelineWindDownTime = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(Color.tasker(.accentPrimary))
                            .accessibilityIdentifier("settings.timeline.windDown.picker")
                            .accessibilityValue(viewModel.timelineWindDownSummary)
                        }
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
            }
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
            VStack(spacing: spacing.cardStackVertical) {
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

                TaskerSettingsFieldCard(
                    title: "Home Background Noise",
                    subtitle: "Add film grain above the animated home gradient.",
                    footer: "Use 0% to disable the grain overlay.",
                    accessibilityIdentifier: "settings.appearance.homeBackgroundNoise.card"
                ) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        HStack(spacing: spacing.s12) {
                            Text("Amount")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textSecondary))

                            Spacer()

                            Text("\(viewModel.homeBackdropNoiseAmount)%")
                                .font(.tasker(.bodyStrong))
                                .foregroundStyle(Color.tasker(.textPrimary))
                                .monospacedDigit()
                        }

                        Slider(
                            value: homeBackdropNoiseSliderBinding,
                            in: 0...100,
                            step: 1
                        )
                        .tint(Color.tasker(.accentPrimary))
                        .accessibilityIdentifier("settings.appearance.homeBackgroundNoise.slider")
                        .accessibilityLabel("Home Background Noise")
                        .accessibilityValue(Text("\(viewModel.homeBackdropNoiseAmount) percent"))
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)
                .accessibilityChildren {
                    Text("\(viewModel.homeBackdropNoiseAmount)%")
                        .accessibilityIdentifier("settings.appearance.homeBackgroundNoise.value")
                }
            }
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
                        action: {
                            #if os(iOS)
                            UIPasteboard.general.string = "v\(viewModel.appVersion) (\(viewModel.buildNumber))"
                            TaskerFeedback.selection()
                            #endif
                        }
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

    private var homeBackdropNoiseSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.homeBackdropNoiseAmount) },
            set: { viewModel.setHomeBackdropNoiseAmount(Int($0.rounded())) }
        )
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

                if viewModel.preferences.quietHoursAppliesToTaskAlerts == false &&
                    viewModel.preferences.quietHoursAppliesToDailySummaries == false {
                    Text("Quiet hours are enabled, but they do not currently apply to any notification type.")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
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

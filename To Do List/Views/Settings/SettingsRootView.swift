import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = TaskerThemeManager.shared
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var isPadLayout: Bool {
        layoutClass.isPad
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsProfileHeaderView(version: viewModel.appVersion)
                    .enhancedStaggeredAppearance(index: 0)
                    .padding(.top, spacing.s16)

                if isPadLayout {
                    iPadSettingsBody
                } else {
                    phoneSettingsBody
                }
            }
        }
        .background(Color.tasker(.bgCanvas))
        .onAppear {
            viewModel.reload()
        }
    }

    private var phoneSettingsBody: some View {
        VStack(spacing: 0) {
            workspaceSection(baseIndex: 1)
            notificationsSection(baseIndex: 6)
            SettingsFooterView(
                version: viewModel.appVersion,
                build: viewModel.buildNumber
            )
            .enhancedStaggeredAppearance(index: 12)
        }
    }

    private var iPadSettingsBody: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: spacing.sectionGap) {
                VStack(spacing: 0) {
                    workspaceSection(baseIndex: 1, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 520, alignment: .top)

                VStack(spacing: 0) {
                    notificationsSection(baseIndex: 6, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 520, alignment: .top)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, spacing.screenHorizontal)

            keyboardShortcutsSection
                .padding(.horizontal, spacing.screenHorizontal)

            SettingsFooterView(
                version: viewModel.appVersion,
                build: viewModel.buildNumber
            )
            .padding(.top, spacing.sectionGap)
            .enhancedStaggeredAppearance(index: 14)
        }
    }

    private var keyboardShortcutsSection: some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(title: "Keyboard Shortcuts")
                .enhancedStaggeredAppearance(index: 12)
                .padding(.top, spacing.sectionGap)

            KeyboardShortcutsCard()
                .enhancedStaggeredAppearance(index: 13)
                .padding(.top, spacing.s12)
                .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private func workspaceSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(title: "Your Workspace")
                .enhancedStaggeredAppearance(index: baseIndex)
                .padding(.top, spacing.sectionGap)

            VStack(spacing: spacing.cardStackVertical) {
                TaskerCard {
                    SettingsNavigationRow(
                        iconName: "square.grid.2x2.fill",
                        title: "Life Management",
                        action: viewModel.onNavigateToLifeManagement
                    )
                }
                .cardPressEffect()
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                TaskerCard {
                    VStack(spacing: 0) {
                        SettingsNavigationRow(
                            iconName: "message.fill",
                            title: "Chats",
                            action: viewModel.onNavigateToChats
                        )

                        Divider()
                            .background(Color.tasker.strokeHairline)

                        SettingsNavigationRow(
                            iconName: "brain.filled.head.profile",
                            title: "Models",
                            detailText: viewModel.currentModelDisplayName,
                            action: viewModel.onNavigateToModels
                        )
                    }
                }
                .cardPressEffect()
                .enhancedStaggeredAppearance(index: baseIndex + 2)

                onboardingReplayCard
                    .enhancedStaggeredAppearance(index: baseIndex + 3)
            }
            .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
            .padding(.top, spacing.s12)
        }
    }

    private var onboardingReplayCard: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    Image(systemName: "sparkles")
                        .font(.tasker(.sectionTitle))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Guided Setup")
                            .font(.tasker(.headline))
                            .foregroundColor(Color.tasker.textPrimary)
                        Text("Replay onboarding any time to rebuild momentum using your real workspace.")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(action: viewModel.restartOnboarding) {
                    Text("Restart onboarding")
                        .font(.tasker(.buttonSmall))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, spacing.s8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.onboarding.restartButton")
            }
            .padding(spacing.s16)
        }
        .accessibilityIdentifier("settings.onboarding.card")
    }

    private func notificationsSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(title: "Notifications & Focus")
                .enhancedStaggeredAppearance(index: baseIndex)
                .padding(.top, spacing.sectionGap)

            VStack(spacing: spacing.cardStackVertical) {
                if viewModel.showPermissionBanner {
                    NotificationPermissionBanner(
                        status: viewModel.permissionStatus,
                        onAction: { viewModel.requestNotificationPermission() }
                    )
                    .enhancedStaggeredAppearance(index: baseIndex + 1)
                }

                NotificationTypesCard(viewModel: viewModel)
                    .enhancedStaggeredAppearance(index: baseIndex + 2)

                DailyRitualsCard(viewModel: viewModel)
                    .enhancedStaggeredAppearance(index: baseIndex + 3)

                DueSoonLeadTimeCard(viewModel: viewModel)
                    .enhancedStaggeredAppearance(index: baseIndex + 4)

                QuietHoursCard(viewModel: viewModel)
                    .enhancedStaggeredAppearance(index: baseIndex + 5)
            }
            .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
            .padding(.top, spacing.s12)
        }
    }
}

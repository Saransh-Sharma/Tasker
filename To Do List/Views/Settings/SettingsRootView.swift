import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = TaskerThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Profile Header
                SettingsProfileHeaderView(version: viewModel.appVersion)
                    .enhancedStaggeredAppearance(index: 0)
                    .padding(.top, TaskerSwiftUITokens.spacing.s16)

                // MARK: - Section 1: Your Workspace
                SettingsSectionHeader(title: "Your Workspace")
                    .enhancedStaggeredAppearance(index: 1)
                    .padding(.top, TaskerSwiftUITokens.spacing.sectionGap)

                VStack(spacing: TaskerSwiftUITokens.spacing.cardStackVertical) {

                    // Appearance (Dark Mode + Theme Gallery)
                    AppearanceCardView(
                        isDarkMode: $viewModel.isDarkMode,
                        onToggleDarkMode: { viewModel.toggleDarkMode($0) }
                    )
                    .enhancedStaggeredAppearance(index: 2)

                    // Projects
                    TaskerCard {
                        SettingsNavigationRow(
                            iconName: "folder.fill",
                            title: "Projects",
                            action: viewModel.onNavigateToProjects
                        )
                    }
                    .cardPressEffect()
                    .enhancedStaggeredAppearance(index: 3)

                    // AI Assistant
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
                    .enhancedStaggeredAppearance(index: 4)
                }
                .padding(.horizontal, TaskerSwiftUITokens.spacing.screenHorizontal)
                .padding(.top, TaskerSwiftUITokens.spacing.s12)

                // MARK: - Section 2: Notifications & Focus
                SettingsSectionHeader(title: "Notifications & Focus")
                    .enhancedStaggeredAppearance(index: 5)
                    .padding(.top, TaskerSwiftUITokens.spacing.sectionGap)

                VStack(spacing: TaskerSwiftUITokens.spacing.cardStackVertical) {

                    // Permission banner (conditional)
                    if viewModel.showPermissionBanner {
                        NotificationPermissionBanner(
                            status: viewModel.permissionStatus,
                            onAction: { viewModel.requestNotificationPermission() }
                        )
                        .enhancedStaggeredAppearance(index: 6)
                    }

                    // Alert Types
                    NotificationTypesCard(viewModel: viewModel)
                        .enhancedStaggeredAppearance(index: 7)

                    // Daily Rituals
                    DailyRitualsCard(viewModel: viewModel)
                        .enhancedStaggeredAppearance(index: 8)

                    // Due Soon Lead Time
                    DueSoonLeadTimeCard(viewModel: viewModel)
                        .enhancedStaggeredAppearance(index: 9)

                    // Quiet Hours
                    QuietHoursCard(viewModel: viewModel)
                        .enhancedStaggeredAppearance(index: 10)
                }
                .padding(.horizontal, TaskerSwiftUITokens.spacing.screenHorizontal)
                .padding(.top, TaskerSwiftUITokens.spacing.s12)

                // MARK: - Footer
                SettingsFooterView(
                    version: viewModel.appVersion,
                    build: viewModel.buildNumber
                )
                .enhancedStaggeredAppearance(index: 11)
            }
        }
        .background(Color.tasker(.bgCanvas))
        .onAppear {
            viewModel.reload()
        }
    }
}

import SwiftUI

struct HomeCompactHeaderView: View {
    let dateText: String
    let summaryText: String
    let selectedQuickView: HomeQuickView
    let taskCounts: [HomeQuickView: Int]
    let showsBackToToday: Bool
    let extraTopPadding: CGFloat
    let reduceMotion: Bool
    let onSelectQuickView: (HomeQuickView) -> Void
    let onBackToToday: () -> Void
    let onShowDatePicker: () -> Void
    let onShowAdvancedFilters: () -> Void
    let onResetFilters: () -> Void
    let onOpenSearch: () -> Void
    let onOpenSettings: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        dateText: String,
        summaryText: String,
        selectedQuickView: HomeQuickView,
        taskCounts: [HomeQuickView: Int],
        showsBackToToday: Bool,
        extraTopPadding: CGFloat = 0,
        reduceMotion: Bool,
        onSelectQuickView: @escaping (HomeQuickView) -> Void,
        onBackToToday: @escaping () -> Void,
        onShowDatePicker: @escaping () -> Void,
        onShowAdvancedFilters: @escaping () -> Void,
        onResetFilters: @escaping () -> Void,
        onOpenSearch: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.dateText = dateText
        self.summaryText = summaryText
        self.selectedQuickView = selectedQuickView
        self.taskCounts = taskCounts
        self.showsBackToToday = showsBackToToday
        self.extraTopPadding = extraTopPadding
        self.reduceMotion = reduceMotion
        self.onSelectQuickView = onSelectQuickView
        self.onBackToToday = onBackToToday
        self.onShowDatePicker = onShowDatePicker
        self.onShowAdvancedFilters = onShowAdvancedFilters
        self.onResetFilters = onResetFilters
        self.onOpenSearch = onOpenSearch
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        Group {
            if showsBackToToday {
                ViewThatFits(in: .horizontal) {
                    inlineHeaderLayout(backButtonStyle: .label)
                    inlineHeaderLayout(backButtonStyle: .iconOnly)
                    if dynamicTypeSize.isAccessibilitySize {
                        stackedHeaderLayout(backButtonStyle: .iconOnly)
                    }
                }
            } else {
                inlineHeaderLayout(backButtonStyle: nil)
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s8 + 10 + extraTopPadding)
        .padding(.bottom, spacing.s8)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.2), value: showsBackToToday)
    }

    @ViewBuilder
    private func inlineHeaderLayout(backButtonStyle: HomeBackToTodayButtonView.DisplayStyle?) -> some View {
        HStack(spacing: spacing.s8) {
            scopeMenu
                .layoutPriority(1)

            if let backButtonStyle {
                HomeBackToTodayButtonView(displayStyle: backButtonStyle, action: onBackToToday)
                    .transition(backToTodayTransition)
                    .fixedSize(horizontal: true, vertical: true)
            }

            settingsButton
                .fixedSize()
        }
    }

    @ViewBuilder
    private func stackedHeaderLayout(backButtonStyle: HomeBackToTodayButtonView.DisplayStyle) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                scopeMenu
                    .layoutPriority(1)
                settingsButton
                    .fixedSize()
            }

            HStack {
                Spacer(minLength: 0)

                HomeBackToTodayButtonView(displayStyle: backButtonStyle, action: onBackToToday)
                    .transition(backToTodayTransition)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
    }

    private var scopeMenu: some View {
        Menu {
            Section("View") {
                ForEach(HomeQuickView.allCases, id: \.rawValue) { quickView in
                    Button {
                        onSelectQuickView(quickView)
                        TaskerFeedback.selection()
                    } label: {
                        HStack {
                            Label(quickView.title, systemImage: iconName(for: quickView))
                            Spacer()
                            if let count = taskCounts[quickView] {
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                            if selectedQuickView == quickView {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityIdentifier("home.focus.menu.option.\(quickView.rawValue)")
                }
            }

            Section("Actions") {
                Button("Search", systemImage: "magnifyingglass", action: onOpenSearch)
                    .accessibilityIdentifier("home.focus.menu.search")

                Button("Select date", systemImage: "calendar", action: onShowDatePicker)
                    .accessibilityIdentifier("home.focus.menu.datePicker")

                Button("Advanced filters", systemImage: "slider.horizontal.3", action: onShowAdvancedFilters)
                    .accessibilityIdentifier("home.focus.menu.advanced")

                Button(role: .destructive, action: onResetFilters) {
                    Label("Reset filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityIdentifier("home.focus.menu.reset")
            }
        } label: {
            HomeScopeSummaryButtonView(
                dateText: dateText,
                summaryText: summaryText
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("home.focus.menu.button")
        .accessibilityLabel("Date and scope. \(dateText). \(summaryText)")
        .accessibilityHint("Opens home view and filter options")
    }

    private var settingsButton: some View {
        Button("Settings", systemImage: "gearshape", action: onOpenSettings)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: 44, height: 44)
            .taskerChromeSurface(
                cornerRadius: 22,
                accentColor: Color.tasker.accentSecondary,
                level: .e1
            )
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens settings")
            .accessibilityIdentifier("home.settingsButton")
    }

    private var backToTodayTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private func iconName(for quickView: HomeQuickView) -> String {
        switch quickView {
        case .today: return "sun.max.fill"
        case .upcoming: return "calendar.badge.clock"
        case .overdue: return "flame.fill"
        case .done: return "checkmark.circle.fill"
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

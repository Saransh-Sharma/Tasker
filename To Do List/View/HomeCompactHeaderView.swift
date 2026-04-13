import SwiftUI

struct HomeCompactHeaderView: View {
    let presentation: HomeHeaderPresentationModel
    let selectedQuickView: HomeQuickView
    let taskCounts: [HomeQuickView: Int]
    let extraTopPadding: CGFloat
    let reduceMotion: Bool
    let onSelectQuickView: (HomeQuickView) -> Void
    let onBackToToday: () -> Void
    let onShowDatePicker: () -> Void
    let onShowAdvancedFilters: () -> Void
    let onResetFilters: () -> Void
    let onOpenSearch: () -> Void
    let onOpenReflection: () -> Void
    let onOpenSettings: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var containerWidth: CGFloat = 0
    @State private var measuredLeadingColumnWidth: CGFloat = 0
    @State private var measuredTrailingColumnWidth: CGFloat = 0

    init(
        presentation: HomeHeaderPresentationModel,
        selectedQuickView: HomeQuickView,
        taskCounts: [HomeQuickView: Int],
        extraTopPadding: CGFloat = 0,
        reduceMotion: Bool,
        onSelectQuickView: @escaping (HomeQuickView) -> Void,
        onBackToToday: @escaping () -> Void,
        onShowDatePicker: @escaping () -> Void,
        onShowAdvancedFilters: @escaping () -> Void,
        onResetFilters: @escaping () -> Void,
        onOpenSearch: @escaping () -> Void,
        onOpenReflection: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.selectedQuickView = selectedQuickView
        self.taskCounts = taskCounts
        self.extraTopPadding = extraTopPadding
        self.reduceMotion = reduceMotion
        self.onSelectQuickView = onSelectQuickView
        self.onBackToToday = onBackToToday
        self.onShowDatePicker = onShowDatePicker
        self.onShowAdvancedFilters = onShowAdvancedFilters
        self.onResetFilters = onResetFilters
        self.onOpenSearch = onOpenSearch
        self.onOpenReflection = onOpenReflection
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            headerTopRow
            utilityRow
            headerBottomAccent
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s8 + extraTopPadding)
        .padding(.bottom, spacing.s8)
        .contentShape(Rectangle())
        .accessibilityIdentifier("home.topChrome")
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            containerWidth = newWidth
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.22), value: presentation.showsBackToToday)
    }

    @ViewBuilder
    private var headerBottomAccent: some View {
        if let xpProgress = presentation.xpProgress {
            HomeMomentumProgressBar(
                progress: xpProgress.progressFraction,
                colors: xpProgress.isStreakSafeToday
                    ? [Color.tasker.accentPrimary.opacity(0.78), Color.tasker.accentPrimary]
                    : [Color.tasker.statusWarning.opacity(0.82), Color.tasker.statusWarning],
                trackColor: Color.tasker.surfaceSecondary.opacity(0.72),
                height: 3,
                animate: !reduceMotion
            )
            .frame(maxWidth: .infinity)
            .frame(height: 3)
            .accessibilityElement()
            .accessibilityLabel(xpProgress.accessibilityLabel)
            .accessibilityIdentifier("home.topChrome.xpProgress")
        } else {
            Rectangle()
                .fill(Color.tasker.divider.opacity(0.88))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private var canCenterDate: Bool {
        presentation.backgroundDateText != nil
            && presentation.foregroundRelativeLabel != nil
            && containerWidth >= 360
            && !dynamicTypeSize.isAccessibilitySize
    }

    private var headerTopRow: some View {
        Group {
            if canCenterDate {
                ZStack {
                    layeredDateLabel
                        .padding(.horizontal, dateHeroHorizontalInset)
                        .offset(y: 10)

                    HStack(alignment: .center, spacing: spacing.s8) {
                        leadingHeaderContent
                            .fixedSize(horizontal: true, vertical: true)
                            .background(
                                widthReader { newWidth in
                                    measuredLeadingColumnWidth = newWidth
                                }
                            )

                        Spacer(minLength: spacing.s8)

                        trailingHeaderContent
                            .fixedSize(horizontal: true, vertical: true)
                            .background(
                                widthReader { newWidth in
                                    measuredTrailingColumnWidth = newWidth
                                }
                            )
                    }
                }
                .frame(minHeight: 36)
            } else {
                HStack(spacing: spacing.s8) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        leadingHeaderContent
                            .layoutPriority(1)

                        if let dateText = presentation.compactDateText {
                            Text(dateText)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker.textSecondary)
                                .lineLimit(1)
                                .accessibilityLabel(presentation.dateAccessibilityLabel ?? dateText)
                                .accessibilityIdentifier("home.topChrome.date")
                        }
                    }

                    Spacer(minLength: spacing.s4)

                    trailingHeaderContent
                }
            }
        }
    }

    @ViewBuilder
    private var utilityRow: some View {
        if presentation.showsReflectionCTA || presentation.statusText != nil || presentation.todayStatus != nil {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: spacing.s8) {
                    if presentation.showsReflectionCTA {
                        reflectionButton
                    }
                    Spacer(minLength: spacing.s8)
                    statusContent
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    if presentation.showsReflectionCTA {
                        reflectionButton
                    }
                    statusContent
                }
            }
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        if let todayStatus = presentation.todayStatus {
            HStack(spacing: spacing.s4) {
                Text(todayStatus.xpText)
                    .foregroundStyle(Color.tasker.textSecondary)

                Text("·")
                    .foregroundStyle(Color.tasker.textTertiary)

                Text(todayStatus.completionText)
                    .foregroundStyle(Color.tasker.textSecondary)

                Text("·")
                    .foregroundStyle(Color.tasker.textTertiary)

                HStack(spacing: spacing.s4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.tasker.statusWarning)
                        .accessibilityHidden(true)

                    Text(todayStatus.streakText)
                        .foregroundStyle(Color.tasker.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(todayStatus.streakAccessibilityLabel)
            }
            .font(.tasker(.caption1))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(todayStatus.accessibilityLabel)
            .accessibilityIdentifier("home.topChrome.status")
        } else if let statusText = presentation.statusText {
            Text(statusText)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityIdentifier("home.topChrome.status")
        }
    }

    private var layeredDateLabel: some View {
        ZStack {
            Text(presentation.backgroundDateText ?? "")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .tracking(-0.4)
                .foregroundStyle(watermarkDateColor)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .offset(y: -5)

            Text(presentation.foregroundRelativeLabel ?? "")
                .font(.system(size: 19, weight: .bold))
                .tracking(2.8)
                .foregroundStyle(foregroundDateColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .clipped()
        .contentShape(Rectangle())
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            presentation.dateAccessibilityLabel
                ?? presentation.compactDateText
                ?? ""
        )
        .allowsHitTesting(false)
        .accessibilityIdentifier("home.topChrome.date")
    }

    private var watermarkDateColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.29, green: 0.33, blue: 0.41).opacity(0.24)
        default:
            return Color(red: 0.40, green: 0.45, blue: 0.55).opacity(0.14)
        }
    }

    private var foregroundDateColor: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(0.98)
        default:
            return Color.tasker.textPrimary.opacity(0.94)
        }
    }

    private var dateHeroHorizontalInset: CGFloat {
        max(
            92,
            max(measuredLeadingColumnWidth, measuredTrailingColumnWidth) + spacing.s12
        )
    }

    private func widthReader(_ action: @escaping (CGFloat) -> Void) -> some View {
        Color.clear
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                guard newWidth > 0 else { return }
                action(newWidth)
            }
    }

    private var leadingHeaderContent: some View {
        HStack(spacing: spacing.s8) {
            if presentation.showsBackToToday {
                HomeBackToTodayButtonView(action: onBackToToday)
                    .fixedSize(horizontal: true, vertical: true)
            }

            scopeMenu
                .layoutPriority(1)
        }
    }

    private var trailingHeaderContent: some View {
        HStack(spacing: spacing.s8) {
            searchButton
                .fixedSize()
            settingsButton
                .fixedSize()
        }
    }

    private var reflectionButton: some View {
        Button {
            TaskerFeedback.selection()
            onOpenReflection()
        } label: {
            Text(presentation.reflectionCTATitle)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.statusWarning)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel("Reflect")
        .accessibilityHint("Opens the daily reflection screen")
        .accessibilityIdentifier("home.reflectionReady.button")
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

            Section("Tools") {
                Button("Search", systemImage: "magnifyingglass", action: onOpenSearch)
                    .accessibilityIdentifier("home.focus.menu.search")

                Button("Pick date", systemImage: "calendar", action: onShowDatePicker)
                    .accessibilityIdentifier("home.focus.menu.datePicker")

                Button("More filters", systemImage: "slider.horizontal.3", action: onShowAdvancedFilters)
                    .accessibilityIdentifier("home.focus.menu.advanced")

                Button(role: .destructive, action: onResetFilters) {
                    Label("Reset", systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityIdentifier("home.focus.menu.reset")
            }
        } label: {
            HomeScopeSummaryButtonView(
                viewLabel: presentation.viewLabel,
                accentColor: selectionTint,
                hasActiveFilters: presentation.hasActiveFilters
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("home.focus.menu.button")
        .accessibilityLabel(scopeMenuAccessibilityLabel)
        .accessibilityHint("Opens quick views and tools")
    }

    private var settingsButton: some View {
        Button("Settings", systemImage: "gearshape", action: onOpenSettings)
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.6), lineWidth: 1)
            )
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens settings")
            .accessibilityIdentifier("home.settingsButton")
    }

    private var searchButton: some View {
        Button("Search", systemImage: "magnifyingglass", action: onOpenSearch)
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.6), lineWidth: 1)
            )
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("Search")
            .accessibilityHint("Opens search")
            .accessibilityIdentifier("home.topNav.searchButton")
    }

    private var scopeMenuAccessibilityLabel: String {
        if presentation.hasActiveFilters {
            return "Current view, \(presentation.viewLabel), filters active"
        }
        return "Current view, \(presentation.viewLabel)"
    }

    private var selectionTint: Color {
        switch selectedQuickView {
        case .overdue:
            return Color.tasker.statusWarning
        case .done:
            return Color.tasker.statusSuccess
        case .morning:
            return Color.tasker.accentPrimary
        case .evening:
            return Color.tasker.accentSecondary
        case .today, .upcoming:
            return Color.tasker.accentPrimary
        }
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

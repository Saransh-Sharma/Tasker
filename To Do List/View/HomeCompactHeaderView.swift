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
            if usesWideLayout {
                wideHeaderLayout
            } else {
                compactHeaderLayout
            }

            headerBottomAccent
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s8 + 10 + extraTopPadding)
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
            ZStack {
                HomeMomentumProgressBar(
                    progress: xpProgress.progressFraction,
                    colors: xpProgress.isStreakSafeToday
                        ? [Color.tasker.accentPrimary.opacity(0.78), Color.tasker.accentPrimary]
                        : [Color.tasker.statusWarning.opacity(0.82), Color.tasker.statusWarning],
                    trackColor: Color.tasker.surfaceSecondary.opacity(0.72),
                    height: 4,
                    animate: !reduceMotion
                )

                Text(xpProgress.accessibilityLabel)
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .clipped()
                    .accessibilityIdentifier("home.topChrome.xpProgress")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 4)
        } else {
            Rectangle()
                .fill(Color.tasker.divider.opacity(0.88))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private var usesWideLayout: Bool {
        containerWidth >= 700 && !dynamicTypeSize.isAccessibilitySize
    }

    private var compactHeaderLayout: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            headerTopRow

            metadataSection(alignment: .leading)
        }
    }

    private var wideHeaderLayout: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            headerTopRow

            metadataSection(alignment: .leading)
        }
    }

    private var headerTopRow: some View {
        Group {
            if presentation.centeredDateText == nil {
                HStack(spacing: spacing.s8) {
                    leadingHeaderContent
                        .background(
                            widthReader { newWidth in
                                measuredLeadingColumnWidth = newWidth
                            }
                        )
                        .layoutPriority(1)

                    Spacer(minLength: spacing.s4)

                    trailingHeaderContent
                }
            } else {
                HStack(alignment: .center, spacing: spacing.s8) {
                    leadingMeasuredHeaderContent
                        .background(
                            widthReader { newWidth in
                                measuredLeadingColumnWidth = newWidth
                            }
                        )
                        .frame(width: balancedSideColumnWidth, alignment: .leading)

                    centeredDateLabel
                        .frame(maxWidth: .infinity, alignment: .center)
                        .layoutPriority(1)

                    trailingMeasuredHeaderContent
                        .background(
                            widthReader { newWidth in
                                measuredTrailingColumnWidth = newWidth
                            }
                        )
                        .frame(width: balancedSideColumnWidth, alignment: .trailing)
                }
            }
        }
        .onChange(of: presentation.centeredDateText != nil) { _, _ in
            resetMeasuredColumnWidths()
        }
        .onChange(of: usesWideLayout) { _, _ in
            resetMeasuredColumnWidths()
        }
    }

    @ViewBuilder
    private func metadataSection(alignment: HorizontalAlignment) -> some View {
        ViewThatFits(in: .horizontal) {
            if presentation.showsReflectionCTA {
                HStack(alignment: .center, spacing: spacing.s8) {
                    reflectionButtonRail
                    metadataItemsRow(alignment: .trailing)
                }
            } else {
                metadataItemsRow(alignment: .leading)
            }

            VStack(alignment: alignment, spacing: spacing.s8) {
                if presentation.showsReflectionCTA {
                    reflectionButtonRail
                }
                metadataItemsRow(alignment: presentation.showsReflectionCTA ? .trailing : .leading)
            }
        }
    }

    private func metadataItemsRow(alignment: Alignment) -> some View {
        HStack(alignment: .center, spacing: spacing.s8) {
            ForEach(Array(presentation.metadataItems.enumerated()), id: \.element.id) { index, item in
                metadataItemView(item)

                if index < presentation.metadataItems.count - 1 {
                    Text("·")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textQuaternary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .accessibilityElement(children: .combine)
    }

    private func metadataItemView(_ item: HomeHeaderMetadataItem) -> some View {
        HStack(spacing: spacing.s4) {
            if let iconSystemName = item.iconSystemName {
                Image(systemName: iconSystemName)
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(item.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.tasker(.caption1).weight(.medium))
        .foregroundStyle(metadataForegroundColor(for: item))
        .fixedSize(horizontal: true, vertical: false)
    }

    private var centeredDateLabel: some View {
        Text(presentation.centeredDateText ?? "")
            .font(.tasker(.display))
            .foregroundStyle(Color.tasker.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("home.topChrome.date")
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
        settingsButton
            .fixedSize()
    }

    private var leadingMeasuredHeaderContent: some View {
        leadingHeaderContent
            .fixedSize(horizontal: true, vertical: false)
    }

    private var trailingMeasuredHeaderContent: some View {
        trailingHeaderContent
            .fixedSize(horizontal: true, vertical: false)
    }

    private var reflectionButton: some View {
        Button {
            TaskerFeedback.selection()
            onOpenReflection()
        } label: {
            HStack(spacing: spacing.s4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))

                Text(presentation.reflectionCTATitle)
                    .font(.tasker(.caption1).weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.tasker.statusWarning)
            .padding(.horizontal, spacing.s12)
            .frame(minHeight: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.tasker.statusWarning.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.tasker.statusWarning.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel("Reflect")
        .accessibilityHint("Opens the daily reflection screen")
        .accessibilityIdentifier("home.reflectionReady.button")
    }

    @ViewBuilder
    private var reflectionButtonRail: some View {
        if let reflectionRailWidth {
            reflectionButton
                .frame(width: reflectionRailWidth, alignment: .center)
        } else {
            reflectionButton
                .fixedSize(horizontal: true, vertical: false)
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
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.focus.menu.button")
            .accessibilityLabel(scopeMenuAccessibilityLabel)
            .accessibilityHint("Opens quick views and tools")
            .accessibilityAddTraits(.isButton)
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("home.focus.menu.button")
        .accessibilityLabel(scopeMenuAccessibilityLabel)
        .accessibilityHint("Opens quick views and tools")
    }

    private var settingsButton: some View {
        Button("Settings", systemImage: "gearshape", action: onOpenSettings)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color.tasker.surfaceSecondary.opacity(0.92))
            )
            .overlay(
                Circle()
                    .stroke(Color.tasker.strokeHairline.opacity(0.75), lineWidth: 1)
            )
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens settings")
            .accessibilityIdentifier("home.settingsButton")
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

    private var balancedSideColumnWidth: CGFloat? {
        guard measuredLeadingColumnWidth > 0, measuredTrailingColumnWidth > 0 else {
            return nil
        }

        return max(measuredLeadingColumnWidth, measuredTrailingColumnWidth)
    }

    private var reflectionRailWidth: CGFloat? {
        guard presentation.showsReflectionCTA, measuredLeadingColumnWidth > 0 else {
            return nil
        }

        return measuredLeadingColumnWidth
    }

    private func resetMeasuredColumnWidths() {
        measuredLeadingColumnWidth = 0
        measuredTrailingColumnWidth = 0
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

    private func metadataToneColor(_ tone: HomeHeaderMetadataItem.Tone) -> Color {
        switch tone {
        case .neutral:
            return Color.tasker.textSecondary
        case .accent:
            return Color.tasker.accentSecondary
        case .success:
            return Color.tasker.statusSuccess
        case .warning:
            return Color.tasker.statusWarning
        }
    }

    private func metadataForegroundColor(for item: HomeHeaderMetadataItem) -> Color {
        if item.id == "xp" {
            return Color.tasker.statusWarning
        }
        if item.id == "completion" {
            return Color.white
        }
        return metadataToneColor(item.tone)
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

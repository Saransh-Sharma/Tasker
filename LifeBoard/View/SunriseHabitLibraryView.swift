import SwiftUI

private enum HabitLibraryFilter: String, CaseIterable, Identifiable {
    case active
    case paused
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .archived:
            return String(localized: "Archived", defaultValue: "Archived")
        }
    }

}
@MainActor
struct SunriseHabitLibraryView: View {
    enum PresentationStyle { case modal, pushed }

    @ObservedObject var viewModel: HabitLibraryViewModel
    let presentationStyle: PresentationStyle
    @State private var selectedRow: HabitLibraryRow?
    @State private var selectedFilter: HabitLibraryFilter = .active
    @State private var searchText = ""
    @State private var habitComposerPresented = false
    @StateObject private var habitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

    init(viewModel: HabitLibraryViewModel, presentationStyle: PresentationStyle = .modal) {
        self.viewModel = viewModel
        self.presentationStyle = presentationStyle
    }

    private var filteredRows: [HabitLibraryRow] {
        let baseRows: [HabitLibraryRow]
        switch selectedFilter {
        case .active:
            baseRows = viewModel.activeRows
        case .paused:
            baseRows = viewModel.pausedRows
        case .archived:
            baseRows = viewModel.archivedRows
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return baseRows }

        return baseRows.filter { row in
            row.title.lowercased().contains(query)
                || row.lifeAreaName.lowercased().contains(query)
                || (row.projectName?.lowercased().contains(query) ?? false)
                || trackingLabel(for: row).lowercased().contains(query)
        }
    }

    private var columns: [GridItem] {
        if layoutClass == .padRegular || layoutClass == .padExpanded {
            return [
                GridItem(.flexible(), spacing: spacing.s16),
                GridItem(.flexible(), spacing: spacing.s16)
            ]
        }
        return [GridItem(.flexible(), spacing: spacing.s12)]
    }

    var body: some View {
        Group {
            if presentationStyle == .modal {
                NavigationStack { libraryContent }
            } else {
                libraryContent
            }
        }
    }

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s16) {
                HabitLibrarySummaryHeader(
                    activeCount: viewModel.activeRows.count,
                    pausedCount: viewModel.pausedRows.count,
                    archivedCount: viewModel.archivedRows.count
                )
                .enhancedStaggeredAppearance(index: 0)

                HabitLibraryControlRail(
                    selectedFilter: $selectedFilter,
                    searchText: $searchText
                )
                .enhancedStaggeredAppearance(index: 1)

                content
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard.bgCanvas)
        .navigationTitle("Manage Habits")
        .toolbar {
            if presentationStyle == .modal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    presentHabitComposer()
                } label: {
                    Label("Add Habit", systemImage: "plus")
                }
                .accessibilityLabel("Add habit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Refresh habits")
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $selectedRow) { row in
            SunriseHabitDetailScreen(
                viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                onMutation: {
                    viewModel.refresh()
                }
            )
        }
        .sheet(isPresented: $habitComposerPresented) {
            SunriseAddHabitSheetView(
                viewModel: habitComposerViewModel,
                onHabitCreated: { _ in
                    habitComposerPresented = false
                    viewModel.refresh()
                },
                onDismissWithoutHabit: {
                    habitComposerPresented = false
                }
            )
        }
        .alert(
            "Habit Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.rows.isEmpty {
            HabitEmptyStateCard(
                systemImage: "clock.arrow.circlepath",
                title: "Loading habits",
                message: "Pulling in your behavior loops and their latest rhythm signals.",
                showsProgress: true
            )
        } else if filteredRows.isEmpty {
            if searchText.isEmpty {
                HabitEmptyStateCard(
                    systemImage: "circle.dashed",
                    title: emptyTitle,
                    message: emptyBody,
                    actionTitle: "Add Habit",
                    action: presentHabitComposer
                )
            } else {
                HabitEmptyStateCard(
                    systemImage: "magnifyingglass",
                    title: "No matching habits",
                    message: "Try a different search or switch filters to see more habits."
                )
            }
        } else {
            LazyVGrid(columns: columns, spacing: spacing.s12) {
                ForEach(filteredRows) { row in
                    Button {
                        LifeBoardPerformanceTrace.event("HabitDetailTapReceived")
                        selectedRow = row
                    } label: {
                        HabitLibraryCard(row: row)
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }
        }
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .active:
            return "No active habits"
        case .paused:
            return "No paused habits"
        case .archived:
            return "No archived habits"
        }
    }

    private var emptyBody: String {
        switch selectedFilter {
        case .active:
            return "Create a behavior loop to keep consistency visible without adding more task clutter."
        case .paused:
            return "Paused habits stay here so they can come back without losing their history."
        case .archived:
            return "Archived habits keep their rhythm history, but stay out of your active management flow."
        }
    }

    private func trackingLabel(for row: HabitLibraryRow) -> String {
        row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in"
    }

    private func presentHabitComposer() {
        habitComposerViewModel.resetForm()
        habitComposerPresented = true
    }

}
private struct HabitLibrarySummaryHeader: View {
    let activeCount: Int
    let pausedCount: Int
    let archivedCount: Int

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Habit system")
                .font(.lifeboard(.screenTitle))
                .foregroundColor(Color.lifeboard.textPrimary)

            Text("Keep recurring behavior legible without turning it into more task noise.")
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)

            HStack(spacing: spacing.s8) {
                HabitCountPill(title: "Active", value: activeCount, tone: .accent)
                HabitCountPill(title: "Paused", value: pausedCount, tone: .neutral)
                HabitCountPill(title: String(localized: "Archived", defaultValue: "Archived"), value: archivedCount, tone: .neutral)
            }
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: Color.lifeboard.accentSecondary
        )
    }
}

private struct HabitCountPill: View {
    let title: String
    let value: Int
    let tone: HabitMetricTone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.lifeboard(.title3))
                .foregroundColor(tone.textColor)
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: tone.fillColor,
            strokeColor: tone.strokeColor
        )
    }
}

private struct HabitLibraryControlRail: View {
    @Binding var selectedFilter: HabitLibraryFilter
    @Binding var searchText: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s8) {
                ForEach(HabitLibraryFilter.allCases) { filter in
                    Button {
                        withAnimation(LifeBoardAnimation.snappy) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.lifeboard(.callout).weight(.semibold))
                            .foregroundColor(selectedFilter == filter ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing.s8)
                            .background(selectedFilter == filter ? Color.lifeboard.accentPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }
            .padding(spacing.s4)
            .lifeboardChromeSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.pill,
                accentColor: Color.lifeboard.accentSecondary,
                level: .e1
            )

            HStack(spacing: spacing.s8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.lifeboard.textSecondary)
                TextField("Search habits, life areas, or projects", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.lifeboard(.body))
            }
            .padding(.horizontal, spacing.s12)
            .frame(height: spacing.buttonHeight)
            .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfacePrimary)
        }
    }
}

private struct HabitLibraryCard: View {
    let row: HabitLibraryRow

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(row.title)
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: spacing.s4) {
                        HabitPill(text: row.kind == .positive ? "Build" : "Quit", tone: row.kind == .positive ? .success : .warning)
                        HabitPill(text: row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in", tone: .neutral)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(metaLine)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textSecondary)
                .lineLimit(2)

            HabitHistoryStripView(
                marks: row.last14Days,
                cadence: row.cadence,
                family: HabitColorFamily.family(
                    for: row.colorHex,
                    fallback: row.kind == .positive ? .green : .coral
                )
            )

            HStack(spacing: spacing.s8) {
                HabitMiniMetric(title: "Active", value: "\(row.currentStreak)d")
                HabitMiniMetric(title: "Best", value: "\(row.bestStreak)d")
                HabitMiniMetric(title: stateLabel, value: stateValue)
            }
        }
        .padding(spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }

    private var kindColor: Color {
        row.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning
    }

    private var accentColor: Color {
        LifeBoardHexColor.color(row.colorHex, fallback: kindColor)
    }

    private var metaLine: String {
        var parts = [row.lifeAreaName]
        if let projectName = row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        return parts.joined(separator: " · ")
    }

    private var stateLabel: String {
        if row.isArchived { return "Status" }
        if row.isPaused { return "Status" }
        return "Next"
    }

    private var stateValue: String {
        if row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
        if row.isPaused { return "Paused" }
        if let nextDueAt = row.nextDueAt {
            return nextDueAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Open"
    }
}

private struct HabitMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundColor(Color.lifeboard.textPrimary)
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.surfaceSecondary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
    }
}

private struct HabitEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    let showsProgress: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        showsProgress: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.showsProgress = showsProgress
        self.actionTitle = actionTitle
        self.action = action
    }

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(spacing: spacing.s12) {
            if showsProgress {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }

            Text(title)
                .font(.lifeboard(.headline))
                .foregroundColor(Color.lifeboard.textPrimary)

            Text(message)
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(spacing.s20)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }
}
@MainActor
private enum HabitMetricTone {
    case accent
    case warning
    case success
    case neutral

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentWash
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .neutral:
            return Color.lifeboard.surfaceSecondary
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.22)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.22)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.22)
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.74)
        }
    }

    var textColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary
        case .warning:
            return Color.lifeboard.statusWarning
        case .success:
            return Color.lifeboard.statusSuccess
        case .neutral:
            return Color.lifeboard.textPrimary
        }
    }
}
private struct HabitPill: View {
    let text: String
    let tone: HabitPillTone

    var body: some View {
        Text(text)
            .font(.lifeboard(.caption2).weight(.semibold))
            .foregroundColor(tone.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)

            .background(tone.fillColor)
            .overlay(
                Capsule()
                    .stroke(tone.strokeColor, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

@MainActor
private enum HabitPillTone {
    case accent
    case neutral
    case success
    case warning

    var textColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary
        case .neutral:
            return Color.lifeboard.textSecondary
        case .success:
            return Color.lifeboard.statusSuccess
        case .warning:
            return Color.lifeboard.statusWarning
        }
    }

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentWash
        case .neutral:
            return Color.lifeboard.surfaceSecondary
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.18)
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.72)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.22)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.22)
        }
    }
}

import SwiftUI

struct SunriseSearchFaceView<ResultsContent: View>: View {
    @Binding var query: String
    @Binding var commandMode: CommandSearchMode
    @FocusState.Binding var isFocused: Bool
    let bottomInset: CGFloat
    let topContentInset: CGFloat
    let quickChips: [LifeBoardSearchFilterChipDescriptor]
    let advancedStatusChips: [LifeBoardSearchFilterChipDescriptor]
    let advancedPriorityChips: [LifeBoardSearchFilterChipDescriptor]
    let advancedProjectChips: [LifeBoardSearchFilterChipDescriptor]
    let recentSearches: [String]
    let activeFilterCount: Int
    let resultCount: Int
    let isLoading: Bool
    let loadingMessage: String
    let showsNoResults: Bool
    let hasActiveSuggestedCommand: Bool
    let emptyTitle: String
    let emptySubtitle: String
    let emptyPrimaryTitle: String?
    let hasActiveFilters: Bool
    let onBack: () -> Void
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onClearFilters: () -> Void
    let onEmptyPrimaryAction: (() -> Void)?
    let onRunSuggestedCommand: (HomeSearchSuggestedCommand) -> Void
    let onAskEvaPrompt: (String) -> Void
    @ViewBuilder let resultsContent: ResultsContent

    @State private var showsAdvancedFilters = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDefaultState: Bool {
        trimmedQuery.isEmpty && hasActiveFilters == false && isLoading == false
    }

    private var isSlashQuery: Bool {
        trimmedQuery.hasPrefix("/")
    }

    var body: some View {
        SunriseDestinationScaffold(
            title: "Search LifeBoard",
            subtitle: "Ask, find, or command",
            leadingSystemImage: "line.3.horizontal",
            leadingAccessibilityLabel: "Back to tasks",
            leadingAccessibilityIdentifier: "search.backChip",
            leadingAction: onBack,
            trailingSystemImage: "sparkles",
            trailingAccessibilityLabel: "Ask Eva",
            trailingAction: { askEva(nonEmpty(trimmedQuery) ?? "What should I do next?") },
            metricPillTitle: activeFilterCount > 0 ? "\(activeFilterCount) filters" : nil,
            bottomInset: 0,
            topContentInset: topContentInset
        ) {
            VStack(spacing: LBSpacingTokens.md) {
                searchChrome

                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        bodyContent(availableHeight: proxy.size.height)
                            .padding(.bottom, bottomInset + LBSpacingTokens.lg)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityIdentifier("search.contentContainer")
                }
            }
        }
        .sheet(isPresented: $showsAdvancedFilters) {
            CommandSearchAdvancedFilterSheet(
                statusChips: advancedStatusChips,
                priorityChips: advancedPriorityChips,
                projectChips: advancedProjectChips,
                activeFilterCount: activeFilterCount,
                onReset: onClearFilters,
                onApply: { showsAdvancedFilters = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.view")
    }

    private var searchChrome: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            LifeBoardSearchHeaderView(
                query: $query,
                isFocused: _isFocused,
                placeholder: commandMode == .askEva ? "Ask Eva or use /commands..." : "Search tasks, notes, habits, projects...",
                isCommandMode: commandMode == .askEva,
                onQueryChanged: onQueryChanged,
                onSubmit: submitSearch,
                onClear: onClear
            )

            modeSelector
            SecondaryChipRow(chips: quickChipsWithMore)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.chromeContainer")
    }

    private var modeSelector: some View {
        SunriseSegmentedControl(
            options: CommandSearchMode.allCases,
            selection: commandMode,
            title: { $0.title },
            accessibilityIdentifier: { "search.mode.\($0.rawValue)" },
            action: { mode in
                commandMode = mode
                LifeBoardFeedback.selection()
            }
        )
    }

    private var quickChipsWithMore: [LifeBoardSearchFilterChipDescriptor] {
        quickChips + [
            LifeBoardSearchFilterChipDescriptor(
                id: "more",
                title: activeFilterCount > 0 ? "More \(activeFilterCount)" : "More",
                systemImage: "slider.horizontal.3",
                isSelected: activeFilterCount > 0,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.filter.more"
            ) {
                showsAdvancedFilters = true
                LifeBoardFeedback.selection()
            }
        ]
    }

    @ViewBuilder
    private func bodyContent(availableHeight: CGFloat) -> some View {
        if isLoading {
            SecondaryStateRenderer(
                asset: .thinkingCup,
                title: loadingMessage,
                message: "Gathering matching tasks and command suggestions."
            )
            .frame(maxWidth: .infinity, minHeight: max(availableHeight - bottomInset, 260), alignment: .center)
        } else if showsNoResults {
            CommandSearchNoResultsState(
                title: emptyTitle,
                subtitle: emptySubtitle,
                query: trimmedQuery,
                hasActiveFilters: hasActiveFilters,
                onClearFilters: onClearFilters,
                primaryTitle: emptyPrimaryTitle,
                primaryAction: onEmptyPrimaryAction,
                onAskEva: { askEva(nonEmpty(trimmedQuery) ?? "Help me find the right plan") }
            )
            .frame(maxWidth: .infinity, minHeight: max(availableHeight - bottomInset, 260), alignment: .center)
        } else if isDefaultState && hasActiveSuggestedCommand == false {
            CommandSearchDefaultState(
                suggestions: suggestedCommands,
                recentSearches: recentSearches,
                onRunSuggestion: runSuggestion,
                onAskEva: askEva
            )
            .frame(maxWidth: .infinity, minHeight: max(availableHeight - bottomInset, 260), alignment: .top)
        } else {
            VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                if shouldShowAskEvaRow {
                    CommandSearchAskEvaRow(
                        query: trimmedQuery,
                        isSlashCommand: isSlashQuery,
                        onAsk: { askEva(trimmedQuery) }
                    )
                }

                Text(resultCount == 1 ? "1 result" : "\(resultCount) results")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .accessibilityIdentifier("search.resultsSummary")

                resultsContent
            }
            .frame(maxWidth: .infinity, minHeight: max(availableHeight - bottomInset, 0), alignment: .topLeading)
        }
    }

    private var shouldShowAskEvaRow: Bool {
        (trimmedQuery.isEmpty == false && commandMode == .askEva)
            || trimmedQuery.split(separator: " ").count >= 3
            || isSlashQuery
    }

    private var suggestedCommands: [HomeSearchSuggestedCommand] {
        HomeSearchSuggestedCommand.contextualDefaults()
    }

    private func submitSearch() {
        if commandMode == .askEva, trimmedQuery.isEmpty == false {
            askEva(trimmedQuery)
        } else {
            onSubmit()
        }
    }

    private func runSuggestion(_ suggestion: HomeSearchSuggestedCommand) {
        onRunSuggestedCommand(suggestion)
    }

    private func askEva(_ prompt: String) {
        let resolvedPrompt = nonEmpty(prompt) ?? "What should I do next?"
        onAskEvaPrompt(resolvedPrompt)
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct CommandSearchDefaultState: View {
    let suggestions: [HomeSearchSuggestedCommand]
    let recentSearches: [String]
    let onRunSuggestion: (HomeSearchSuggestedCommand) -> Void
    let onAskEva: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            Text("Suggested commands")
                .font(.lifeboard(.headline).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)

            LazyVStack(spacing: LBSpacingTokens.sm) {
                ForEach(suggestions) { suggestion in
                    CommandSearchSuggestionRow(suggestion: suggestion) {
                        onRunSuggestion(suggestion)
                    }
                }
            }

            if recentSearches.isEmpty == false {
                Text("Recent")
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                    .padding(.top, LBSpacingTokens.xs)

                LazyVStack(spacing: LBSpacingTokens.xs) {
                    ForEach(recentSearches, id: \.self) { search in
                        Button {
                            onAskEva(search)
                        } label: {
                            Label(search, systemImage: "clock.arrow.circlepath")
                                .font(.lifeboard(.callout))
                                .foregroundStyle(LBColorTokens.navySoft)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct CommandSearchSuggestionRow: View {
    let suggestion: HomeSearchSuggestedCommand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBSpacingTokens.sm) {
                Image(systemName: suggestion.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .frame(width: 42, height: 42)
                    .background(LBColorTokens.violetSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                    Text(suggestion.context)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LBColorTokens.textTertiary)
            }
            .padding(LBSpacingTokens.md)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("search.suggestion.\(suggestion.rawValue)")
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LBColorTokens.glassStrong.opacity(0.82))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(LBColorTokens.glassBorder, lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CommandSearchAskEvaRow: View {
    let query: String
    let isSlashCommand: Bool
    let onAsk: () -> Void

    var body: some View {
        Button(action: onAsk) {
            HStack(spacing: LBSpacingTokens.sm) {
                Image(systemName: isSlashCommand ? "terminal" : "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .frame(width: 44, height: 44)
                    .background(LBColorTokens.violetSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(isSlashCommand ? "Run command" : "Ask Eva")
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                    Text(query)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LBColorTokens.textTertiary)
            }
            .padding(LBSpacingTokens.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LBColorTokens.glassStrong.opacity(0.86))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(LBColorTokens.violet.opacity(0.30), lineWidth: 1))
        }
        .accessibilityIdentifier("search.askEvaRow")
        .accessibilityElement(children: .combine)
    }
}

private struct CommandSearchNoResultsState: View {
    let title: String
    let subtitle: String
    let query: String
    let hasActiveFilters: Bool
    let onClearFilters: () -> Void
    let primaryTitle: String?
    let primaryAction: (() -> Void)?
    let onAskEva: () -> Void

    var body: some View {
        SecondaryStateRenderer(
            asset: .decisionSign,
            title: title,
            message: subtitle,
            primaryTitle: primaryTitle ?? (hasActiveFilters ? "Clear filters" : nil),
            primaryAction: primaryAction ?? (hasActiveFilters ? onClearFilters : nil),
            secondaryTitle: query.isEmpty ? nil : "Ask Eva",
            secondaryAction: query.isEmpty ? nil : onAskEva
        )
        .accessibilityIdentifier("search.noResults")
    }
}

struct SunriseSearchResultsSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            Color.clear
                .frame(height: 0)
                .accessibilityIdentifier("search.resultsList")

            content
        }
        .padding(LBSpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LBColorTokens.glass.opacity(0.74))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(LBColorTokens.glassBorder, lineWidth: 1)
                )
                .shadow(color: LBColorTokens.elevationShadow, radius: 16, x: 0, y: 9)
        }
    }
}

struct HomeSearchCommandResultHeader: View {
    let result: HomeSearchCommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: LBSpacingTokens.xs) {
                Image(systemName: result.command.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .accessibilityHidden(true)

                Text(result.title)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)

                Spacer(minLength: 0)

                Text(result.resultCount == 1 ? "1 result" : "\(result.resultCount) results")
                    .font(.lifeboard(.caption2).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navyMuted)
            }

            Text(result.subtitle)
                .font(.lifeboard(.caption1))
                .foregroundStyle(LBColorTokens.navyMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("search.commandResult.header")
    }
}

struct HomeSearchHabitResultRow: View {
    let row: HomeHabitRow
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: LBSpacingTokens.sm) {
                Image(systemName: row.iconSymbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .frame(width: 40, height: 40)
                    .background(LBColorTokens.violetSoft, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)

                    Text(subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LBColorTokens.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(LBSpacingTokens.sm)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LBColorTokens.glassStrong.opacity(0.68))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LBColorTokens.glassBorder, lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("search.habitResult.\(row.id)")
    }

    private var subtitle: String {
        let activeDays = row.currentStreak == 1 ? "1 active day" : "\(row.currentStreak) active days"
        switch row.state {
        case .overdue:
            return "Needs rescue - \(activeDays)"
        case .lapsedToday:
            return "Lapsed today - \(activeDays)"
        case .due:
            return "Due - \(activeDays)"
        case .tracking:
            return "Tracking - \(activeDays)"
        case .completedToday:
            return "Completed today - \(activeDays)"
        case .skippedToday:
            return "Skipped today - \(activeDays)"
        }
    }
}

private struct CommandSearchAdvancedFilterSheet: View {
    let statusChips: [LifeBoardSearchFilterChipDescriptor]
    let priorityChips: [LifeBoardSearchFilterChipDescriptor]
    let projectChips: [LifeBoardSearchFilterChipDescriptor]
    let activeFilterCount: Int
    let onReset: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LBSpacingTokens.lg) {
                    filterSection(title: "Status", chips: statusChips)
                    filterSection(title: "Priority", chips: priorityChips)
                    filterSection(title: "Type", chips: typeChips)
                    filterSection(title: "Date", chips: dateChips)
                    filterSection(title: "Category", chips: projectChips.isEmpty ? categoryFallbackChips : projectChips)
                }
                .padding(LBSpacingTokens.screenMargin)
            }
            .navigationTitle("Refine search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset", action: onReset)
                        .disabled(activeFilterCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: onApply)
                }
            }
        }
    }

    private func filterSection(title: String, chips: [LifeBoardSearchFilterChipDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            Text(title)
                .font(.lifeboard(.headline).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
            FlexibleChipWrap(chips: chips)
        }
    }

    private var typeChips: [LifeBoardSearchFilterChipDescriptor] {
        ["Tasks", "Habits", "Notes", "Projects", "Routines"].map { title in
            LifeBoardSearchFilterChipDescriptor(
                id: "type-\(title)",
                title: title,
                isSelected: title == "Tasks",
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.type.\(title.lowercased())",
                action: { LifeBoardFeedback.selection() }
            )
        }
    }

    private var dateChips: [LifeBoardSearchFilterChipDescriptor] {
        ["Today", "Tomorrow", "This week", "No date", "Custom"].map { title in
            LifeBoardSearchFilterChipDescriptor(
                id: "date-\(title)",
                title: title,
                isSelected: false,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.date.\(title.lowercased().replacingOccurrences(of: " ", with: ""))",
                action: { LifeBoardFeedback.selection() }
            )
        }
    }

    private var categoryFallbackChips: [LifeBoardSearchFilterChipDescriptor] {
        ["Appointments", "Bills", "Health", "Work", "Personal"].map { title in
            LifeBoardSearchFilterChipDescriptor(
                id: "category-\(title)",
                title: title,
                isSelected: false,
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.category.\(title.lowercased())",
                action: { LifeBoardFeedback.selection() }
            )
        }
    }
}

private struct FlexibleChipWrap: View {
    let chips: [LifeBoardSearchFilterChipDescriptor]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: LBSpacingTokens.sm)], alignment: .leading, spacing: LBSpacingTokens.sm) {
            ForEach(chips) { chip in
                LifeBoardFilterChip(
                    title: chip.title,
                    systemImage: chip.systemImage,
                    count: chip.count,
                    isSelected: chip.isSelected,
                    accentColor: chip.tintColor,
                    accessibilityIdentifier: chip.accessibilityIdentifier,
                    action: chip.action
                )
            }
        }
    }
}

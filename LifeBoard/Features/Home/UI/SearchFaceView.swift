import SwiftUI

struct SearchFaceView<ResultsContent: View>: View {
    @Binding var query: String
    @Binding var commandMode: CommandSearchMode
    @FocusState.Binding var isFocused: Bool
    let bottomInset: CGFloat
    let topContentInset: CGFloat
    let quickChips: [SearchFilterChipDescriptor]
    let advancedStatusChips: [SearchFilterChipDescriptor]
    let advancedPriorityChips: [SearchFilterChipDescriptor]
    let advancedProjectChips: [SearchFilterChipDescriptor]
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
        DestinationScaffold(
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
            VStack(spacing: ClayLayoutMetrics.md) {
                searchChrome

                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        bodyContent(availableHeight: proxy.size.height)
                            .padding(.bottom, bottomInset + ClayLayoutMetrics.lg)
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
        VStack(alignment: .leading, spacing: ClayLayoutMetrics.sm) {
            SearchHeaderView(
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
        SegmentedControl(
            options: CommandSearchMode.allCases,
            selection: commandMode,
            title: { $0.title },
            accessibilityIdentifier: { "search.mode.\($0.rawValue)" },
            action: { mode in
                commandMode = mode
                HapticFeedback.selection()
            }
        )
    }

    private var quickChipsWithMore: [SearchFilterChipDescriptor] {
        quickChips + [
            SearchFilterChipDescriptor(
                id: "more",
                title: activeFilterCount > 0 ? "More \(activeFilterCount)" : "More",
                systemImage: "slider.horizontal.3",
                isSelected: activeFilterCount > 0,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.filter.more"
            ) {
                showsAdvancedFilters = true
                HapticFeedback.selection()
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
            VStack(alignment: .leading, spacing: ClayLayoutMetrics.md) {
                if shouldShowAskEvaRow {
                    CommandSearchAskEvaRow(
                        query: trimmedQuery,
                        isSlashCommand: isSlashQuery,
                        onAsk: { askEva(trimmedQuery) }
                    )
                }

                Text(resultCount == 1 ? "1 result" : "\(resultCount) results")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(ClayColorTokens.navyMuted)
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
        VStack(alignment: .leading, spacing: ClayLayoutMetrics.md) {
            Text("Suggested commands")
                .font(.lifeboard(.headline).weight(.semibold))
                .foregroundStyle(ClayColorTokens.navy)

            LazyVStack(spacing: ClayLayoutMetrics.sm) {
                ForEach(suggestions) { suggestion in
                    CommandSearchSuggestionRow(suggestion: suggestion) {
                        onRunSuggestion(suggestion)
                    }
                }
            }

            if recentSearches.isEmpty == false {
                Text("Recent")
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(ClayColorTokens.navy)
                    .padding(.top, ClayLayoutMetrics.xs)

                LazyVStack(spacing: ClayLayoutMetrics.xs) {
                    ForEach(recentSearches, id: \.self) { search in
                        Button {
                            onAskEva(search)
                        } label: {
                            Label(search, systemImage: "clock.arrow.circlepath")
                                .font(.lifeboard(.callout))
                                .foregroundStyle(ClayColorTokens.navySoft)
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
            HStack(spacing: ClayLayoutMetrics.sm) {
                Image(systemName: suggestion.symbol)
                    .lifeboardFont(.title2)
                    .foregroundStyle(ClayColorTokens.violetDeep)
                    .frame(width: 42, height: 42)
                    .background(ClayColorTokens.violetSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(ClayColorTokens.navy)
                    Text(suggestion.context)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(ClayColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .lifeboardFont(.eyebrow)
                    .foregroundStyle(ClayColorTokens.textTertiary)
            }
            .padding(ClayLayoutMetrics.md)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("search.suggestion.\(suggestion.rawValue)")
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(ClayColorTokens.glassStrong.opacity(0.82))
                .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(ClayColorTokens.glassBorder, lineWidth: 1))
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
            HStack(spacing: ClayLayoutMetrics.sm) {
                Image(systemName: isSlashCommand ? "terminal" : "sparkles")
                    .lifeboardFont(.title2)
                    .foregroundStyle(ClayColorTokens.violetDeep)
                    .frame(width: 44, height: 44)
                    .background(ClayColorTokens.violetSoft, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(isSlashCommand ? "Run command" : "Ask Eva")
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(ClayColorTokens.navy)
                    Text(query)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(ClayColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer()
                Image(systemName: "arrow.up.right")
                    .lifeboardFont(.meta)
                    .foregroundStyle(ClayColorTokens.textTertiary)
            }
            .padding(ClayLayoutMetrics.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ClayColorTokens.glassStrong.opacity(0.86))
                .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(ClayColorTokens.violet.opacity(0.30), lineWidth: 1))
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

struct SearchResultsSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ClayLayoutMetrics.md) {
            Color.clear
                .frame(height: 0)
                .accessibilityIdentifier("search.resultsList")

            content
        }
        .padding(ClayLayoutMetrics.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ClayColorTokens.glass.opacity(0.74))
                .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(ClayColorTokens.glassBorder, lineWidth: 1)
                )
                .shadow(color: ClayColorTokens.elevationShadow, radius: 16, x: 0, y: 9)
        }
    }
}

struct HomeSearchCommandResultHeader: View {
    let result: HomeSearchCommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: ClayLayoutMetrics.xs) {
                Image(systemName: result.command.symbol)
                    .lifeboardFont(.buttonSmall)
                    .foregroundStyle(ClayColorTokens.violetDeep)
                    .accessibilityHidden(true)

                Text(result.title)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(ClayColorTokens.navy)

                Spacer(minLength: 0)

                Text(result.resultCount == 1 ? "1 result" : "\(result.resultCount) results")
                    .font(.lifeboard(.caption2).weight(.semibold))
                    .foregroundStyle(ClayColorTokens.navyMuted)
            }

            Text(result.subtitle)
                .font(.lifeboard(.caption1))
                .foregroundStyle(ClayColorTokens.navyMuted)
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
            HStack(spacing: ClayLayoutMetrics.sm) {
                Image(systemName: row.iconSymbolName)
                    .lifeboardFont(.title2)
                    .foregroundStyle(ClayColorTokens.violetDeep)
                    .frame(width: 40, height: 40)
                    .background(ClayColorTokens.violetSoft, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(ClayColorTokens.navy)

                    Text(subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(ClayColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .lifeboardFont(.eyebrow)
                    .foregroundStyle(ClayColorTokens.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(ClayLayoutMetrics.sm)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(ClayColorTokens.glassStrong.opacity(0.68))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ClayColorTokens.glassBorder, lineWidth: 1))
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
    let statusChips: [SearchFilterChipDescriptor]
    let priorityChips: [SearchFilterChipDescriptor]
    let projectChips: [SearchFilterChipDescriptor]
    let activeFilterCount: Int
    let onReset: () -> Void
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ClayLayoutMetrics.lg) {
                    filterSection(title: "Status", chips: statusChips)
                    filterSection(title: "Priority", chips: priorityChips)
                    filterSection(title: "Type", chips: typeChips)
                    filterSection(title: "Date", chips: dateChips)
                    filterSection(title: "Category", chips: projectChips.isEmpty ? categoryFallbackChips : projectChips)
                }
                .padding(ClayLayoutMetrics.screenMargin)
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

    private func filterSection(title: String, chips: [SearchFilterChipDescriptor]) -> some View {
        VStack(alignment: .leading, spacing: ClayLayoutMetrics.sm) {
            Text(title)
                .font(.lifeboard(.headline).weight(.semibold))
                .foregroundStyle(ClayColorTokens.navy)
            FlexibleChipWrap(chips: chips)
        }
    }

    private var typeChips: [SearchFilterChipDescriptor] {
        ["Tasks", "Habits", "Notes", "Projects", "Routines"].map { title in
            SearchFilterChipDescriptor(
                id: "type-\(title)",
                title: title,
                isSelected: title == "Tasks",
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.type.\(title.lowercased())",
                action: { HapticFeedback.selection() }
            )
        }
    }

    private var dateChips: [SearchFilterChipDescriptor] {
        ["Today", "Tomorrow", "This week", "No date", "Custom"].map { title in
            SearchFilterChipDescriptor(
                id: "date-\(title)",
                title: title,
                isSelected: false,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.date.\(title.lowercased().replacingOccurrences(of: " ", with: ""))",
                action: { HapticFeedback.selection() }
            )
        }
    }

    private var categoryFallbackChips: [SearchFilterChipDescriptor] {
        ["Appointments", "Bills", "Health", "Work", "Personal"].map { title in
            SearchFilterChipDescriptor(
                id: "category-\(title)",
                title: title,
                isSelected: false,
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.category.\(title.lowercased())",
                action: { HapticFeedback.selection() }
            )
        }
    }
}

private struct FlexibleChipWrap: View {
    let chips: [SearchFilterChipDescriptor]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: ClayLayoutMetrics.sm)], alignment: .leading, spacing: ClayLayoutMetrics.sm) {
            ForEach(chips) { chip in
                FilterChip(
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

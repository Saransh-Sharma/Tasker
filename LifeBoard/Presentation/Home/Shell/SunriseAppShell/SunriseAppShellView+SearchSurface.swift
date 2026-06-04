//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

extension SunriseAppShellView {
    @ViewBuilder
    func searchFaceContentBody(
        availableHeight: CGFloat,
        contentBottomInset: CGFloat
    ) -> some View {
        if isSearchLoadingContentVisible {
            VStack(spacing: spacing.s8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text(searchLoadingMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }
        } else if searchState.shouldShowNoResultsMessage {
            VStack(spacing: spacing.s8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textTertiary)
                Text(searchState.emptyStateTitle)
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)
                    .accessibilityIdentifier("search.emptyStateLabel")
                Text(searchState.emptyStateSubtitle)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(availableHeight - contentBottomInset, 0),
                alignment: .center
            )
        } else {
            LazyVStack(alignment: .leading, spacing: spacing.s12) {
                Color.clear
                    .frame(height: 0)
                    .accessibilityIdentifier("search.resultsList")

                ForEach(searchState.sections) { section in
                    SunriseTaskSectionView(
                        project: searchProject(for: section.projectName),
                        tasks: section.tasks,
                        tagNameByID: tasksSnapshot.tagNameByID,
                        completedCollapsed: false,
                        isTaskDragEnabled: false,
                        onTaskTap: { task in
                            trackSearchResultOpened(task, projectName: section.projectName)
                            onTaskTap(task)
                        },
                        onToggleComplete: { task in
                            trackTaskToggle(task, source: "search_results")
                            onToggleComplete(task)
                        },
                        onDeleteTask: { task in
                            onDeleteTask(task)
                        },
                        onRescheduleTask: { task in
                            onRescheduleTask(task)
                        }
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: max(availableHeight - contentBottomInset, 0),
                alignment: .topLeading
            )
        }
    }

    var searchResultsContent: some View {
        SunriseSearchResultsSurface {
            if let commandResult = searchState.activeSuggestedCommandResult {
                HomeSearchCommandResultHeader(result: commandResult)

                ForEach(commandResult.taskSections) { section in
                    searchTaskSection(section)
                }

                if commandResult.habitRows.isEmpty == false {
                    LazyVStack(spacing: LBSpacingTokens.sm) {
                        ForEach(commandResult.habitRows) { habit in
                            HomeSearchHabitResultRow(row: habit) {
                                openHabitDetail(habit)
                            }
                        }
                    }
                }
            } else {
                ForEach(searchState.sections) { section in
                    searchTaskSection(section)
                }
            }
        }
    }

    func searchTaskSection(_ section: HomeSearchSection) -> some View {
        SunriseTaskSectionView(
            project: searchProject(for: section.projectName),
            tasks: section.tasks,
            tagNameByID: tasksSnapshot.tagNameByID,
            completedCollapsed: searchCompletedResultsCollapsed,
            isTaskDragEnabled: false,
            layoutStyle: .sunriseSearch,
            onTaskTap: { task in
                trackSearchResultOpened(task, projectName: section.projectName)
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "search_results")
                onToggleComplete(task)
            },
            onDeleteTask: { task in
                onDeleteTask(task)
            },
            onRescheduleTask: { task in
                onRescheduleTask(task)
            },
            onCompletedCollapsedChange: { _, _ in
                searchState.toggleCompletedExpansion()
            }
        )
    }

    var searchCompletedResultsCollapsed: Bool {
        if searchState.selectedStatus == .completed { return false }
        if searchState.trimmedQuery.localizedCaseInsensitiveContains("completed") { return false }
        return searchState.isCompletedExpanded == false
    }

    var isSearchLoadingContentVisible: Bool {
        if searchState.hasActiveSuggestedCommand {
            return false
        }
        return (searchSurfaceState != .ready && !searchState.hasLoaded) || (searchState.isLoading && !searchState.hasLoaded)
    }

    var searchLoadingMessage: String {
        if searchSurfaceState != .ready && !searchState.hasLoaded {
            return searchSurfaceState == .presenting ? "Opening search…" : "Loading tasks…"
        }
        return "Loading tasks…"
    }

    var searchContentAlignment: Alignment {
        (isSearchLoadingContentVisible || searchState.shouldShowNoResultsMessage) ? .center : .topLeading
    }

    var searchContentHorizontalPadding: CGFloat {
        searchState.shouldShowNoResultsMessage ? spacing.s20 : spacing.s16
    }

    @ViewBuilder
    func topNavigationBar() -> some View {
        if isSearchOpen || isInsightsOpen {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
        } else if isChatOpen {
            HomeEvaChatTopChromeView(
                chromeState: chatNavigationChromeState,
                onBack: {
                    returnToTasks(source: "chat_top_chrome_back")
                },
                onSettings: {
                    NotificationCenter.default.post(name: .requestEvaChatSettings, object: nil)
                },
                onHistory: {
                    NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
                },
                onNewChat: {
                    NotificationCenter.default.post(name: .requestEvaChatNewThread, object: nil)
                }
            )
            .padding(.top, layoutClass.isPad ? 18 : 0)
        } else {
            VStack(alignment: .leading, spacing: spacing.s12) {
                let headerPresentation = chromeSnapshot.homeHeaderPresentation(
                    tasks: tasksSnapshot,
                    habits: habitsSnapshot
                )

                SunriseCompactHeaderChrome(
                    presentation: headerPresentation,
                    selectedQuickView: chromeSnapshot.activeScope.quickView,
                    taskCounts: chromeSnapshot.quickViewCounts,
                    extraTopPadding: layoutClass.isPad ? 18 : 0,
                    reduceMotion: reduceMotion,
                    onSelectQuickView: { viewModel.setQuickView($0) },
                    onBackToToday: {
                        viewModel.returnToToday(source: .backToToday)
                    },
                    onShowDatePicker: {
                        draftDate = chromeSnapshot.selectedDate
                        showDatePicker = true
                    },
                    onShowAdvancedFilters: {
                        showAdvancedFilters = true
                    },
                    onResetFilters: {
                        viewModel.resetAllFilters()
                    },
                    onOpenMenuSearch: {
                        openSearch(source: "scope_menu_search")
                    },
                    onOpenReflection: {
                        openDailyReflectPlan()
                    },
                    onOpenSettings: {
                        onOpenSettings()
                    }
                )
            }
        }
    }

    var searchQuickChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        let p0 = TaskPriorityConfig.Priority.allCases.first?.rawValue ?? 0
        let hasProjectFilter = searchState.selectedProjects.isEmpty == false
        return [
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-ask-eva",
                title: "Ask Eva",
                systemImage: "sparkles",
                isSelected: searchState.commandMode == .askEva,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.quick.askEva"
            ) {
                searchState.setCommandMode(searchState.commandMode == .askEva ? .search : .askEva)
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-today",
                title: "Today",
                systemImage: "calendar",
                isSelected: searchState.selectedStatus == .today,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: "search.quick.today"
            ) {
                searchState.setStatus(searchState.selectedStatus == .today ? .all : .today)
                trackSearchChipToggled(kind: "status", value: "today", isSelected: searchState.selectedStatus == .today)
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-overdue",
                title: "Rescue",
                systemImage: "lifepreserver",
                isSelected: searchState.selectedStatus == .overdue,
                tintColor: LBColorTokens.role(.warning).base,
                accessibilityIdentifier: "search.quick.overdue"
            ) {
                searchState.setStatus(searchState.selectedStatus == .overdue ? .all : .overdue)
                trackSearchChipToggled(kind: "status", value: "overdue", isSelected: searchState.selectedStatus == .overdue)
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-p0",
                title: "P0",
                systemImage: "flag.fill",
                isSelected: searchState.selectedPriorities.contains(p0),
                tintColor: Color.lifeboard.priorityMax,
                accessibilityIdentifier: "search.quick.p0"
            ) {
                if let priority = TaskPriorityConfig.Priority.allCases.first {
                    searchState.togglePriority(priority)
                    trackSearchChipToggled(kind: "priority", value: priority.code.lowercased(), isSelected: searchState.selectedPriorities.contains(priority.rawValue))
                }
            },
            LifeBoardSearchFilterChipDescriptor(
                id: "quick-projects",
                title: "Projects",
                systemImage: "folder",
                count: searchState.selectedProjects.isEmpty ? nil : searchState.selectedProjects.count,
                isSelected: hasProjectFilter,
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.quick.projects"
            ) {
                if let firstProject = searchState.availableProjects.first {
                    searchState.toggleProject(firstProject)
                    trackSearchChipToggled(kind: "project", value: firstProject, isSelected: searchState.selectedProjects.contains(firstProject))
                } else {
                    LifeBoardFeedback.selection()
                }
            }
        ]
    }

    var searchStatusChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        HomeSearchStatusFilter.allCases.map { status in
            LifeBoardSearchFilterChipDescriptor(
                id: "status-\(status.rawValue)",
                title: status.title,
                systemImage: searchStatusSystemImage(status),
                isSelected: searchState.selectedStatus == status,
                tintColor: Color.lifeboard.accentPrimary,
                accessibilityIdentifier: status.accessibilityIdentifier
            ) {
                searchState.setStatus(status)
                trackSearchChipToggled(kind: "status", value: status.analyticsName, isSelected: true)
            }
        }
    }

    func searchStatusSystemImage(_ status: HomeSearchStatusFilter) -> String {
        switch status {
        case .all:
            return "square.grid.2x2"
        case .today:
            return "calendar"
        case .overdue:
            return "exclamationmark.triangle"
        case .completed:
            return "checkmark.circle"
        }
    }

    var searchPriorityChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        TaskPriorityConfig.Priority.allCases.map { priority in
            let isSelected = searchState.selectedPriorities.contains(priority.rawValue)
            return LifeBoardSearchFilterChipDescriptor(
                id: "priority-\(priority.rawValue)",
                title: priority.code,
                isSelected: isSelected,
                tintColor: Color(uiColor: priority.color),
                accessibilityIdentifier: "search.priority.\(priority.code.lowercased())"
            ) {
                searchState.togglePriority(priority)
                trackSearchChipToggled(
                    kind: "priority",
                    value: priority.code.lowercased(),
                    isSelected: !isSelected
                )
            }
        }
    }

    var searchProjectChipDescriptors: [LifeBoardSearchFilterChipDescriptor] {
        searchState.availableProjects.map { projectName in
            let isSelected = searchState.selectedProjects.contains(projectName)
            return LifeBoardSearchFilterChipDescriptor(
                id: "project-\(projectName)",
                title: projectName,
                isSelected: isSelected,
                tintColor: Color.lifeboard.accentSecondary,
                accessibilityIdentifier: "search.project.\(searchIdentifierToken(projectName))"
            ) {
                searchState.toggleProject(projectName)
                trackSearchChipToggled(
                    kind: "project",
                    value: projectName,
                    isSelected: !isSelected
                )
            }
        }
    }

    func searchProject(for name: String) -> Project {
        if let resolved = tasksSnapshot.projects.first(where: { $0.name == name }) {
            return resolved
        }
        if name == ProjectConstants.inboxProjectName {
            return Project.createInbox()
        }
        return Project(name: name)
    }

    var rescueTasksByID: [UUID: TaskDefinition] {
        Dictionary(
            uniqueKeysWithValues: (
                tasksSnapshot.overdueTasks
                + tasksSnapshot.morningTasks
                + tasksSnapshot.eveningTasks
            ).map { ($0.id, $0) }
        )
    }

    func searchIdentifierToken(_ rawValue: String) -> String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    func trackSearchQueryChanged(_ query: String) {
        let now = Date()
        if let lastSearchQueryTelemetryAt, now.timeIntervalSince(lastSearchQueryTelemetryAt) < 0.7 {
            return
        }
        lastSearchQueryTelemetryAt = now
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.trackHomeInteraction(
            action: "home_search_query_changed",
            metadata: [
                "length": trimmed.count,
                "has_query": trimmed.isEmpty ? "false" : "true"
            ]
        )
    }

    func trackSearchChipToggled(kind: String, value: String, isSelected: Bool) {
        viewModel.trackHomeInteraction(
            action: "home_search_chip_toggled",
            metadata: [
                "kind": kind,
                "value": value,
                "selected": isSelected ? "true" : "false"
            ]
        )
    }
}

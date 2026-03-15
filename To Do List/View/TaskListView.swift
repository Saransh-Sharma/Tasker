//
//  TaskListView.swift
//  Tasker
//
//  Top-level task list with project-grouped collapsible sections.
//  Groups tasks by projectID, sorts Overdue > Inbox > alphabetical.
//  Part of the "Obsidian & Gems" design system.
//

import SwiftUI

// MARK: - Task List View

private struct TaskListTodayLayoutCacheKey: Equatable {
    let morningTaskSignature: [String]
    let eveningTaskSignature: [String]
    let overdueTaskSignature: [String]
    let inlineCompletedSignature: [String]
    let projectSignature: [String]
    let groupingMode: HomeProjectGroupingMode
    let customProjectOrderIDs: [UUID]
}

private enum TaskListTodayLayoutCache {
    private static var lastEntry: (key: TaskListTodayLayoutCacheKey, layout: HomeTaskTodayLayout)?

    static func layout(
        for key: TaskListTodayLayoutCacheKey,
        build: () -> HomeTaskTodayLayout
    ) -> HomeTaskTodayLayout {
        if V2FeatureFlags.iPadPerfTaskRenderMemoizationV3Enabled,
           let lastEntry,
           lastEntry.key == key {
            return lastEntry.layout
        }

        let layout = build()
        if V2FeatureFlags.iPadPerfTaskRenderMemoizationV3Enabled {
            lastEntry = (key, layout)
        }
        return layout
    }

    static func taskSignature(for tasks: [TaskDefinition]) -> [String] {
        tasks.map { task in
            let completedAt = task.dateCompleted?.timeIntervalSinceReferenceDate ?? 0
            return [
                task.id.uuidString,
                task.projectID.uuidString,
                String(task.updatedAt.timeIntervalSinceReferenceDate),
                String(completedAt),
                task.isComplete ? "1" : "0"
            ].joined(separator: ":")
        }
    }

    static func projectSignature(for projects: [Project]) -> [String] {
        projects.map { project in
            [
                project.id.uuidString,
                project.name,
                project.icon.systemImageName
            ].joined(separator: ":")
        }
    }
}

struct HomeScrollChromeStateTracker {
    private let jitterThreshold: CGFloat = 6
    private let minimizeThreshold: CGFloat = 24
    private let restoreThreshold: CGFloat = 12
    private let nearTopThreshold: CGFloat = 40

    private(set) var lastOffsetY: CGFloat?
    private(set) var cumulativeDownward: CGFloat = 0
    private(set) var cumulativeUpward: CGFloat = 0
    private(set) var emittedState: HomeScrollChromeState = .nearTop

    mutating func consume(offset newOffset: CGFloat) -> HomeScrollChromeState? {
        guard newOffset.isFinite else { return nil }

        if newOffset < nearTopThreshold {
            lastOffsetY = nil
            cumulativeDownward = 0
            cumulativeUpward = 0
            return emit(.nearTop)
        }

        guard let lastOffsetY else {
            self.lastOffsetY = newOffset
            return emit(.expanded)
        }

        let delta = newOffset - lastOffsetY
        self.lastOffsetY = newOffset

        guard abs(delta) >= jitterThreshold else { return nil }

        if delta > 0 {
            cumulativeDownward += delta
            cumulativeUpward = 0
            if cumulativeDownward >= minimizeThreshold {
                cumulativeDownward = 0
                return emit(.collapsed)
            }
            return nil
        }

        cumulativeUpward += abs(delta)
        cumulativeDownward = 0
        if cumulativeUpward >= restoreThreshold {
            cumulativeUpward = 0
            return emit(.expanded)
        }
        return nil
    }

    mutating func emitIdleIfNeeded() -> HomeScrollChromeState? {
        emit(.idle)
    }

    private mutating func emit(_ state: HomeScrollChromeState) -> HomeScrollChromeState? {
        guard emittedState != state else { return nil }
        emittedState = state
        return state
    }
}

struct TaskListView: View {
    private static let defaultBottomContentInset: CGFloat = 80
    private static let scrollTraceIdleDelayNanoseconds: UInt64 = 250_000_000

    let headerContent: AnyView?
    let morningTasks: [TaskDefinition]
    let eveningTasks: [TaskDefinition]
    let overdueTasks: [TaskDefinition]
    let inlineCompletedTasks: [TaskDefinition]
    let projects: [Project]
    let doneTimelineTasks: [TaskDefinition]
    let tagNameByID: [UUID: String]
    let activeQuickView: HomeQuickView?
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let projectGroupingMode: HomeProjectGroupingMode
    let customProjectOrderIDs: [UUID]
    let emptyStateMessage: String?
    let emptyStateActionTitle: String?
    let isTaskDragEnabled: Bool
    var onTaskTap: ((TaskDefinition) -> Void)? = nil
    var onToggleComplete: ((TaskDefinition) -> Void)? = nil
    var onDeleteTask: ((TaskDefinition) -> Void)? = nil
    var onRescheduleTask: ((TaskDefinition) -> Void)? = nil
    var onReorderCustomProjects: (([UUID]) -> Void)? = nil
    var onInboxHeaderAction: (() -> Void)? = nil
    var inboxHeaderActionTitle: String? = nil
    var onOverdueHeaderAction: (() -> Void)? = nil
    var overdueHeaderActionTitle: String? = nil
    var onCompletedSectionToggle: ((UUID, Bool, Int) -> Void)? = nil
    var onEmptyStateAction: (() -> Void)? = nil
    var onTaskDragStarted: ((TaskDefinition) -> Void)? = nil
    var onScrollChromeStateChange: ((HomeScrollChromeState) -> Void)? = nil
    let highlightedTaskID: UUID?
    let bottomContentInset: CGFloat
    @State private var draggingCustomProjectID: UUID?
    @State private var isCompletedCollapsedBySection: [UUID: Bool] = [:]
    @State private var scrollChromeStateTracker = HomeScrollChromeStateTracker()
    @State private var scrollTraceInterval: TaskerPerformanceInterval?
    @State private var pendingScrollTraceIdleTask: Task<Void, Never>?

    /// Initializes a new instance.
    init(
        headerContent: AnyView? = nil,
        morningTasks: [TaskDefinition],
        eveningTasks: [TaskDefinition],
        overdueTasks: [TaskDefinition],
        inlineCompletedTasks: [TaskDefinition] = [],
        projects: [Project],
        doneTimelineTasks: [TaskDefinition] = [],
        tagNameByID: [UUID: String] = [:],
        activeQuickView: HomeQuickView? = nil,
        todayXPSoFar: Int? = nil,
        isGamificationV2Enabled: Bool = V2FeatureFlags.gamificationV2Enabled,
        projectGroupingMode: HomeProjectGroupingMode = .defaultMode,
        customProjectOrderIDs: [UUID] = [],
        emptyStateMessage: String? = nil,
        emptyStateActionTitle: String? = nil,
        isTaskDragEnabled: Bool = false,
        onTaskTap: ((TaskDefinition) -> Void)? = nil,
        onToggleComplete: ((TaskDefinition) -> Void)? = nil,
        onDeleteTask: ((TaskDefinition) -> Void)? = nil,
        onRescheduleTask: ((TaskDefinition) -> Void)? = nil,
        onReorderCustomProjects: (([UUID]) -> Void)? = nil,
        onInboxHeaderAction: (() -> Void)? = nil,
        inboxHeaderActionTitle: String? = nil,
        onOverdueHeaderAction: (() -> Void)? = nil,
        overdueHeaderActionTitle: String? = nil,
        onCompletedSectionToggle: ((UUID, Bool, Int) -> Void)? = nil,
        onEmptyStateAction: (() -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil,
        onScrollChromeStateChange: ((HomeScrollChromeState) -> Void)? = nil,
        highlightedTaskID: UUID? = nil,
        bottomContentInset: CGFloat = TaskListView.defaultBottomContentInset
    ) {
        self.headerContent = headerContent
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.inlineCompletedTasks = inlineCompletedTasks
        self.projects = projects
        self.doneTimelineTasks = doneTimelineTasks
        self.tagNameByID = tagNameByID
        self.activeQuickView = activeQuickView
        self.todayXPSoFar = todayXPSoFar
        self.isGamificationV2Enabled = isGamificationV2Enabled
        self.projectGroupingMode = projectGroupingMode
        self.customProjectOrderIDs = customProjectOrderIDs
        self.emptyStateMessage = emptyStateMessage
        self.emptyStateActionTitle = emptyStateActionTitle
        self.isTaskDragEnabled = isTaskDragEnabled
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
        self.onReorderCustomProjects = onReorderCustomProjects
        self.onInboxHeaderAction = onInboxHeaderAction
        self.inboxHeaderActionTitle = inboxHeaderActionTitle
        self.onOverdueHeaderAction = onOverdueHeaderAction
        self.overdueHeaderActionTitle = overdueHeaderActionTitle
        self.onCompletedSectionToggle = onCompletedSectionToggle
        self.onEmptyStateAction = onEmptyStateAction
        self.onTaskDragStarted = onTaskDragStarted
        self.onScrollChromeStateChange = onScrollChromeStateChange
        self.highlightedTaskID = highlightedTaskID
        self.bottomContentInset = bottomContentInset
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                    if let headerContent {
                        headerContent
                    }

                    if activeQuickView == .done {
                        doneTimelineContent
                    } else {
                        regularTaskContent
                    }

                    // Empty state
                    if allTasksEmpty {
                        emptyStateView
                            .enhancedStaggeredAppearance(index: 0)
                    }

                    // Bottom spacer for tab bar
                    Spacer()
                        .frame(height: bottomContentInset)
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.lg)
            .onAppear {
                scrollToHighlightedTaskIfNeeded(proxy: proxy)
                onScrollChromeStateChange?(.nearTop)
            }
            .onDisappear {
                finishScrollTraceIfNeeded()
            }
            .onChange(of: highlightedTaskID) { _, _ in
                scrollToHighlightedTaskIfNeeded(proxy: proxy)
            }
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                },
                action: { _, newOffset in
                    handleScrollOffsetChange(newOffset)
                }
            )
            .accessibilityIdentifier("home.taskList.scrollView")
        }
    }

    private func handleScrollOffsetChange(_ newOffset: CGFloat) {
        let previousOffset = scrollChromeStateTracker.lastOffsetY
        if previousOffset != nil || newOffset > 2 {
            recordScrollActivity()
        }
        if let nextState = scrollChromeStateTracker.consume(offset: newOffset) {
            onScrollChromeStateChange?(nextState)
        }
    }

    private func recordScrollActivity() {
        if scrollTraceInterval == nil {
            scrollTraceInterval = TaskerPerformanceTrace.begin("HomeTaskListScrollSession")
        }

        pendingScrollTraceIdleTask?.cancel()
        pendingScrollTraceIdleTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.scrollTraceIdleDelayNanoseconds)
            } catch {
                return
            }
            finishScrollTraceIfNeeded()
        }
    }

    private func finishScrollTraceIfNeeded() {
        pendingScrollTraceIdleTask?.cancel()
        pendingScrollTraceIdleTask = nil

        if let scrollTraceInterval {
            TaskerPerformanceTrace.end(scrollTraceInterval)
            self.scrollTraceInterval = nil
        }

        if let idleState = scrollChromeStateTracker.emitIdleIfNeeded() {
            onScrollChromeStateChange?(idleState)
        }
    }

    private func scrollToHighlightedTaskIfNeeded(proxy: ScrollViewProxy) {
        guard let highlightedTaskID else { return }
        DispatchQueue.main.async {
            withAnimation(TaskerAnimation.gentle) {
                proxy.scrollTo(highlightedTaskID, anchor: .center)
            }
        }
    }

    // MARK: - Regular Grouping Logic

    @ViewBuilder
    private var regularTaskContent: some View {
        if activeQuickView == .today {
            todayRegularTaskContent
        } else {
            legacyRegularTaskContent
        }
    }

    @ViewBuilder
    private var todayRegularTaskContent: some View {
        let completedByID = inlineCompletedTasks.reduce(into: [UUID: TaskDefinition]()) { partialResult, task in
            partialResult[task.id] = task
        }
        let reconciledMorning = morningTasks.map { completedByID[$0.id] ?? $0 }
        let reconciledEvening = eveningTasks.map { completedByID[$0.id] ?? $0 }
        let reconciledOverdue = overdueTasks.map { completedByID[$0.id] ?? $0 }

        let baseNonOverdue = reconciledMorning + reconciledEvening
        let baseIDs = Set((baseNonOverdue + reconciledOverdue).map(\.id))
        let additionalCompleted = inlineCompletedTasks.filter { !baseIDs.contains($0.id) }
        let mergedNonOverdue = baseNonOverdue + additionalCompleted.filter { !$0.isOverdue }
        let mergedOverdue = reconciledOverdue + additionalCompleted.filter(\.isOverdue)

        let layoutKey = TaskListTodayLayoutCacheKey(
            morningTaskSignature: TaskListTodayLayoutCache.taskSignature(for: morningTasks),
            eveningTaskSignature: TaskListTodayLayoutCache.taskSignature(for: eveningTasks),
            overdueTaskSignature: TaskListTodayLayoutCache.taskSignature(for: overdueTasks),
            inlineCompletedSignature: TaskListTodayLayoutCache.taskSignature(for: inlineCompletedTasks),
            projectSignature: TaskListTodayLayoutCache.projectSignature(for: projects),
            groupingMode: projectGroupingMode,
            customProjectOrderIDs: customProjectOrderIDs
        )
        let layout = TaskListTodayLayoutCache.layout(for: layoutKey) {
            HomeTaskSectionBuilder.buildTodayLayout(
                mode: projectGroupingMode,
                nonOverdueTasks: mergedNonOverdue,
                overdueTasks: mergedOverdue,
                projects: projects,
                customProjectOrderIDs: customProjectOrderIDs
            )
        }
        if let inboxSection = layout.inboxSection, !inboxSection.tasks.isEmpty {
            TaskSectionView(
                project: inboxSection.project,
                tasks: inboxSection.tasks,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                completedCollapsed: isCompletedCollapsedBySection[inboxSection.project.id],
                isTaskDragEnabled: isTaskDragEnabled,
                highlightedTaskID: highlightedTaskID,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[inboxSection.project.id] = collapsed
                    onCompletedSectionToggle?(inboxSection.project.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted,
                headerActionTitle: inboxHeaderActionTitle,
                onHeaderAction: onInboxHeaderAction,
                headerActionAccessibilityID: "home.inbox.headerAction"
            )
        }

        if projectGroupingMode == .prioritizeOverdue, !layout.overdueGroups.isEmpty {
            OverdueGroupedSectionView(
                groups: layout.overdueGroups,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                isTaskDragEnabled: isTaskDragEnabled,
                headerActionTitle: overdueHeaderActionTitle,
                onHeaderAction: onOverdueHeaderAction,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onTaskDragStarted: onTaskDragStarted
            )
        }

        let currentCustomOrder = layout.customSections.map(\.project.id)
        ForEach(Array(layout.customSections.enumerated()), id: \.element.id) { index, section in
            TaskSectionView(
                project: section.project,
                tasks: section.tasks,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                completedCollapsed: isCompletedCollapsedBySection[section.project.id],
                isTaskDragEnabled: isTaskDragEnabled,
                highlightedTaskID: highlightedTaskID,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[section.project.id] = collapsed
                    onCompletedSectionToggle?(section.project.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted
            )
            .onDrag {
                draggingCustomProjectID = section.project.id
                return NSItemProvider(object: section.project.id.uuidString as NSString)
            }
            .onDrop(
                of: ["public.text"],
                delegate: CustomProjectSectionDropDelegate(
                    targetProjectID: section.project.id,
                    draggedProjectID: $draggingCustomProjectID,
                    currentCustomOrder: currentCustomOrder,
                    onReorder: { reordered in
                        onReorderCustomProjects?(reordered)
                    }
                )
            )
        }
    }

    @ViewBuilder
    private var legacyRegularTaskContent: some View {
        if !overdueTasks.isEmpty {
            TaskSectionView(
                project: overdueProject,
                tasks: overdueTasks,
                isOverdueSection: true,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                completedCollapsed: isCompletedCollapsedBySection[overdueProject.id],
                isTaskDragEnabled: isTaskDragEnabled,
                highlightedTaskID: highlightedTaskID,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[overdueProject.id] = collapsed
                    onCompletedSectionToggle?(overdueProject.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted,
                headerActionTitle: overdueHeaderActionTitle,
                onHeaderAction: onOverdueHeaderAction,
                headerActionAccessibilityID: "home.overdue.headerAction"
            )
        }

        ForEach(Array(legacySortedProjectSections.enumerated()), id: \.element.id) { index, section in
            TaskSectionView(
                project: section.project,
                tasks: section.tasks,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                completedCollapsed: isCompletedCollapsedBySection[section.project.id],
                isTaskDragEnabled: isTaskDragEnabled,
                highlightedTaskID: highlightedTaskID,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[section.project.id] = collapsed
                    onCompletedSectionToggle?(section.project.id, collapsed, count)
                },
                onTaskDragStarted: onTaskDragStarted
            )
        }
    }

    @ViewBuilder
    private var doneTimelineContent: some View {
        let grouped = groupedDoneTimeline

        ForEach(Array(grouped.enumerated()), id: \.element.id) { index, group in
            TaskSectionView(
                project: group.project,
                tasks: group.tasks,
                isOverdueSection: false,
                tagNameByID: tagNameByID,
                todayXPSoFar: todayXPSoFar,
                isGamificationV2Enabled: isGamificationV2Enabled,
                completedCollapsed: isCompletedCollapsedBySection[group.project.id],
                isTaskDragEnabled: false,
                highlightedTaskID: highlightedTaskID,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onCompletedCollapsedChange: { collapsed, count in
                    isCompletedCollapsedBySection[group.project.id] = collapsed
                    onCompletedSectionToggle?(group.project.id, collapsed, count)
                }
            )
        }
    }

    private var legacySortedProjectSections: [ProjectSection] {
        let allTasks = morningTasks + eveningTasks

        guard !allTasks.isEmpty else { return [] }

        // Group by projectID
        let grouped = Dictionary(grouping: allTasks, by: \.projectID)

        // Map to sections with project metadata
        var sections: [ProjectSection] = grouped.map { projectID, tasks in
            let taskProjectName = normalizedTaskProjectName(from: tasks)
            let project: Project

            if let projectByID = projects.first(where: { $0.id == projectID }) {
                project = projectByID
            } else if let taskProjectName,
                      let projectByName = projects.first(where: { $0.name.caseInsensitiveCompare(taskProjectName) == .orderedSame }) {
                project = projectByName
            } else if let taskProjectName {
                project = Project(
                    id: projectID,
                    name: taskProjectName,
                    icon: taskProjectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame ? .inbox : .folder
                )
            } else {
                project = Project(id: projectID, name: "Uncategorized", icon: .folder)
            }
            return ProjectSection(project: project, tasks: tasks)
        }

        // Sort: Inbox first, then alphabetical by name
        sections.sort { s1, s2 in
            let s1Inbox = isInboxSection(s1.project)
            let s2Inbox = isInboxSection(s2.project)
            if s1Inbox { return true }
            if s2Inbox { return false }
            return s1.project.name.localizedCaseInsensitiveCompare(s2.project.name) == .orderedAscending
        }

        return sections
    }

    private var groupedDoneTimeline: [ProjectSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: doneTimelineTasks) { task -> Date in
            let completionDate = task.dateCompleted ?? Date.distantPast
            return calendar.startOfDay(for: completionDate)
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return grouped.keys.sorted(by: >).map { day in
            let dayTasks = (grouped[day] ?? []).sorted { lhs, rhs in
                if lhs.priority.scorePoints != rhs.priority.scorePoints {
                    return lhs.priority.scorePoints > rhs.priority.scorePoints
                }
                let lhsCompletion = lhs.dateCompleted ?? Date.distantPast
                let rhsCompletion = rhs.dateCompleted ?? Date.distantPast
                return lhsCompletion > rhsCompletion
            }

            let project = Project(
                id: UUID(),
                name: formatter.string(from: day),
                icon: .folder
            )
            return ProjectSection(project: project, tasks: dayTasks)
        }
    }

    private var allTasksEmpty: Bool {
        if activeQuickView == .done {
            return doneTimelineTasks.isEmpty
        }

        return morningTasks.isEmpty && eveningTasks.isEmpty && overdueTasks.isEmpty
    }

    /// Executes normalizedTaskProjectName.
    private func normalizedTaskProjectName(from tasks: [TaskDefinition]) -> String? {
        tasks
            .compactMap { $0.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    /// Executes isInboxSection.
    private func isInboxSection(_ project: Project) -> Bool {
        project.isInbox || project.name.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    /// Synthetic project for the overdue section header
    private var overdueProject: Project {
        Project(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            name: "Overdue",
            icon: .flag
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: TaskerTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.5))
                .breathingPulse(min: 0.4, max: 0.6, duration: 3.0)

            Text("All clear")
                .font(.tasker(.title3))
                .foregroundColor(Color.tasker.textTertiary)

            Text(resolvedEmptyStateMessage)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textQuaternary)

            if let title = emptyStateActionTitle {
                Button(title) {
                    onEmptyStateAction?()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.tasker.accentPrimary)
                .padding(.top, TaskerTheme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TaskerTheme.Spacing.xxxl)
    }

    private var resolvedEmptyStateMessage: String {
        if let emptyStateMessage {
            return emptyStateMessage
        }

        switch activeQuickView {
        case .upcoming:
            return "No upcoming tasks in 14 days"
        case .overdue:
            return "No overdue tasks"
        case .done:
            return "No completed tasks in last 30 days"
        case .morning:
            return "No morning tasks. Add one to start strong."
        case .evening:
            return "No evening tasks. Plan your wind-down."
        case .today, .none:
            return "No tasks for today"
        }
    }
}

// MARK: - Project Section Model

private struct ProjectSection: Identifiable {
    let project: Project
    let tasks: [TaskDefinition]
    var id: UUID { project.id }
}

private struct OverdueGroupedSectionView: View {
    let groups: [HomeTaskOverdueGroup]
    let tagNameByID: [UUID: String]
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool
    let isTaskDragEnabled: Bool
    var headerActionTitle: String?
    var onHeaderAction: (() -> Void)?
    var onTaskTap: ((TaskDefinition) -> Void)?
    var onToggleComplete: ((TaskDefinition) -> Void)?
    var onDeleteTask: ((TaskDefinition) -> Void)?
    var onRescheduleTask: ((TaskDefinition) -> Void)?
    var onTaskDragStarted: ((TaskDefinition) -> Void)?
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
            TaskSectionHeaderRow(
                accentColor: Color.tasker(.taskOverdue),
                iconSystemName: "exclamationmark.triangle.fill",
                title: "Overdue",
                taskCount: totalTaskCount,
                isExpanded: isExpanded,
                onToggle: {
                    withAnimation(TaskerAnimation.snappy) {
                        isExpanded.toggle()
                    }
                    TaskerFeedback.selection()
                },
                headerActionTitle: headerActionTitle,
                onHeaderAction: onHeaderAction,
                headerActionAccessibilityID: "home.overdue.grouped.headerAction"
            )

            if isExpanded {
                ForEach(Array(groups.enumerated()), id: \.element.project.id) { index, group in
                    VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
                        Text(group.project.name)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .padding(.top, index == 0 ? 0 : TaskerTheme.Spacing.sm)

                        ForEach(Array(group.tasks.enumerated()), id: \.element.id) { taskIndex, task in
                            TaskRowView(
                                task: task,
                                showTypeBadge: false,
                                isInOverdueSection: true,
                                tagNameByID: tagNameByID,
                                todayXPSoFar: todayXPSoFar,
                                isGamificationV2Enabled: isGamificationV2Enabled,
                                isTaskDragEnabled: isTaskDragEnabled,
                                onTap: { onTaskTap?(task) },
                                onToggleComplete: { onToggleComplete?(task) },
                                onDelete: { onDeleteTask?(task) },
                                onReschedule: { onRescheduleTask?(task) },
                                onTaskDragStarted: onTaskDragStarted
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }

    private var totalTaskCount: Int {
        groups.reduce(0) { $0 + $1.tasks.count }
    }
}

private struct CustomProjectSectionDropDelegate: DropDelegate {
    let targetProjectID: UUID
    @Binding var draggedProjectID: UUID?
    let currentCustomOrder: [UUID]
    let onReorder: ([UUID]) -> Void

    /// Executes dropEntered.
    func dropEntered(info: DropInfo) {
        guard let draggedProjectID, draggedProjectID != targetProjectID else { return }
        guard let fromIndex = currentCustomOrder.firstIndex(of: draggedProjectID),
              let toIndex = currentCustomOrder.firstIndex(of: targetProjectID),
              fromIndex != toIndex else { return }

        var reordered = currentCustomOrder
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)
        onReorder(reordered)
        self.draggedProjectID = targetProjectID
    }

    /// Executes performDrop.
    func performDrop(info: DropInfo) -> Bool {
        draggedProjectID = nil
        return true
    }

    /// Executes dropUpdated.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Preview

#if DEBUG
struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        let inboxProject = Project.createInbox()
        let workProject = Project(name: "Work", icon: .work)
        let sideProject = Project(name: "Side Project", icon: .creative)

        TaskListView(
            morningTasks: [
                TaskDefinition(
                    title: "Morning standup call with the engineering team",
                    details: "Discuss sprint priorities and blockers",
                    priority: .high,
                    type: .morning,
                    dueDate: Date()
                ),
                TaskDefinition(
                    projectID: workProject.id,
                    title: "Review quarterly OKRs and prepare status updates for leadership review",
                    priority: .max,
                    type: .morning,
                    dueDate: Date()
                ),
                TaskDefinition(
                    projectID: sideProject.id,
                    title: "Design landing page wireframes",
                    details: "Focus on mobile-first layout with clear CTA hierarchy",
                    priority: .low,
                    type: .morning,
                    dueDate: Date().addingTimeInterval(86400)
                )
            ],
            eveningTasks: [
                TaskDefinition(
                    title: "Evening reading — Atomic Habits chapter 4",
                    priority: .none,
                    type: .evening
                ),
                TaskDefinition(
                    projectID: workProject.id,
                    title: "Write weekly retrospective notes",
                    details: "Include wins, challenges, and next week goals",
                    priority: .low,
                    type: .evening,
                    dueDate: Date()
                )
            ],
            overdueTasks: [
                TaskDefinition(
                    title: "Submit expense report for January travel",
                    priority: .max,
                    type: .morning,
                    dueDate: Date().addingTimeInterval(-172800)
                )
            ],
            projects: [inboxProject, workProject, sideProject]
        )
        .background(Color.tasker.bgCanvas)
    }
}
#endif

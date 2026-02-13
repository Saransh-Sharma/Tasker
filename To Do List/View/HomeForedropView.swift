//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI

struct HomeBackdropForedropRootView: View {
    @ObservedObject var viewModel: HomeViewModel

    let onTaskTap: (DomainTask) -> Void
    let onToggleComplete: (DomainTask) -> Void
    let onDeleteTask: (DomainTask) -> Void
    let onRescheduleTask: (DomainTask) -> Void
    let onReorderCustomProjects: ([UUID]) -> Void
    let onAddTask: () -> Void
    let onOpenSearch: () -> Void
    let onOpenChat: () -> Void
    let onOpenSettings: () -> Void

    @State private var isBackdropRevealed = false
    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                backdropLayer(geometry: geometry)

                foredropLayer(geometry: geometry)
                    .offset(y: isBackdropRevealed ? 228 : 86)
                    .animation(TaskerAnimation.snappy, value: isBackdropRevealed)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onEnded { value in
                                if value.translation.height > 40 {
                                    withAnimation(TaskerAnimation.snappy) {
                                        isBackdropRevealed = true
                                    }
                                } else if value.translation.height < -40 {
                                    withAnimation(TaskerAnimation.snappy) {
                                        isBackdropRevealed = false
                                    }
                                }
                            }
                    )
            }
            .background(Color.tasker.bgCanvas)
            .sheet(isPresented: $showDatePicker) {
                NavigationView {
                    VStack(spacing: spacing.s16) {
                        DatePicker(
                            "Select date",
                            selection: $draftDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, spacing.s16)

                        HStack(spacing: spacing.s12) {
                            Button("Today") {
                                draftDate = Date()
                                viewModel.selectDate(Date())
                                showDatePicker = false
                            }
                            .buttonStyle(.bordered)

                            Button("Apply") {
                                viewModel.selectDate(draftDate)
                                showDatePicker = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .navigationTitle("Date")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showDatePicker = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAdvancedFilters) {
                HomeAdvancedFilterSheetView(
                    initialFilter: viewModel.activeFilterState.advancedFilter,
                    initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
                    savedViews: viewModel.savedHomeViews,
                    activeSavedViewID: viewModel.activeFilterState.selectedSavedViewID,
                    onApply: { filter, showCompletedInline in
                        viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                    },
                    onClear: {
                        viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                        viewModel.clearProjectFilters()
                        viewModel.setQuickView(.today)
                    },
                    onSaveNamedView: { filter, showCompletedInline, name in
                        viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                        viewModel.saveCurrentFilterAsView(name: name)
                    },
                    onApplySavedView: { id in
                        viewModel.applySavedView(id: id)
                    },
                    onDeleteSavedView: { id in
                        viewModel.deleteSavedView(id: id)
                    }
                )
            }
        }
    }

    private func backdropLayer(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker.accentPrimary.opacity(0.24),
                            Color.tasker.bgCanvas
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: max(320, geometry.size.height * 0.42))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        Text("Analytics")
                            .font(.tasker(.headline))
                            .foregroundColor(Color.tasker.textPrimary)

                        ChartCardsScrollView(referenceDate: viewModel.selectedDate)
                            .frame(height: 260)

                        VStack(alignment: .leading, spacing: spacing.s8) {
                            Text("Quick Actions")
                                .font(.tasker(.headline))
                                .foregroundColor(Color.tasker.textPrimary)

                            HStack(spacing: spacing.s8) {
                                launcherCard(
                                    title: "Search",
                                    systemImage: "magnifyingglass",
                                    accessibilityID: "home.launch.search",
                                    action: onOpenSearch
                                )
                                launcherCard(
                                    title: "Add Task",
                                    systemImage: "plus.circle.fill",
                                    accessibilityID: "home.launch.addTask",
                                    action: onAddTask
                                )
                                launcherCard(
                                    title: "Chat",
                                    systemImage: "bubble.left.and.bubble.right",
                                    accessibilityID: "home.launch.chat",
                                    action: onOpenChat
                                )
                            }
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s16)
                    .opacity(isBackdropRevealed ? 1 : 0.001)
                }
            Spacer(minLength: 0)
        }
    }

    private func foredropLayer(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            handleBar
                .padding(.top, spacing.s8)

            homeHeader
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)

            filterRails
                .padding(.top, spacing.s8)

            TaskListView(
                morningTasks: viewModel.morningTasks,
                eveningTasks: viewModel.eveningTasks,
                overdueTasks: viewModel.overdueTasks,
                inlineCompletedTasks: viewModel.activeScope.quickView == .today ? viewModel.completedTasks : [],
                projects: viewModel.projects,
                doneTimelineTasks: viewModel.doneTimelineTasks,
                activeQuickView: viewModel.activeScope.quickView,
                projectGroupingMode: viewModel.activeFilterState.projectGroupingMode,
                customProjectOrderIDs: viewModel.activeFilterState.customProjectOrderIDs,
                emptyStateMessage: viewModel.emptyStateMessage,
                emptyStateActionTitle: viewModel.emptyStateActionTitle,
                onTaskTap: onTaskTap,
                onToggleComplete: onToggleComplete,
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onReorderCustomProjects: onReorderCustomProjects,
                onEmptyStateAction: onAddTask
            )
            .padding(.top, spacing.s8)

            foredropBottomBar
                .padding(.horizontal, spacing.s16)
                .padding(.vertical, spacing.s12)
                .background(Color.tasker.surfacePrimary.opacity(0.98))
        }
        .frame(
            width: geometry.size.width,
            height: geometry.size.height - 58,
            alignment: .top
        )
        .background(
            RoundedRectangle(cornerRadius: corner.modal, style: .continuous)
                .fill(Color.tasker.surfacePrimary)
                .taskerElevation(.e2, cornerRadius: corner.modal, includesBorder: false)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner.modal, style: .continuous))
    }

    private var handleBar: some View {
        Capsule()
            .fill(Color.tasker.textQuaternary.opacity(0.4))
            .frame(width: 44, height: 5)
            .accessibilityIdentifier("home.foredrop.handle")
    }

    private var homeHeader: some View {
        HStack(spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(headerTitle)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)
                if viewModel.pointsPotential > 0 {
                    Text("Potential \(viewModel.pointsPotential) pts")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }
            }

            Spacer()

            Button {
                draftDate = viewModel.selectedDate
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.bordered)

            Button {
                showAdvancedFilters = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.bordered)

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
        }
    }

    private var filterRails: some View {
        VStack(spacing: spacing.s8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    ForEach(HomeQuickView.allCases, id: \.rawValue) { quickView in
                        let count = viewModel.quickViewCounts[quickView] ?? 0
                        TaskerChip(
                            title: "\(quickView.title) \(count)",
                            isSelected: viewModel.activeScope.quickView == quickView,
                            selectedStyle: .filled
                        ) {
                            viewModel.setQuickView(quickView)
                        }
                    }
                }
                .padding(.horizontal, spacing.s16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    let selectedProjectIDs = Set(viewModel.activeFilterState.selectedProjectIDs)
                    let pinned = viewModel.projects.filter { viewModel.activeFilterState.pinnedProjectIDSet.contains($0.id) }
                    ForEach(pinned, id: \.id) { project in
                        TaskerChip(
                            title: project.name,
                            isSelected: selectedProjectIDs.contains(project.id),
                            selectedStyle: .tinted
                        ) {
                            viewModel.toggleProjectFilter(project.id)
                        }
                    }
                    TaskerChip(
                        title: selectedProjectIDs.isEmpty ? "All Projects ✓" : "All Projects",
                        isSelected: selectedProjectIDs.isEmpty,
                        selectedStyle: .tinted
                    ) {
                        viewModel.clearProjectFilters()
                    }
                }
                .padding(.horizontal, spacing.s16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    TaskerChip(
                        title: HomeProjectGroupingMode.prioritizeOverdue.title,
                        isSelected: viewModel.activeFilterState.projectGroupingMode == .prioritizeOverdue,
                        selectedStyle: .tinted
                    ) {
                        viewModel.setProjectGroupingMode(.prioritizeOverdue)
                    }
                    TaskerChip(
                        title: HomeProjectGroupingMode.groupByProjects.title,
                        isSelected: viewModel.activeFilterState.projectGroupingMode == .groupByProjects,
                        selectedStyle: .tinted
                    ) {
                        viewModel.setProjectGroupingMode(.groupByProjects)
                    }
                }
                .padding(.horizontal, spacing.s16)
            }
        }
    }

    private var foredropBottomBar: some View {
        HStack(spacing: spacing.s12) {
            Button {
                withAnimation(TaskerAnimation.snappy) {
                    isBackdropRevealed.toggle()
                }
            } label: {
                Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("home.foredrop.chartsToggle")

            Button {
                onOpenSearch()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)

            Button {
                onOpenChat()
            } label: {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                onAddTask()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 42, height: 42)
                    .foregroundColor(Color.tasker.accentOnPrimary)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("home.addTaskButton")
        }
    }

    private func launcherCard(
        title: String,
        systemImage: String,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Image(systemName: systemImage)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.accentPrimary)
                Text(title)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                    .fill(Color.tasker.surfacePrimary.opacity(0.96))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }

    private var headerTitle: String {
        switch viewModel.activeScope {
        case .today:
            return "Today"
        case .customDate(let date):
            return Self.dateFormatter.string(from: date)
        case .upcoming:
            return "Upcoming"
        case .done:
            return "Done"
        case .morning:
            return "Morning"
        case .evening:
            return "Evening"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()
}

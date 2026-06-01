//
//  HomeiPadShell.swift
//  LifeBoard
//
//  iPad split-shell support for the Home surface.
//

import Combine
import SwiftUI

enum HomeiPadDestination: String, CaseIterable, Identifiable {
    case tasks
    case schedule
    case search
    case analytics
    case addTask
    case settings
    case lifeManagement
    case projects
    case chat
    case models

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "Tasks"
        case .schedule: return "Schedule"
        case .search: return "Search"
        case .analytics: return "Analytics"
        case .addTask: return "Add Task"
        case .settings: return "Settings"
        case .lifeManagement: return "Life Management"
        case .projects: return "Projects"
        case .chat: return AssistantIdentityText.currentSnapshot().displayName
        case .models: return "Models"
        }
    }

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .schedule: return "calendar.badge.clock"
        case .search: return "magnifyingglass"
        case .analytics: return "chart.bar.xaxis"
        case .addTask: return "plus.circle"
        case .settings: return "gearshape"
        case .lifeManagement: return "square.grid.2x2"
        case .projects: return "folder"
        case .chat: return "sparkles"
        case .models: return "cpu"
        }
    }

    var homeFace: HomeSunriseFace? {
        switch self {
        case .tasks: return .tasks
        case .schedule: return .schedule
        case .search: return .search
        case .analytics: return .analytics
        case .chat: return .chat
        case .addTask, .settings, .lifeManagement, .projects, .models: return nil
        }
    }

    var isPrimaryHomeDestination: Bool {
        homeFace != nil
    }
}

@MainActor
enum HomeiPadModalRequest: Equatable {
    case addTask
}

@MainActor
final class HomeiPadShellState: ObservableObject {
    @Published var destination: HomeiPadDestination = .tasks
    @Published var selectedTask: TaskDefinition?
    @Published var modalRequest: HomeiPadModalRequest?
}

// MARK: - iPad Sidebar Sections

enum HomeiPadSidebarSection: String, CaseIterable, Identifiable {
    case primary
    case create
    case manage

    var id: String { rawValue }

    var title: String? {
        switch self {
        case .primary: return nil
        case .create: return "Create"
        case .manage: return "Manage"
        }
    }

    var destinations: [HomeiPadDestination] {
        switch self {
        case .primary: return [.tasks, .schedule, .chat, .analytics]
        case .create: return [.addTask]
        case .manage: return [.lifeManagement, .projects, .models, .settings]
        }
    }
}

@MainActor
final class HomeiPadPrimarySurfaceMonitor: ObservableObject {
    private var baselineShellEpoch: Int?
    private var baselineHostID: UUID?

    func recordAppearance(hostID: UUID, destination: HomeiPadDestination, shellEpoch: Int) {
        if baselineShellEpoch != shellEpoch {
            if let previousEpoch = baselineShellEpoch {
                logWarning(
                    event: "ipadPrimarySurfaceShellEpochReset",
                    message: "Reset the iPad primary surface host baseline after an expected shell rebuild",
                    fields: [
                        "destination": destination.rawValue,
                        "previous_epoch": String(previousEpoch),
                        "next_epoch": String(shellEpoch)
                    ]
                )
            }

            baselineShellEpoch = shellEpoch
            baselineHostID = hostID
            logWarning(
                event: "ipadPrimarySurfaceMounted",
                message: "Mounted the persistent iPad primary surface host",
                fields: [
                    "destination": destination.rawValue,
                    "shell_epoch": String(shellEpoch)
                ]
            )
            return
        }

        if let baselineHostID {
            if baselineHostID != hostID {
                logWarning(
                    event: "ipadPrimarySurfaceHostRemounted",
                    message: "The iPad primary surface host was remounted",
                    fields: [
                        "destination": destination.rawValue,
                        "shell_epoch": String(shellEpoch)
                    ]
                )
                self.baselineHostID = hostID
                return
            }

            logWarning(
                event: "ipadPrimarySurfaceReused",
                message: "Reused the persistent iPad primary surface host",
                fields: [
                    "destination": destination.rawValue,
                    "shell_epoch": String(shellEpoch)
                ]
            )
            return
        }

        baselineShellEpoch = shellEpoch
        baselineHostID = hostID
        logWarning(
            event: "ipadPrimarySurfaceMounted",
            message: "Mounted the persistent iPad primary surface host",
            fields: [
                "destination": destination.rawValue,
                "shell_epoch": String(shellEpoch)
            ]
        )
    }
}

@MainActor
private final class HomeiPadPrimaryPaneLifecycle: ObservableObject {
    let id = UUID()
}

// MARK: - iPad Split Shell

private struct HomeiPadPrimaryPaneHost: View {
    @Binding var activeFace: HomeSunriseFace
    let layoutClass: LifeBoardLayoutClass
    let destination: HomeiPadDestination
    let shellEpoch: Int
    let homeSurface: (Binding<HomeSunriseFace>) -> AnyView
    @ObservedObject var monitor: HomeiPadPrimarySurfaceMonitor
    @StateObject private var lifecycle = HomeiPadPrimaryPaneLifecycle()

    var body: some View {
        homeSurface($activeFace)
            .accessibilityIdentifier("home.ipad.detail.\(destination.rawValue)")
            .onAppear {
                guard layoutClass.isPad, V2FeatureFlags.iPadPerfPrimarySurfacePersistenceV3Enabled else { return }
                monitor.recordAppearance(hostID: lifecycle.id, destination: destination, shellEpoch: shellEpoch)
            }
    }
}

struct SunriseiPadSplitShellView: View {
    private enum HomeiPadShellCommand {
        case tasks
        case schedule
        case search
        case analytics
        case chat
        case addTask
        case settings
        case dismiss
    }

    let layoutClass: LifeBoardLayoutClass
    @ObservedObject var shellState: HomeiPadShellState
    let shellEpoch: Int
    let homeSurface: (Binding<HomeSunriseFace>) -> AnyView
    let addTaskSurface: () -> AnyView
    let scheduleSurface: () -> AnyView
    let settingsSurface: () -> AnyView
    let lifeManagementSurface: () -> AnyView
    let projectsSurface: () -> AnyView
    let chatSurface: () -> AnyView
    let modelsSurface: () -> AnyView
    let inspectorSurface: (TaskDefinition) -> AnyView
    let onOpenTaskDetailSheet: (TaskDefinition) -> Void

    @State private var activeHomeFace: HomeSunriseFace = .tasks
    @State private var showCompactSidebar = false
    @State private var showHabitLibrarySheet = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var primarySurfaceMonitor = HomeiPadPrimarySurfaceMonitor()

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var isPrimaryHomeDestination: Bool {
        shellState.destination.isPrimaryHomeDestination
    }

    private var showsPrimaryHomeTaskToolbarItems: Bool {
        switch shellState.destination {
        case .tasks, .search, .analytics:
            return true
        case .schedule, .chat, .addTask, .settings, .lifeManagement, .projects, .models:
            return false
        }
    }

    var body: some View {
        shellLayout
            .accessibilityIdentifier("home.ipad.shell")
            .background {
                hiddenKeyboardShortcuts
            }
            .sheet(isPresented: $showHabitLibrarySheet) {
                SunriseHabitLibraryView(
                    viewModel: PresentationDependencyContainer.shared.makeNewHabitLibraryViewModel()
                )
            }
            .onAppear {
                if let face = shellState.destination.homeFace {
                    activeHomeFace = face
                }
            }
        .onChange(of: shellState.destination) { _, newValue in
            if newValue.isPrimaryHomeDestination {
                logWarning(
                    event: "ipadPrimaryDestinationSwitchStart",
                    message: "Switched iPad primary destination",
                    fields: ["destination": newValue.rawValue]
                )
            }
            if newValue == .addTask, layoutClass != .padExpanded {
                shellState.modalRequest = .addTask
                shellState.destination = .tasks
                return
            }
            if let face = newValue.homeFace {
                activeHomeFace = face
            } else {
                shellState.selectedTask = nil
            }
        }
        .onChange(of: activeHomeFace) {
            handleActiveHomeFaceChange()
        }
    }

    @ViewBuilder
    private var shellLayout: some View {
        if layoutClass == .padCompact {
            compactShell
        } else if layoutClass == .padExpanded {
            expandedShell
        } else {
            regularShell
        }
    }

    private var compactShell: some View {
        NavigationStack {
            detailContent
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        compactSidebarToggle
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
        }
        .sheet(isPresented: $showCompactSidebar) {
            compactSidebarSheet
        }
    }

    private var expandedShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } content: {
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
                .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: .infinity)
        } detail: {
            inspectorPanel
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
                .background(Color.lifeboard.bgElevated)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var regularShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        detailToolbarItems
                    }
                }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }

    private var hiddenKeyboardShortcuts: some View {
        Group {
            Button("") { performShellCommand(.search) }
                .keyboardShortcut("f", modifiers: .command)
            Button("") { performShellCommand(.tasks) }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { performShellCommand(.schedule) }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { performShellCommand(.analytics) }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { performShellCommand(.chat) }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { performShellCommand(.addTask) }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { performShellCommand(.settings) }
                .keyboardShortcut(",", modifiers: .command)
            Button("") { performShellCommand(.dismiss) }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
    }

    private func analyticsName(for face: HomeSunriseFace) -> String {
        switch face {
        case .tasks:
            return "tasks"
        case .schedule:
            return "schedule"
        case .analytics:
            return "analytics"
        case .search:
            return "search"
        case .chat:
            return "chat"
        }
    }

    private func handleActiveHomeFaceChange() {
        let newValue = activeHomeFace
        if layoutClass.isPad && V2FeatureFlags.iPadPerfPrimarySurfacePersistenceV3Enabled {
            logWarning(
                event: "ipadPrimaryDestinationSwitchEnd",
                message: "Completed iPad primary destination switch",
                fields: ["face": analyticsName(for: newValue)]
            )
        }
        let nextDestination = destination(for: newValue)
        if shellState.destination != nextDestination {
            shellState.destination = nextDestination
        }
    }

    // MARK: - Toolbar Items

    @ViewBuilder
    private var detailToolbarItems: some View {
        if showsPrimaryHomeTaskToolbarItems {
            Button {
                showHabitLibrarySheet = true
            } label: {
                Image(systemName: "repeat.circle")
            }
            .hoverEffect(.highlight)
            .accessibilityIdentifier("home.ipad.toolbar.manageHabits")
            .accessibilityLabel("Manage Habits")

            Button {
                performShellCommand(.addTask)
            } label: {
                Image(systemName: "plus")
            }
            .hoverEffect(.highlight)
            .accessibilityIdentifier("home.ipad.toolbar.addTask")
            .accessibilityLabel("New Task")
        }
    }

    // MARK: - Compact Sidebar Toggle

    private var compactSidebarToggle: some View {
        Button {
            showCompactSidebar = true
        } label: {
            Label(shellState.destination.title, systemImage: "sidebar.left")
                .labelStyle(.titleAndIcon)
                .frame(minWidth: 44, minHeight: 44)
        }
        .hoverEffect(.highlight)
        .accessibilityIdentifier("home.ipad.sidebar.toggle")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: Binding<HomeiPadDestination?>(
            get: { shellState.destination },
            set: { newValue in
                if let newValue { shellState.destination = newValue }
            }
        )) {
            ForEach(HomeiPadSidebarSection.allCases) { section in
                Section {
                    ForEach(section.destinations) { dest in
                        Label(dest.title, systemImage: dest.icon)
                            .tag(dest)
                            .hoverEffect(.highlight)
                            .accessibilityIdentifier("home.ipad.destination.\(dest.rawValue)")
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.lifeboard.bgCanvas)
        .navigationTitle("LifeBoard")
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .accessibilityIdentifier("home.ipad.sidebar")
    }

    private var sidebarFooter: some View {
        VStack(spacing: spacing.s4) {
            Divider()
            Text("LifeBoard v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textQuaternary)
                .padding(.vertical, spacing.s8)
        }
        .padding(.horizontal, spacing.s16)
    }

    // MARK: - Compact Sidebar Sheet

    private var compactSidebarSheet: some View {
        NavigationStack {
            List {
                ForEach(HomeiPadSidebarSection.allCases) { section in
                    Section {
                        ForEach(section.destinations) { dest in
                            Button {
                                shellState.destination = dest
                                showCompactSidebar = false
                            } label: {
                                Label(dest.title, systemImage: dest.icon)
                            }
                            .hoverEffect(.highlight)
                            .accessibilityIdentifier("home.ipad.compact.destination.\(dest.rawValue)")
                        }
                    } header: {
                        if let title = section.title {
                            Text(title)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Navigate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showCompactSidebar = false
                    }
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        switch shellState.destination {
        case .tasks, .search, .analytics, .chat:
            HomeiPadPrimaryPaneHost(
                activeFace: $activeHomeFace,
                layoutClass: layoutClass,
                destination: shellState.destination,
                shellEpoch: shellEpoch,
                homeSurface: homeSurface,
                monitor: primarySurfaceMonitor
            )
        case .schedule:
            scheduleSurface()
                .accessibilityIdentifier("home.ipad.detail.schedule")
        case .addTask:
            if layoutClass == .padExpanded {
                addTaskSurface()
                    .accessibilityIdentifier("home.ipad.detail.addTask")
            } else {
                HomeiPadPrimaryPaneHost(
                    activeFace: $activeHomeFace,
                    layoutClass: layoutClass,
                    destination: .tasks,
                    shellEpoch: shellEpoch,
                    homeSurface: homeSurface,
                    monitor: primarySurfaceMonitor
                )
            }
        case .settings:
            settingsSurface()
                .accessibilityIdentifier("home.ipad.detail.settings")
        case .lifeManagement:
            lifeManagementSurface()
                .accessibilityIdentifier("home.ipad.detail.lifeManagement")
        case .projects:
            projectsSurface()
                .accessibilityIdentifier("home.ipad.detail.projects")
        case .models:
            modelsSurface()
                .accessibilityIdentifier("home.ipad.detail.models")
        }
    }

    // MARK: - Inspector Panel

    @ViewBuilder
    private var inspectorPanel: some View {
        if let task = shellState.selectedTask {
            NavigationStack {
                inspectorSurface(task)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text(task.title)
                                .font(.lifeboard(.headline))
                                .foregroundColor(Color.lifeboard.textPrimary)
                                .lineLimit(1)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                onOpenTaskDetailSheet(task)
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .hoverEffect(.highlight)
                            .accessibilityLabel("Expand to sheet")
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .id(task.id)
            .accessibilityIdentifier("home.ipad.inspector.task")
        } else {
            VStack(spacing: spacing.s16) {
                Image(systemName: "rectangle.righthalf.inset.filled")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(Color.lifeboard.accentMuted)
                Text("No task selected")
                    .font(.lifeboard(.title3))
                    .foregroundColor(Color.lifeboard.textSecondary)
                Text("Tap a task in the list to see its details here.")
                    .font(.lifeboard(.body))
                    .foregroundColor(Color.lifeboard.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lifeboard.bgCanvas)
            .accessibilityIdentifier("home.ipad.inspector.empty")
        }
    }

    private func destination(for face: HomeSunriseFace) -> HomeiPadDestination {
        switch face {
        case .tasks:
            return .tasks
        case .schedule:
            return .schedule
        case .analytics:
            return .analytics
        case .search:
            return .search
        case .chat:
            return .chat
        }
    }

    private func performShellCommand(_ command: HomeiPadShellCommand) {
        switch command {
        case .tasks:
            shellState.destination = .tasks
        case .schedule:
            shellState.destination = .schedule
        case .search:
            shellState.destination = .search
        case .analytics:
            shellState.destination = .analytics
        case .chat:
            shellState.destination = .chat
        case .addTask:
            if layoutClass == .padExpanded {
                shellState.destination = .addTask
            } else {
                shellState.modalRequest = .addTask
            }
        case .settings:
            shellState.destination = .settings
        case .dismiss:
            if shellState.selectedTask != nil {
                shellState.selectedTask = nil
            } else if shellState.destination != .tasks {
                shellState.destination = .tasks
            } else {
                showCompactSidebar = false
            }
        }
    }
}

struct HomeiPadSettingsContainer: View {
    let onNavigateToLifeManagement: () -> Void
    let onNavigateToChats: () -> Void
    let onNavigateToModels: () -> Void
    let onRestartOnboarding: () -> Void
    let onOpenCalendarChooser: () -> Void

    @StateObject private var viewModel: SettingsViewModel

    init(
        onNavigateToLifeManagement: @escaping () -> Void,
        onNavigateToChats: @escaping () -> Void,
        onNavigateToModels: @escaping () -> Void,
        onRestartOnboarding: @escaping () -> Void,
        calendarIntegrationService: CalendarIntegrationService,
        onOpenCalendarChooser: @escaping () -> Void
    ) {
        self.onNavigateToLifeManagement = onNavigateToLifeManagement
        self.onNavigateToChats = onNavigateToChats
        self.onNavigateToModels = onNavigateToModels
        self.onRestartOnboarding = onRestartOnboarding
        self.onOpenCalendarChooser = onOpenCalendarChooser
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                calendarIntegrationService: calendarIntegrationService
            )
        )
    }

    var body: some View {
        NavigationStack {
            SettingsRootView(viewModel: viewModel)
                .onAppear {
                    viewModel.onNavigateToLifeManagement = onNavigateToLifeManagement
                    viewModel.onNavigateToChats = onNavigateToChats
                    viewModel.onNavigateToModels = onNavigateToModels
                    viewModel.onRestartOnboarding = onRestartOnboarding
                    viewModel.onOpenCalendarChooser = onOpenCalendarChooser
                }
        }
        .accessibilityIdentifier("home.ipad.detail.settings")
    }
}

import SwiftUI
import UIKit

/// The `backlog` lens of `PlanRootView`, lifted out of the root as a
/// `struct: View` so it gets its own `body` call — see the `-Onone` stack note
/// at the foot of `PlanRootView.swift`.
///
/// Every piece of filter state stays owned by the root and arrives here as a
/// `@Binding`. Moving the `@State` down would look tidier and would silently
/// change behaviour: the section is torn down when the lens switches away, so
/// locally-owned filters would reset on every visit.
struct PlanBacklogSection: View {
    let store: PlanStore
    let lens: PlanLens
    @Binding var showsTaskLibrary: Bool
    @Binding var backlogSearch: String
    @Binding var backlogContextFilter: BacklogContextFilter
    @Binding var backlogReadinessFilter: BacklogReadinessFilter
    @Binding var backlogEnergyFilter: BacklogEnergyFilter
    @Binding var backlogDurationFilter: BacklogDurationFilter
    @Binding var backlogProjectFilter: BacklogProjectFilter
    @Binding var selectedTaskIDs: Set<UUID>
    @Binding var pendingBacklogDeletionTaskIDs: Set<UUID>
    @Binding var showsBacklogDeletionConfirmation: Bool
    @Binding var pendingFocusSetup: FocusSetupContext?
    let onOpenTask: (UUID) -> Void

    var body: some View {
        // `LazyVStack`, not `VStack`: these rows were direct children of the
        // root's own `LazyVStack` and a backlog is unbounded, so eager layout
        // here would be a behaviour change, not just a restyle. The spacing is
        // restated because the parent's no longer reaches these children.
        LazyVStack(spacing: 16) {
            if let snapshot = store.backlogSnapshot {
                backlogControls
                if let undoState = store.backlogDeletionUndoState {
                    deletionUndoBanner(undoState)
                }
                if !selectedTaskIDs.isEmpty { bulkActionBar }
                ForEach(BacklogGroup.allCases, id: \.self) { group in
                    let values = filteredBacklogTasks(snapshot.groups[group] ?? [])
                    if !values.isEmpty {
                        PlanSectionHeader(title(group), systemImage: symbol(group))
                        ForEach(values) { task in
                            PlanTaskCard(
                                store: store,
                                task: task,
                                planned: task.metadata.planningDay != nil,
                                lens: lens,
                                selectedTaskIDs: $selectedTaskIDs,
                                pendingBacklogDeletionTaskIDs: $pendingBacklogDeletionTaskIDs,
                                showsBacklogDeletionConfirmation: $showsBacklogDeletionConfirmation,
                                pendingFocusSetup: $pendingFocusSetup,
                                onOpenTask: onOpenTask
                            )
                        }
                    }
                }
                if snapshot.groups.values.allSatisfy(\.isEmpty) {
                    PlanEmptyCard(
                        title: "Backlog clear",
                        detail: "Everything open has a home.",
                        symbol: "checkmark.seal"
                    )
                }
            }
        }
    }

    private var backlogControls: some View {
        VStack(spacing: 10) {
            Button {
                showsTaskLibrary = true
            } label: {
                HStack {
                    Label("Browse every task view", systemImage: "checklist")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens canonical Inbox, Today, Upcoming, Waiting, Someday, Completed, and All views")
            .accessibilityIdentifier("plan.taskLibrary.open")

            TextField("Search backlog", text: $backlogSearch)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("plan.backlog.search")
            ScrollView(.horizontal) {
                HStack {
                Menu(backlogContextFilter.rawValue) {
                    Picker("Context", selection: $backlogContextFilter) {
                        ForEach(BacklogContextFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogReadinessFilter.rawValue) {
                    Picker("Readiness", selection: $backlogReadinessFilter) {
                        ForEach(BacklogReadinessFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogEnergyFilter.rawValue) {
                    Picker("Energy", selection: $backlogEnergyFilter) {
                        ForEach(BacklogEnergyFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogDurationFilter.rawValue) {
                    Picker("Duration", selection: $backlogDurationFilter) {
                        ForEach(BacklogDurationFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogProjectFilter.rawValue) {
                    Picker("Project", selection: $backlogProjectFilter) {
                        ForEach(BacklogProjectFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                if !selectedTaskIDs.isEmpty {
                    Button("Clear") { selectedTaskIDs.removeAll() }
                }
                }
            }
            .scrollIndicators(.hidden)
            .font(.subheadline)
        }
        .padding(12)
        .background(Color(SemanticColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14))
    }

    private var bulkActionBar: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("\(selectedTaskIDs.count) selected").font(.subheadline.weight(.semibold))
            ScrollView(.horizontal) {
                HStack {
                    Button("Plan today", systemImage: "calendar") {
                        store.previewBulkPlan(
                            selectedTaskIDs,
                            on: PlanningDay(date: Date())
                        )
                        selectedTaskIDs.removeAll()
                    }
                    Button("Someday", systemImage: "sparkles") {
                        Task { await store.bulkUpdate(selectedTaskIDs, disposition: .someday); selectedTaskIDs.removeAll() }
                    }
                    Button("Waiting", systemImage: "hourglass") {
                        Task { await store.bulkUpdate(selectedTaskIDs, availability: .waiting); selectedTaskIDs.removeAll() }
                    }
                    Button("Paused", systemImage: "pause.circle") {
                        Task { await store.bulkUpdate(selectedTaskIDs, availability: .paused); selectedTaskIDs.removeAll() }
                    }
                    Button("Archive", systemImage: "archivebox") {
                        Task { await store.bulkUpdate(selectedTaskIDs, disposition: .archived); selectedTaskIDs.removeAll() }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingBacklogDeletionTaskIDs = selectedTaskIDs
                        showsBacklogDeletionConfirmation = true
                    }
                    Menu("Context", systemImage: "person.2") {
                        ForEach(PlanningContext.allCases, id: \.self) { context in
                            Button(context.rawValue.capitalized) {
                                Task { await store.bulkUpdate(selectedTaskIDs, context: context); selectedTaskIDs.removeAll() }
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .scrollIndicators(.hidden)
        }
        .padding(12)
        .background(Color(SemanticColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("plan.backlog.bulkActions")
    }

    private func deletionUndoBanner(_ state: BacklogDeletionUndoState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.slash.fill")
                .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.deletedCount) item\(state.deletedCount == 1 ? "" : "s") removed")
                    .font(.subheadline.weight(.semibold))
                Text("Deletion is synced as a reversible tombstone.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Button("Undo") { Task { await store.undoLastMutation() } }
                .buttonStyle(.bordered)
                .accessibilityHint("Restores the deleted backlog items exactly as they were")
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.backlog.deletionUndo")
    }

    private func title(_ group: BacklogGroup) -> String {
        switch group { case .thisWeek: "This Week"; case .nextWeek: "Next Week"; default: group.rawValue.capitalized }
    }

    private func symbol(_ group: BacklogGroup) -> String {
        switch group {
        case .inbox: "tray"; case .thisWeek: "calendar"; case .nextWeek: "calendar.badge.plus"
        case .later: "clock"; case .someday: "sparkles"; case .reference: "books.vertical"
        case .waiting: "hourglass"; case .paused: "pause.circle"; case .archived: "archivebox"
        }
    }

    private func filteredBacklogTasks(_ values: [PlanningTaskSummary]) -> [PlanningTaskSummary] {
        values.filter { task in
            let matchesSearch = backlogSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || task.title.localizedCaseInsensitiveContains(backlogSearch)
            let matchesContext: Bool
            switch backlogContextFilter {
            case .all: matchesContext = true
            case .work: matchesContext = task.metadata.planningContext == .work
            case .personal: matchesContext = task.metadata.planningContext == .personal
            case .neutral: matchesContext = task.metadata.planningContext == .neutral
            }
            let matchesReadiness: Bool
            switch backlogReadinessFilter {
            case .all: matchesReadiness = true
            case .ready: matchesReadiness = task.dependenciesReady
            case .blocked: matchesReadiness = !task.dependenciesReady
            case .estimateMissing: matchesReadiness = task.estimatedDuration == nil
            case .hasDeadline: matchesReadiness = task.dueDate != nil
            }
            let matchesEnergy: Bool
            switch backlogEnergyFilter {
            case .all: matchesEnergy = true
            case .low: matchesEnergy = task.requiredEnergy.map { $0 <= 2 } ?? false
            case .medium: matchesEnergy = task.requiredEnergy == 3
            case .high: matchesEnergy = task.requiredEnergy.map { $0 >= 4 } ?? false
            case .missing: matchesEnergy = task.requiredEnergy == nil
            }
            let matchesDuration: Bool
            switch backlogDurationFilter {
            case .all: matchesDuration = true
            case .quick: matchesDuration = task.estimatedDuration.map { $0 <= 15 * 60 } ?? false
            case .short: matchesDuration = task.estimatedDuration.map { $0 <= 30 * 60 } ?? false
            case .hour: matchesDuration = task.estimatedDuration.map { $0 <= 60 * 60 } ?? false
            case .long: matchesDuration = task.estimatedDuration.map { $0 > 60 * 60 } ?? false
            case .missing: matchesDuration = task.estimatedDuration == nil
            }
            let matchesProject: Bool
            switch backlogProjectFilter {
            case .all: matchesProject = true
            case .assigned: matchesProject = task.projectID != nil
            case .unassigned: matchesProject = task.projectID == nil
            }
            return matchesSearch && matchesContext && matchesReadiness && matchesEnergy && matchesDuration && matchesProject
        }
    }
}

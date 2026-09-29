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
    /// What the last bulk action did, with Undo. Bulk moves used to land in
    /// silence, and Archive took rows away with no way back from this screen.
    /// Keyed to the mutation it names, so Undo never reverses a later change.
    @State private var bulkReceipt: (receipt: PlanReceipt, mutationID: UUID)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                } else if let bulkReceipt, store.lastMutationReceiptID == bulkReceipt.mutationID {
                    bulkReceiptBar(bulkReceipt.receipt)
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
                            .lifeBoardScrollEntrance()
                        }
                    }
                }
                if snapshot.groups.values.allSatisfy(\.isEmpty) {
                    PlanEmptyCard(
                        title: String(localized: "Backlog clear"),
                        detail: nil,
                        symbol: "checkmark.seal"
                    )
                }
            } else {
                // Loading and empty are different states, and this branch is the
                // difference between "still reading" and "nothing here".
                PlanBacklogSkeleton()
            }
        }
    }

    private var backlogControls: some View {
        VStack(spacing: 12) {
            Button {
                showsTaskLibrary = true
            } label: {
                HStack {
                    Label("Task lists", systemImage: "checklist")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens all task lists")
            .accessibilityIdentifier("plan.taskLibrary.open")

            TextField("Search backlog", text: $backlogSearch, prompt: Text("Search backlog").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                .textFieldStyle(.plain)
                // Clay well, not the system rounded border: that drew a pure white
                // box on warm paper and a pure black one in dark appearance.
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
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
                Menu(backlogDurationFilter.title) {
                    Picker("Duration", selection: $backlogDurationFilter) {
                        ForEach(BacklogDurationFilter.allCases) { Text($0.title).tag($0) }
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
        .background(Color(SemanticColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
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
                    Button(DecisionDestination.someday.title, systemImage: DecisionDestination.someday.systemImage) {
                        runBulk("moved to Someday") { await store.bulkUpdate($0, disposition: .someday) }
                    }
                    Button("Waiting", systemImage: "hourglass") {
                        runBulk("marked waiting") { await store.bulkUpdate($0, availability: .waiting) }
                    }
                    Button("Paused", systemImage: "pause.circle") {
                        runBulk("paused") { await store.bulkUpdate($0, availability: .paused) }
                    }
                    Button("Archive", systemImage: "archivebox") {
                        runBulk("archived") { await store.bulkUpdate($0, disposition: .archived) }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingBacklogDeletionTaskIDs = selectedTaskIDs
                        showsBacklogDeletionConfirmation = true
                    }
                    Menu("Context", systemImage: "person.2") {
                        ForEach(PlanningContext.allCases, id: \.self) { context in
                            Button(context.displayName) {
                                runBulk("set to \(context.displayName)") { await store.bulkUpdate($0, context: context) }
                            }
                        }
                    }
                }
                .buttonStyle(.lifeBoardChip)
            }
            .scrollIndicators(.hidden)
        }
        .padding(12)
        .background(Color(SemanticColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityIdentifier("plan.backlog.bulkActions")
    }

    private func deletionUndoBanner(_ state: BacklogDeletionUndoState) -> some View {
        ReceiptBar(
            ActionReceiptPresentation(
                message: state.deletedCount == 1
                    ? String(localized: "Deleted 1 task")
                    : String(localized: "Deleted \(state.deletedCount) tasks")
            ),
            undo: {
                Task {
                    if await store.undoLastMutation() == false { Haptic.fail.play() }
                }
            },
            onDismiss: {
                withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                    store.dismissBacklogDeletionReceipt()
                }
            }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityIdentifier("plan.backlog.deletionUndo")
    }

    private func bulkReceiptBar(_ receipt: PlanReceipt) -> some View {
        ReceiptBar(
            ActionReceiptPresentation(id: receipt.id, message: receipt.message, detail: receipt.detail),
            undo: {
                Task {
                    if await store.undoLastMutation() == false { Haptic.fail.play() }
                }
            },
            onDismiss: {
                withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                    bulkReceipt = nil
                }
            }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityIdentifier("plan.backlog.bulkReceipt")
    }

    /// Commits a bulk change, then names it with Undo. The receipt appears only
    /// once the store has a reversible receipt for it: a failed write already
    /// raises Plan's error alert.
    private func runBulk(_ verb: String, _ apply: @escaping (Set<UUID>) async -> Void) {
        let ids = selectedTaskIDs
        let before = store.lastMutationReceiptID
        selectedTaskIDs.removeAll()
        Task {
            await apply(ids)
            guard let after = store.lastMutationReceiptID, after != before else {
                Haptic.fail.play()
                return
            }
            Haptic.commit.play()
            let noun = ids.count == 1 ? "1 task" : "\(ids.count) tasks"
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                bulkReceipt = (PlanReceipt(message: "\(noun) \(verb)"), after)
            }
        }
    }

    private func title(_ group: BacklogGroup) -> String {
        switch group {
        case .inbox: "Inbox"
        case .thisWeek: "This week"
        case .nextWeek: "Next week"
        case .later: "Later"
        case .someday: DecisionDestination.someday.title
        case .reference: "Reference"
        case .waiting: "Waiting"
        case .paused: "Paused"
        case .archived: "Archived"
        }
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

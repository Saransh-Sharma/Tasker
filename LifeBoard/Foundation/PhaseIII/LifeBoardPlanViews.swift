import SwiftUI
import UIKit

private enum BacklogContextFilter: String, CaseIterable, Identifiable {
    case all = "All contexts"
    case work = "Work"
    case personal = "Personal"
    case neutral = "Neutral"
    var id: String { rawValue }
}

private enum BacklogReadinessFilter: String, CaseIterable, Identifiable {
    case all = "All readiness"
    case ready = "Ready"
    case blocked = "Blocked"
    case estimateMissing = "Estimate missing"
    case hasDeadline = "Has deadline"
    var id: String { rawValue }
}

private enum BacklogEnergyFilter: String, CaseIterable, Identifiable {
    case all = "All energy"
    case low = "Low energy"
    case medium = "Medium energy"
    case high = "High energy"
    case missing = "Energy missing"
    var id: String { rawValue }
}

private enum BacklogDurationFilter: String, CaseIterable, Identifiable {
    case all = "All durations"
    case quick = "15 minutes or less"
    case short = "30 minutes or less"
    case hour = "60 minutes or less"
    case long = "More than 60 minutes"
    case missing = "Estimate missing"
    var id: String { rawValue }
}

private enum BacklogProjectFilter: String, CaseIterable, Identifiable {
    case all = "All projects"
    case assigned = "Has project"
    case unassigned = "No project"
    var id: String { rawValue }
}

private enum PlanDayPresentation: String, CaseIterable, Identifiable {
    case canvas = "Timeline"
    case agenda = "Agenda"
    var id: String { rawValue }
}

/// How the agenda schedule is sectioned. `timeOfDay` mirrors best-in-class
/// planners (Morning / Afternoon / Evening); `none` keeps the flat card list.
private enum PlanScheduleGrouping: String, CaseIterable, Identifiable {
    case timeOfDay = "Time of day"
    case none = "None"
    var id: String { rawValue }
}

/// A daypart bucket derived from a scheduled entry's start time.
private enum PlanScheduleDaypart: Int, CaseIterable, Identifiable {
    case morning, afternoon, evening
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sunrise"
        case .afternoon: return "sun.max"
        case .evening: return "moon.stars"
        }
    }

    static func daypart(for date: Date, calendar: Calendar = .current) -> PlanScheduleDaypart {
        switch calendar.component(.hour, from: date) {
        case 0..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }
}

/// A single scheduled agenda entry — a read-only calendar commitment or a
/// LifeBoard time block — unified so the daypart grouping can interleave them.
private enum PlanScheduledEntry: Identifiable {
    case commitment(PlanningFixedCommitment)
    case block(InternalTimeBlock)

    var id: String {
        switch self {
        case .commitment(let commitment): return "commitment-\(commitment.id)"
        case .block(let block): return "block-\(block.id.uuidString)"
        }
    }

    var startAt: Date {
        switch self {
        case .commitment(let commitment): return commitment.startAt
        case .block(let block): return block.startAt
        }
    }
}

/// Resolves a flick on the repair deck into one of four repair actions.
///
/// The deck used to read only left and right, so a proposal offering four ways
/// out could surface just two of them to the hand; the rest were reachable only
/// by hunting the button row. Vertical intent now carries the third and fourth.
///
/// A flick has to commit to an axis. Diagonals resolve to nothing rather than
/// guessing, because picking wrong here mutates the plan.
enum PlanRepairDeckDragResolver {
    static let threshold: CGFloat = 96
    static let minimumIntent: CGFloat = 24
    /// How far the dominant axis must beat the other before the flick counts as
    /// pointing that way at all.
    static let dominance: CGFloat = 1.15

    /// Declaration order is the slot order actions are assigned to.
    enum Direction: CaseIterable, Hashable {
        case right, left, up, down
    }

    static func direction(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> Direction? {
        guard max(abs(translation.width), abs(translation.height)) >= minimumIntent else { return nil }
        let dx = predictedEndTranslation.width
        let dy = predictedEndTranslation.height
        if abs(dx) > abs(dy) * dominance {
            guard abs(dx) >= threshold else { return nil }
            return dx > 0 ? .right : .left
        }
        if abs(dy) > abs(dx) * dominance {
            guard abs(dy) >= threshold else { return nil }
            return dy > 0 ? .down : .up
        }
        return nil
    }

    /// The action a direction carries, or nil when the proposal offers fewer
    /// ways out than the deck has directions.
    static func action(
        for direction: Direction,
        candidates: [PlanRepairAction]
    ) -> PlanRepairAction? {
        guard let slot = Direction.allCases.firstIndex(of: direction),
              slot < candidates.count else { return nil }
        return candidates[slot]
    }

    static func action(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        candidates: [PlanRepairAction]
    ) -> PlanRepairAction? {
        guard candidates.isEmpty == false,
              let direction = direction(
                  translation: translation,
                  predictedEndTranslation: predictedEndTranslation
              ) else { return nil }
        return action(for: direction, candidates: candidates)
    }

    /// Where a committed card leaves the screen.
    static func exitOffset(for direction: Direction, distance: CGFloat = 420) -> CGSize {
        switch direction {
        case .right: CGSize(width: distance, height: 0)
        case .left: CGSize(width: -distance, height: 0)
        case .up: CGSize(width: 0, height: -distance)
        case .down: CGSize(width: 0, height: distance)
        }
    }
}

/// Assigns overlapping timeline items to side-by-side lanes.
///
/// The day canvas used to position every commitment and block at the same x with
/// only a y offset, so anything concurrent was drawn literally on top of
/// everything else: with three or four overlapping meetings the spine became an
/// unreadable stack where only the last-drawn title was legible.
///
/// Items are grouped into clusters — maximal runs connected by overlap — and
/// greedily packed into the first free lane inside each cluster. Lane counts are
/// per cluster rather than per day, so one busy hour cannot narrow the whole
/// schedule.
enum PlanTimelineLaneResolver {
    /// How many lanes are on screen at once.
    ///
    /// Two is what a phone can show while a card still reads as a title and a
    /// time rather than an ellipsis. Dividing the width by the true lane count
    /// was tried and rejected: at three lanes every title collapsed to "…".
    /// Anything past the second lane scrolls instead.
    static let visibleLaneLimit = 2

    struct Item: Equatable {
        let id: String
        let start: Date
        let end: Date
    }

    struct Placement: Equatable {
        /// Zero-based column within the cluster.
        let lane: Int
        /// How many lanes the cluster needs. Drives width and scrolling.
        let laneCount: Int
        /// Stable identifier for the overlapping group this item belongs to.
        let clusterID: Int
    }

    /// Packs `items` into lanes, keyed by item id.
    ///
    /// Zero-length and reversed intervals are tolerated: a malformed event
    /// should take a lane, not break the day.
    static func placements(for items: [Item]) -> [String: Placement] {
        let sorted = items.sorted {
            $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start
        }
        var result: [String: Placement] = [:]
        var clusterID = 0
        var clusterMembers: [String] = []
        var laneEnds: [Date] = []
        var clusterEnd: Date?

        func closeCluster() {
            guard clusterMembers.isEmpty == false else { return }
            let count = max(1, laneEnds.count)
            for member in clusterMembers {
                guard let existing = result[member] else { continue }
                result[member] = Placement(
                    lane: existing.lane,
                    laneCount: count,
                    clusterID: existing.clusterID
                )
            }
            clusterMembers = []
            laneEnds = []
            clusterEnd = nil
            clusterID += 1
        }

        for item in sorted {
            let end = max(item.end, item.start)
            // A gap with everything placed so far ends the cluster, so the next
            // item starts a fresh set of lanes back at full width.
            if let currentEnd = clusterEnd, item.start >= currentEnd {
                closeCluster()
            }
            let lane = laneEnds.firstIndex { $0 <= item.start } ?? laneEnds.count
            if lane < laneEnds.count {
                laneEnds[lane] = end
            } else {
                laneEnds.append(end)
            }
            result[item.id] = Placement(lane: lane, laneCount: laneEnds.count, clusterID: clusterID)
            clusterMembers.append(item.id)
            clusterEnd = clusterEnd.map { max($0, end) } ?? end
        }
        closeCluster()
        return result
    }

    /// Total width a cluster's lanes occupy, including the gaps between them.
    static func stripWidth(laneCount: Int, laneWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let lanes = max(1, laneCount)
        return laneWidth * CGFloat(lanes) + spacing * CGFloat(lanes - 1)
    }

    /// Keeps a pan inside the strip: never past the first lane, never beyond the
    /// last one's trailing edge, so the band cannot be dragged into empty space.
    static func clampedStripOffset(
        _ offset: CGFloat,
        contentWidth: CGFloat,
        stripWidth: CGFloat
    ) -> CGFloat {
        min(0, max(min(0, contentWidth - stripWidth), offset))
    }

    /// Width of one lane, and whether the cluster extends past the visible edge.
    ///
    /// A lane is always sized so that `visibleLaneLimit` of them fill the
    /// canvas, however many there really are. One overlap splits the width in
    /// two and sits still; a third and beyond keep that same readable width and
    /// scroll horizontally, so a busy hour costs a swipe rather than legibility.
    static func laneMetrics(
        laneCount: Int,
        availableWidth: CGFloat,
        spacing: CGFloat
    ) -> (laneWidth: CGFloat, scrolls: Bool) {
        let lanes = max(1, laneCount)
        let width = max(0, availableWidth)
        guard lanes > 1 else { return (width, false) }
        let visible = min(lanes, visibleLaneLimit)
        let laneWidth = (width - spacing * CGFloat(visible - 1)) / CGFloat(visible)
        return (max(1, laneWidth), lanes > visibleLaneLimit)
    }
}

/// Quantizes a time-block drag onto the schedule grid.
///
/// The canvas previously tracked the finger continuously and only snapped on
/// release, so the grid was invisible during the gesture: there was no detent to
/// feel, and no way to see which slot the block would land in.
enum PlanBlockSnapResolver {
    /// Correction grid, used while the block is close to where it started.
    static let fineStepMinutes = 5
    /// Travel grid, used once the drag is a real move.
    static let coarseStepMinutes = 15
    /// Below this much travel the drag is treated as a correction.
    static let fineThresholdMinutes = 30.0
    /// Proximity within which a real neighboring edge unlocks the five-minute
    /// correction grid.
    static let boundaryProximityMinutes = 7.5

    /// Minutes the block should move for a given finger travel, snapped to the
    /// grid and clamped to the drawn day.
    ///
    /// A single coarse grid makes nudging a block by five minutes impossible; a
    /// single fine grid makes crossing the day feel notchy. Splitting on travel
    /// distance keeps both gestures available without a mode switch.
    static func snappedMinutes(
        translation: CGFloat,
        hourHeight: CGFloat,
        bounds: ClosedRange<Int>
    ) -> Int {
        guard hourHeight > 0 else { return 0 }
        let raw = Double(translation / hourHeight * 60)
        let step = Double(abs(raw) < fineThresholdMinutes ? fineStepMinutes : coarseStepMinutes)
        let snapped = Int((raw / step).rounded() * step)
        return min(max(snapped, bounds.lowerBound), bounds.upperBound)
    }

    /// Resize snapping is driven by nearby schedule edges, not by how far the
    /// finger happened to travel. Away from an event/block boundary the edge
    /// remains on the calm 15-minute grid; close to a real edge it gains a
    /// five-minute correction grid.
    static func boundaryAwareSnappedMinutes(
        translation: CGFloat,
        hourHeight: CGFloat,
        movingEdgeAt: Date,
        boundaries: [Date],
        bounds: ClosedRange<Int>,
        proximityMinutes: Double = boundaryProximityMinutes
    ) -> Int {
        guard hourHeight > 0 else { return 0 }
        let raw = Double(translation / hourHeight * 60)
        let nearestBoundaryDelta = boundaries
            .map { $0.timeIntervalSince(movingEdgeAt) / 60 }
            .min { abs($0 - raw) < abs($1 - raw) }
        let isNearBoundary = nearestBoundaryDelta.map {
            abs($0 - raw) <= proximityMinutes
        } ?? false
        let step = Double(isNearBoundary ? fineStepMinutes : coarseStepMinutes)
        let source = isNearBoundary ? (nearestBoundaryDelta ?? raw) : raw
        let snapped = Int((source / step).rounded() * step)
        return min(max(snapped, bounds.lowerBound), bounds.upperBound)
    }
}

/// The production surface for every canonical task scope.
///
/// This intentionally lives inside Plan rather than becoming a sixth root.
/// `TaskExecutionStore` supplies every row and count, and selection routes to
/// the same task editor used by project, Home, search, and deep links.
private struct TaskExecutionLibraryView: View {
    @Bindable var store: TaskExecutionStore
    let batchCoordinator: TaskBatchMutationCoordinator
    let projectRepository: any ProjectRepositoryProtocol
    let sectionRepository: (any SectionRepositoryProtocol)?
    let tagRepository: any TagRepositoryProtocol
    let onOpenTask: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var projects: [Project] = []
    @State private var sectionsByProjectID: [UUID: [LifeBoardProjectSection]] = [:]
    @State private var tags: [TagDefinition] = []
    @State private var isApplyingBatch = false
    @State private var batchReceipt: TaskBatchReceipt?
    @State private var batchError: String?
    @State private var destructiveMutation: TaskBatchMutation?

    var body: some View {
        List(selection: $selectedTaskIDs) {
            Section {
                Picker("Task view", selection: $store.query.scope) {
                    ForEach(TaskExecutionQuery.Scope.allCases, id: \.self) { scope in
                        Text(scope.titleWithCount(store.counts[scope]))
                            .tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("plan.taskLibrary.scope")
            }

            switch store.state {
            case .loading where store.tasks.isEmpty:
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading tasks…")
                        Spacer()
                    }
                    .frame(minHeight: 88)
                }
            case .empty:
                Section {
                    ContentUnavailableView(
                        store.query.scope.emptyTitle,
                        systemImage: store.query.scope.emptySymbol,
                        description: Text(store.query.scope.emptyDetail)
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            case .failed(let message):
                Section {
                    ContentUnavailableView {
                        Label("Tasks couldn’t be loaded", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await store.load() } }
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            case .permissionDenied:
                Section {
                    ContentUnavailableView(
                        "Task access unavailable",
                        systemImage: "lock",
                        description: Text("LifeBoard can’t read this task view right now.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            case .stale(let lastUpdatedAt):
                taskRows
                Section {
                    Label(
                        "Showing tasks from \(lastUpdatedAt.formatted(date: .omitted, time: .shortened))",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.footnote)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            case .loaded, .loading:
                taskRows
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .accessibilityIdentifier("plan.taskLibrary.select")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedTaskIDs.isEmpty == false {
                batchActionBar
            } else if let batchReceipt {
                batchUndoBar(batchReceipt)
            }
        }
        .task {
            async let loadTasks: Void = store.load()
            async let loadChoices: Void = loadBatchChoices()
            _ = await (loadTasks, loadChoices)
        }
        .onChange(of: store.query) {
            selectedTaskIDs.removeAll()
            Task { await store.load() }
        }
        .refreshable { await store.load() }
        .alert(
            "Batch action couldn’t finish",
            isPresented: Binding(
                get: { batchError != nil },
                set: { if $0 == false { batchError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { batchError = nil }
        } message: {
            Text(batchError ?? "")
        }
        .confirmationDialog(
            destructiveTitle,
            isPresented: Binding(
                get: { destructiveMutation != nil },
                set: { if $0 == false { destructiveMutation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let destructiveMutation {
                Button(destructiveActionTitle, role: .destructive) {
                    applyBatch(destructiveMutation)
                    self.destructiveMutation = nil
                }
            }
            Button("Cancel", role: .cancel) { destructiveMutation = nil }
        } message: {
            Text("This applies once to every selected task and can be undone as one action.")
        }
        .accessibilityIdentifier("plan.taskLibrary")
    }

    @ViewBuilder
    private var taskRows: some View {
        Section(store.query.scope.sectionTitle) {
            ForEach(store.tasks) { task in
                Button {
                    onOpenTask(task.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: store.query.scope == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                store.query.scope == .completed
                                    ? Color(LifeBoardColorTokens.foundationSageAccent)
                                    : Color(LifeBoardColorTokens.inkSecondary)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                                .multilineTextAlignment(.leading)
                            Text(taskMetadata(task))
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tag(task.id)
                .accessibilityHint("Opens the canonical task editor")
                .accessibilityAction(
                    named: selectedTaskIDs.contains(task.id)
                        ? "Remove from batch selection"
                        : "Add to batch selection"
                ) {
                    if selectedTaskIDs.contains(task.id) {
                        selectedTaskIDs.remove(task.id)
                    } else {
                        selectedTaskIDs.insert(task.id)
                    }
                }
                .accessibilityIdentifier("plan.taskLibrary.task.\(task.id.uuidString)")
            }
        }
    }

    private var batchActionBar: some View {
        HStack(spacing: 10) {
            Text("\(selectedTaskIDs.count) selected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .accessibilityLabel("\(selectedTaskIDs.count) tasks selected")

            Spacer(minLength: 4)

            Menu {
                Button("Today") {
                    applyBatch(
                        .schedule(
                            planningDay: PlanningDay(date: Date()),
                            startAt: nil,
                            endAt: nil
                        )
                    )
                }
                Button("Tomorrow") {
                    applyBatch(.deferTo(planningDay(daysFromToday: 1)))
                }
                Button("Next week") {
                    applyBatch(.deferTo(planningDay(daysFromToday: 7)))
                }
            } label: {
                Label("Plan", systemImage: "calendar")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityIdentifier("plan.taskLibrary.batch.plan")

            Menu {
                if tags.isEmpty == false {
                    Section("Add tag") {
                        ForEach(tags, id: \.id) { tag in
                            Button(tag.name) {
                                applyBatch(.addTags([tag.id]))
                            }
                        }
                    }
                }
                if projects.isEmpty == false {
                    Section("Move to project") {
                        ForEach(projects, id: \.id) { project in
                            Menu(project.name) {
                                Button("No section") {
                                    applyBatch(
                                        .move(
                                            projectID: project.id,
                                            projectName: project.name,
                                            sectionID: nil
                                        )
                                    )
                                }
                                ForEach(
                                    sectionsByProjectID[project.id] ?? [],
                                    id: \.id
                                ) { section in
                                    Button(section.name) {
                                        applyBatch(
                                            .move(
                                                projectID: project.id,
                                                projectName: project.name,
                                                sectionID: section.id
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                if tags.isEmpty && projects.isEmpty {
                    Text("No tags or projects available")
                }
            } label: {
                Label("Organize", systemImage: "tray.full")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityIdentifier("plan.taskLibrary.batch.organize")

            Button {
                applyBatch(.setCompletion(store.query.scope != .completed))
            } label: {
                Label(
                    store.query.scope == .completed ? "Reopen" : "Complete",
                    systemImage: store.query.scope == .completed
                        ? "arrow.uturn.backward.circle"
                        : "checkmark.circle"
                )
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityIdentifier("plan.taskLibrary.batch.complete")

            Menu {
                Button("Archive", role: .destructive) {
                    destructiveMutation = .archive
                }
                Button("Delete", role: .destructive) {
                    destructiveMutation = .delete
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 44, height: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityLabel("More batch actions")
            .accessibilityIdentifier("plan.taskLibrary.batch.more")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func batchUndoBar(_ receipt: TaskBatchReceipt) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            Text(receiptSummary(receipt))
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            Spacer()
            Button("Undo") { undoBatch(receipt) }
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isApplyingBatch)
                .accessibilityIdentifier("plan.taskLibrary.batch.undo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var destructiveTitle: String {
        switch destructiveMutation {
        case .archive: "Archive selected tasks?"
        case .delete: "Delete selected tasks?"
        default: "Apply to selected tasks?"
        }
    }

    private var destructiveActionTitle: String {
        switch destructiveMutation {
        case .archive: "Archive Tasks"
        case .delete: "Delete Tasks"
        default: "Apply"
        }
    }

    private func applyBatch(_ mutation: TaskBatchMutation) {
        let taskIDs = selectedTaskIDs
        guard taskIDs.isEmpty == false, isApplyingBatch == false else { return }
        isApplyingBatch = true
        Task {
            do {
                let receipt = try await batchCoordinator.apply(
                    TaskBatchMutationRequest(
                        taskIDs: taskIDs,
                        mutation: mutation,
                        source: "plan.task-library"
                    )
                )
                batchReceipt = receipt
                selectedTaskIDs.removeAll()
                await store.load()
            } catch {
                batchError = error.localizedDescription
            }
            isApplyingBatch = false
        }
    }

    private func undoBatch(_ receipt: TaskBatchReceipt) {
        guard isApplyingBatch == false else { return }
        isApplyingBatch = true
        Task {
            do {
                try await batchCoordinator.undo(receipt)
                batchReceipt = nil
                await store.load()
            } catch {
                batchError = error.localizedDescription
            }
            isApplyingBatch = false
        }
    }

    private func receiptSummary(_ receipt: TaskBatchReceipt) -> String {
        let count = receipt.before.count
        return "\(count) task\(count == 1 ? "" : "s") updated"
    }

    private func planningDay(daysFromToday offset: Int) -> PlanningDay {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return PlanningDay(date: date)
    }

    private func loadBatchChoices() async {
        async let loadedProjects = withCheckedContinuation {
            (continuation: CheckedContinuation<[Project], Never>) in
            projectRepository.fetchAllProjects { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        async let loadedTags = withCheckedContinuation {
            (continuation: CheckedContinuation<[TagDefinition], Never>) in
            tagRepository.fetchAll { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        projects = await loadedProjects
            .filter { $0.isArchived == false }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        tags = await loadedTags
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        guard let sectionRepository else {
            sectionsByProjectID = [:]
            return
        }
        var loadedSections: [UUID: [LifeBoardProjectSection]] = [:]
        for project in projects {
            let values = await withCheckedContinuation {
                (continuation: CheckedContinuation<[LifeBoardProjectSection], Never>) in
                sectionRepository.fetchSections(projectID: project.id) { result in
                    continuation.resume(returning: (try? result.get()) ?? [])
                }
            }
            loadedSections[project.id] = values.sorted { $0.sortOrder < $1.sortOrder }
        }
        sectionsByProjectID = loadedSections
    }

    private func taskMetadata(_ task: PlanningTaskSummary) -> String {
        var values: [String] = []
        if let day = task.metadata.planningDay?.startDate() {
            values.append(day.formatted(date: .abbreviated, time: .omitted))
        }
        if let due = task.dueDate {
            values.append("Due \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        if let estimate = task.estimatedDuration {
            let minutes = max(1, Int((estimate / 60).rounded()))
            values.append(minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m")
        }
        if task.dependenciesReady == false { values.append("Waiting on dependency") }
        return values.isEmpty ? "No date or estimate" : values.joined(separator: " · ")
    }
}

private extension TaskExecutionQuery.Scope {
    func titleWithCount(_ count: Int?) -> String {
        guard let count else { return sectionTitle }
        return "\(sectionTitle) (\(count))"
    }

    var sectionTitle: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .waiting: "Waiting"
        case .someday: "Someday"
        case .completed: "Completed"
        case .all: "All"
        }
    }

    var emptyTitle: String {
        switch self {
        case .inbox: "Inbox clear"
        case .today: "A spacious day"
        case .upcoming: "Nothing queued ahead"
        case .waiting: "Nothing waiting"
        case .someday: "Someday is open"
        case .completed: "No completed tasks yet"
        case .all: "No tasks yet"
        }
    }

    var emptyDetail: String {
        switch self {
        case .inbox: "Every filed task has somewhere to be."
        case .today: "Choose something intentionally when you’re ready."
        case .upcoming: "Future planned work will appear here."
        case .waiting: "Blocked and delegated work will appear here."
        case .someday: "Ideas you deliberately set aside will appear here."
        case .completed: "Finished work remains available without crowding Today."
        case .all: "Captured and planned work will appear here."
        }
    }

    var emptySymbol: String {
        switch self {
        case .inbox: "tray"
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .waiting: "hourglass"
        case .someday: "sparkles"
        case .completed: "checkmark.circle"
        case .all: "checklist"
        }
    }
}

private struct FocusSetupContext: Identifiable {
    let id = UUID()
    var taskID: UUID?
    var timeBlockID: UUID?
    var title: String
    var suggestedDuration: TimeInterval
    var subtaskID: UUID?
}

private enum FocusSetupMode: String, CaseIterable, Identifiable {
    case countdown = "Countdown"
    case stopwatch = "Stopwatch"
    case pomodoro = "Pomodoro"
    case openEnded = "Open-ended"

    var id: String { rawValue }
}

struct LifeBoardPlanRootView: View {
    private let onOpenFocus: (UUID) -> Void
    private let onAskEva: () -> Void
    private let onOpenWeeklyPlanner: () -> Void
    private let onOpenWeeklyReview: () -> Void
    private let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    private let onReviewCapture: (InboxItem) -> Void
    private let onOpenTask: (UUID) -> Void
    private let onOpenProject: (UUID) -> Void
    private let taskBatchCoordinator: TaskBatchMutationCoordinator
    private let projectTemplateService: ProjectTemplateInstantiationService
    private let projectRepository: any ProjectRepositoryProtocol
    private let sectionRepository: (any SectionRepositoryProtocol)?
    private let tagRepository: any TagRepositoryProtocol
    private let rescueRefreshGeneration: Int
    @State private var store: PlanStore
    @State private var inboxStore: InboxStore
    @State private var taskExecutionStore: TaskExecutionStore
    @State private var lens: PlanLens = .day
    @State private var dayPresentation: PlanDayPresentation = .canvas
    @State private var scheduleGrouping: PlanScheduleGrouping = .timeOfDay
    @State private var showsBlockComposer = false
    @State private var showsWorkingHours = false
    @State private var showsTaskLibrary = false
    @State private var showsProjectTemplates = false
    @State private var projectTemplateReceipt: ProjectTemplateCreationReceipt?
    @State private var projectTemplateError: String?
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var pendingBacklogDeletionTaskIDs: Set<UUID> = []
    @State private var showsBacklogDeletionConfirmation = false
    @FocusState private var focusedWeekTaskID: UUID?
    @State private var backlogSearch = ""
    @State private var backlogContextFilter: BacklogContextFilter = .all
    @State private var backlogReadinessFilter: BacklogReadinessFilter = .all
    @State private var backlogEnergyFilter: BacklogEnergyFilter = .all
    @State private var backlogDurationFilter: BacklogDurationFilter = .all
    @State private var backlogProjectFilter: BacklogProjectFilter = .all
    @State private var repairDragOffset: CGSize = .zero
    @State private var repairSnapAction: PlanRepairAction?
    @State private var focusReflectionEnergy = 3
    @State private var focusReflectionNote = ""
    @State private var pendingFocusSetup: FocusSetupContext?
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted

    init(
        dependencies: PlanFeatureDependencies,
        initialLens: PlanLens? = nil,
        rescueRefreshGeneration: Int = 0,
        onOpenFocus: @escaping (UUID) -> Void = { _ in },
        onAskEva: @escaping () -> Void = {},
        onOpenWeeklyPlanner: @escaping () -> Void = {},
        onOpenWeeklyReview: @escaping () -> Void = {},
        onOpenOverdueRescue: @escaping (OverdueRescueLaunchContext) -> Void = { _ in },
        onReviewCapture: @escaping (InboxItem) -> Void = { _ in },
        onOpenTask: @escaping (UUID) -> Void = { _ in },
        onOpenProject: @escaping (UUID) -> Void = { _ in }
    ) {
        let repository = dependencies.planningRepository
        _store = State(initialValue: PlanStore(
            planningRepository: repository,
            blockRepository: repository,
            scenarioCoordinator: DefaultPlanningScenarioCoordinator(
                planning: repository,
                mutations: repository
            ),
            taskDefinitionRepository: dependencies.taskDefinitionRepository,
            focusCommands: dependencies.focusCommands
        ))
        _inboxStore = State(
            initialValue: InboxStore(
                reader: InboxReader(repository: repository),
                planningRepository: repository,
                mutationRepository: repository,
                commitCoordinator: dependencies.inboxCommitCoordinator
            )
        )
        _taskExecutionStore = State(
            initialValue: TaskExecutionStore(
                query: TaskExecutionQuery(scope: .all, sort: .recentlyUpdated),
                projection: dependencies.taskExecutionProjection
            )
        )
        _lens = State(initialValue: initialLens ?? PlanLensRestoration.load())
        self.rescueRefreshGeneration = rescueRefreshGeneration
        self.onOpenFocus = onOpenFocus
        self.onAskEva = onAskEva
        self.onOpenWeeklyPlanner = onOpenWeeklyPlanner
        self.onOpenWeeklyReview = onOpenWeeklyReview
        self.onOpenOverdueRescue = onOpenOverdueRescue
        self.onReviewCapture = onReviewCapture
        self.onOpenTask = onOpenTask
        self.onOpenProject = onOpenProject
        taskBatchCoordinator = dependencies.taskBatchMutationCoordinator
        projectTemplateService = dependencies.projectTemplateInstantiationService
        projectRepository = dependencies.projectRepository
        sectionRepository = dependencies.sectionRepository
        tagRepository = dependencies.tagRepository
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear.ignoresSafeArea()
            if atmosphereIsHosted == false {
                LifeBoardScenicBackdrop(
                    scene: .plan,
                    daypart: preferences.resolvedDaypart(),
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                .frame(height: 230)
                .clipped()
                .ignoresSafeArea(edges: .top)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    Picker("Plan lens", selection: $lens) {
                        ForEach(PlanLens.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("plan.lens")

                    orientationBar

                    switch lens {
                    case .inbox: inboxContent
                    case .day: dayContent
                    case .week: weekContent
                    case .backlog: backlogContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    pendingFocusSetup = .init(
                        taskID: nil,
                        timeBlockID: nil,
                        title: "Unscoped focus",
                        suggestedDuration: 25 * 60,
                        subtaskID: nil
                    )
                } label: {
                    Label("Start unscoped focus", systemImage: "timer")
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("plan.focus.startUnscoped")
                Button {
                    showsProjectTemplates = true
                } label: {
                    Label("New project from template", systemImage: "folder.badge.plus")
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("plan.projectTemplates.open")
            }
        }
        .task(id: rescueRefreshGeneration) { await store.load() }
        .onChange(of: lens) { _, selectedLens in
            PlanLensRestoration.save(selectedLens)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.load() }
        }
        .sheet(isPresented: $showsBlockComposer) {
            PlanBlockComposer(day: store.selectedDay) { title, start, duration in
                Task { await store.createBlock(title: title, start: start, duration: duration) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsWorkingHours) {
            PlanWorkingHoursComposer(profile: store.workingProfile) { weekdays, start, end, buffer in
                Task { await store.saveWorkingHours(activeWeekdays: weekdays, startMinute: start, endMinute: end, bufferDuration: buffer) }
            }
        }
        .sheet(isPresented: $showsTaskLibrary) {
            NavigationStack {
                TaskExecutionLibraryView(
                    store: taskExecutionStore,
                    batchCoordinator: taskBatchCoordinator,
                    projectRepository: projectRepository,
                    sectionRepository: sectionRepository,
                    tagRepository: tagRepository
                ) { taskID in
                    showsTaskLibrary = false
                    onOpenTask(taskID)
                }
            }
        }
        .sheet(isPresented: $showsProjectTemplates) {
            ProjectTemplatePicker(
                service: projectTemplateService
            ) { receipt in
                projectTemplateReceipt = receipt
                showsProjectTemplates = false
            }
        }
        .sheet(item: $pendingFocusSetup) { context in
            FocusSetupSheet(
                context: context,
                onCancel: { pendingFocusSetup = nil },
                onStart: { mode, intention in
                    pendingFocusSetup = nil
                    Task {
                        await store.startFocus(
                            taskID: context.taskID,
                            timeBlockID: context.timeBlockID,
                            targetDuration: mode.initialTargetDuration,
                            mode: mode,
                            intention: intention,
                            subtaskID: context.subtaskID
                        )
                        if let taskID = context.taskID { onOpenFocus(taskID) }
                    }
                }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let receipt = projectTemplateReceipt {
                projectTemplateReceiptBar(receipt)
            }
        }
        .alert("Plan needs attention", isPresented: errorBinding) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog(
            backlogDeletionTitle,
            isPresented: $showsBacklogDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete from LifeBoard", role: .destructive) {
                let taskIDs = pendingBacklogDeletionTaskIDs
                pendingBacklogDeletionTaskIDs.removeAll()
                selectedTaskIDs.subtract(taskIDs)
                Task { await store.deleteBacklogTasks(taskIDs) }
            }
            Button("Cancel", role: .cancel) { pendingBacklogDeletionTaskIDs.removeAll() }
        } message: {
            Text("These items will disappear from Plan and linked-source pickers on every synced device. You can undo this planning change immediately; LifeBoard keeps a tombstone instead of physically destroying the canonical task.")
        }
        .alert(
            "Project template needs attention",
            isPresented: Binding(
                get: { projectTemplateError != nil },
                set: { if $0 == false { projectTemplateError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { projectTemplateError = nil }
        } message: {
            Text(projectTemplateError ?? "")
        }
    }

    private func projectTemplateReceiptBar(
        _ receipt: ProjectTemplateCreationReceipt
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill.badge.checkmark")
                .foregroundStyle(Color.lifeboard(.statusSuccess))
            VStack(alignment: .leading, spacing: 2) {
                Text("Project created")
                    .font(.subheadline.weight(.semibold))
                Text(receipt.createdProject.name)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("Undo") {
                Task {
                    do {
                        try await projectTemplateService.undo(receipt)
                        projectTemplateReceipt = nil
                    } catch {
                        projectTemplateError = error.localizedDescription
                    }
                }
            }
            .frame(minHeight: 44)
            Button("Open") {
                projectTemplateReceipt = nil
                onOpenProject(receipt.createdProject.id)
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.lifeboard(.surfacePrimary).opacity(0.98))
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.projectTemplates.receipt")
    }

    private var orientationBar: some View {
        HStack(spacing: 10) {
            if lens == .day {
                Button { Task { await store.moveSelection(by: -1) } } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous day")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lens == .day ? dayTitle(store.selectedDay) : lens.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Text(contextLine)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(1)
            }
            Spacer()
            if store.lastMutationReceiptID != nil {
                Button { Task { await store.undoLastMutation() } } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Undo last planning change")
            }
            if lens == .day {
                Button { Task { await store.select(day: PlanningDay(date: Date())) } } label: {
                    Image(systemName: "calendar").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Return to today")
                Button { Task { await store.moveSelection(by: 1) } } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next day")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
        .accessibilityIdentifier("plan.header")
    }

    @ViewBuilder private var dayContent: some View {
        if store.isLoading && store.daySnapshot == nil {
            LifeBoardStatusSurface(
                state: .loading,
                title: "Building your day",
                message: "Gathering commitments, blocks, and the next usable window."
            )
        } else if let errorMessage = store.errorMessage, store.daySnapshot == nil {
            LifeBoardStatusSurface(
                state: .recoverableError,
                title: "Your plan is still safe",
                message: errorMessage,
                actionTitle: "Try again",
                action: { Task { await store.load() } }
            )
        } else if let snapshot = store.daySnapshot {
            if let session = store.activeFocusSession { activeFocusCard(session) }
            if let receipt = store.pendingFocusReflection { focusReflectionCard(receipt) }
            calendarState(snapshot)

            // Capacity was computed, rendered as a one-line summary in the
            // header, and its full card was never called — which also made the
            // working-hours composer unreachable, since the card holds its only
            // trigger. Plan was showing a number derived from inputs the user
            // could not edit.
            capacityCard(snapshot.capacity)
            minimumViableDayControl

            dayPresentationControl
            if effectiveDayPresentation == .canvas {
                PlanDayTimeCanvas(
                    snapshot: snapshot,
                    taskForID: store.task(for:),
                    createBlock: { title, start, duration, taskID in
                        Task { await store.createBlock(title: title, start: start, duration: duration, taskID: taskID) }
                    },
                    moveBlock: { block, minutes in Task { await store.moveBlock(block, minutesDelta: minutes) } },
                    resizeBlock: { block, minutes in Task { await store.resizeBlock(block, minutesDelta: minutes) } },
                    resizeBlockEdges: { block, start, end in
                        Task {
                            await store.resizeBlockEdges(
                                block,
                                startMinutesDelta: start,
                                endMinutesDelta: end
                            )
                        }
                    },
                    splitBlock: { block in Task { await store.splitBlock(block) } },
                    deleteBlock: { block in Task { await store.deleteBlock(block) } },
                    startFocus: { block in
                        presentFocusSetup(for: block)
                    }
                )
            } else {
                if snapshot.freeWindows.isEmpty == false {
                    sectionHeader("Free windows", systemImage: "clock.badge.checkmark")
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(snapshot.freeWindows) { window in freeWindowButton(window) }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                fitsNextSurface(snapshot)

                if scheduleGrouping == .timeOfDay {
                    daypartGroupedSchedule(snapshot)
                } else {
                    if snapshot.commitments.isEmpty == false {
                        sectionHeader("Fixed commitments", systemImage: "calendar")
                        ForEach(snapshot.commitments) { commitmentCard($0) }
                    }
                    sectionHeader("Time blocks", systemImage: "rectangle.split.3x1", trailing: { scheduleSectionTrailing })
                    if snapshot.blocks.isEmpty {
                        emptyCard("No LifeBoard blocks yet", detail: "Add a calm focus window without changing your external calendar.", symbol: "calendar.badge.plus")
                    } else {
                        ForEach(snapshot.blocks) { blockCard($0) }
                    }
                }
            }

            sectionHeader("Planned work", systemImage: "checklist")
            if snapshot.plannedTasks.isEmpty {
                openDayRescueCard
            } else {
                ForEach(snapshot.plannedTasks) { taskCard($0, planned: true) }
            }

            sectionHeader("Unscheduled", systemImage: "tray")
            ForEach(snapshot.unscheduledTasks.prefix(8)) { taskCard($0, planned: false) }

            if !store.repairProposals.isEmpty {
                repairCard(store.repairProposals)
            }
        }
    }

    @ViewBuilder
    private var minimumViableDayControl: some View {
        if let scenario = store.pendingScenario {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    scenarioTitle(scenario.source),
                    systemImage: scenarioSymbol(scenario.source)
                )
                    .font(.headline)
                if let refresh = store.scenarioRefreshResult {
                    Label(
                        "Plan changed · review this refreshed proposal",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                    .accessibilityIdentifier("plan.minimumViableDay.refreshed")
                    DisclosureGroup("What changed") {
                        ForEach(refresh.previousDiff) { change in
                            Text("\(change.title): \(change.after ?? "No selection")")
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                    }
                    .font(.caption)
                }
                ForEach(scenario.diff) { change in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.title).font(.subheadline.weight(.semibold))
                        if let after = change.after {
                            Text(after)
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                    }
                }
                ForEach(scenario.validationIssues, id: \.self) { issue in
                    Label(issue, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                if scenario.source == .minimumViableDay,
                   scenario.isReadyToApply == false,
                   let snapshot = store.daySnapshot {
                    minimumViableDayChooser(snapshot)
                }
                HStack {
                    Button(
                        scenario.source == .minimumViableDay
                            ? "Keep current day"
                            : "Keep current plan"
                    ) { store.dismissScenario() }
                        .buttonStyle(.bordered)
                    Button(
                        scenarioApplyTitle(scenario.source)
                    ) {
                        Task { await store.applyPendingScenario() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scenario.isReadyToApply == false)
                }
            }
            .foundationClayCard()
            .accessibilityIdentifier("plan.minimumViableDay.preview")
        } else {
            Button {
                store.previewMinimumViableDay()
            } label: {
                Label("Shape a Minimum Viable Day", systemImage: "leaf")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            .accessibilityHint("Previews essential care, one achievable outcome, and protected rest before changing the plan")
            .accessibilityIdentifier("plan.minimumViableDay")
        }
    }

    private func scenarioTitle(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: "Minimum Viable Day"
        case .repair: "Plan repair preview"
        case .multiItemReschedule: "Reschedule preview"
        case .manual: "Plan preview"
        }
    }

    private func scenarioSymbol(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: "leaf.fill"
        case .repair: "wand.and.stars"
        case .multiItemReschedule: "calendar.badge.clock"
        case .manual: "list.bullet.clipboard"
        }
    }

    private func scenarioApplyTitle(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: "Apply reduced day"
        case .repair: "Apply repair"
        case .multiItemReschedule: "Apply reschedule"
        case .manual: "Apply changes"
        }
    }

    private func minimumViableDayChooser(
        _ snapshot: PlanDaySnapshot
    ) -> some View {
        let readyTasks = snapshot.unscheduledTasks.filter(\.dependenciesReady)
        let selected = store.minimumViableDaySelection
        return VStack(alignment: .leading, spacing: 8) {
            Text("Complete the three-part day")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            HStack(spacing: 8) {
                Menu {
                    ForEach(readyTasks) { task in
                        Button(task.title) {
                            var next = selected
                            next.careTaskID = task.id
                            if next.outcomeTaskID == task.id {
                                next.outcomeTaskID = nil
                            }
                            store.previewMinimumViableDay(selection: next)
                        }
                    }
                } label: {
                    Label("Essential care", systemImage: "heart")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(readyTasks.filter { $0.id != selected.careTaskID }) { task in
                        Button(task.title) {
                            var next = selected
                            next.outcomeTaskID = task.id
                            store.previewMinimumViableDay(selection: next)
                        }
                    }
                } label: {
                    Label("One outcome", systemImage: "scope")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            Menu {
                ForEach(snapshot.freeWindows.filter { $0.duration >= 15 * 60 }) { window in
                    Button("\(time(window.startAt))–\(time(window.endAt))") {
                        var next = selected
                        next.restWindowID = window.id
                        store.previewMinimumViableDay(selection: next)
                    }
                }
            } label: {
                Label("Protected rest", systemImage: "moon.zzz")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("plan.minimumViableDay.chooser")
    }

    @ViewBuilder private var weekContent: some View {
        if let snapshot = store.weekSnapshot {
            weeklyOperatingLayerActions(snapshot)
            if horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false && voiceOverEnabled == false {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(snapshot.days) { day in
                            weekDayCard(day)
                                .frame(width: 176)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("plan.week.sevenDayBoard")
            } else {
                let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(snapshot.days) { day in weekDayCard(day) }
                }
                .accessibilityIdentifier("plan.week.compactList")
            }
            if !snapshot.unplannedTasks.isEmpty {
                emptyCard("\(snapshot.unplannedTasks.count) items still need a day", detail: "Open Backlog to place them in the week.", symbol: "rectangle.stack.badge.plus")
            }
            let weekTasks = snapshot.days.flatMap { store.plannedTasks(on: $0.day) }
            if !weekTasks.isEmpty {
                sectionHeader("Redistribute work", systemImage: "arrow.left.arrow.right")
                ForEach(weekTasks) { task in weekTaskRow(task) }
            }
        }
    }

    private func weeklyOperatingLayerActions(_ snapshot: PlanWeekSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape the week")
                        .font(.headline)
                    Text("Set outcomes and a minimum viable week, then review unfinished work without losing this seven-day capacity view.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            }
            HStack(spacing: 10) {
                Button("Plan the week", systemImage: "arrow.right.circle.fill", action: onOpenWeeklyPlanner)
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Opens outcomes, triage, capacity, and minimum viable week planning")
                Button("Weekly review", systemImage: "checklist", action: onOpenWeeklyReview)
                    .buttonStyle(.bordered)
                    .accessibilityHint("Opens carry-forward decisions, outcomes, and reflection")
            }
            .controlSize(.large)
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.week.operatingLayer")
    }

    @ViewBuilder private var backlogContent: some View {
        if let snapshot = store.backlogSnapshot {
            backlogControls
            if let undoState = store.backlogDeletionUndoState {
                backlogDeletionUndoBanner(undoState)
            }
            if !selectedTaskIDs.isEmpty { bulkActionBar }
            ForEach(BacklogGroup.allCases, id: \.self) { group in
                let values = filteredBacklogTasks(snapshot.groups[group] ?? [])
                if !values.isEmpty {
                    sectionHeader(backlogTitle(group), systemImage: backlogSymbol(group))
                    ForEach(values) { taskCard($0, planned: taskIsPlanned($0)) }
                }
            }
            if snapshot.groups.values.allSatisfy(\.isEmpty) {
                emptyCard("Backlog clear", detail: "Everything open has a home.", symbol: "checkmark.seal")
            }
        }
    }

    private func capacityCard(_ capacity: CapacityBudget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(capacity.overloadDuration > 0 ? "Over capacity" : "Room in the day")
                        .font(.headline)
                    Text(loadLabel(capacity))
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Text(duration(capacity.usableDuration))
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("\(duration(capacity.usableDuration)) usable")
                Button { showsWorkingHours = true } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit working hours and buffer")
            }
            ProgressView(value: loadFraction(capacity)).tint(loadColor(capacity))
            // Capacity says how much room is left; this says how much of the day
            // is left to spend it in. The two together are the actual question.
            LifeBoardCelestialDaypartIndicator()
                .frame(height: 44)
                .accessibilityIdentifier("plan.capacity.daypart")
            HStack {
                Label("\(duration(capacity.plannedEstimatedDuration)) planned", systemImage: "checkmark.circle")
                Spacer()
                if capacity.isEstimateIncomplete {
                    Label("\(capacity.missingEstimateCount) estimates missing", systemImage: "questionmark.circle")
                } else {
                    Label("High confidence", systemImage: "checkmark.shield")
                }
            }
            .font(.caption)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.capacity")
    }

    private func activeFocusCard(_ session: FocusSessionV2) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(session.state == .paused ? "Focus paused" : "Focus in progress", systemImage: session.state == .paused ? "pause.circle.fill" : "timer")
                    .font(.headline)
                Spacer()
                focusClock(session)
            }
            if let companion = store.focusCompanion {
                HStack {
                    Text(focusModeLabel(companion.mode))
                    if let phase = companion.pomodoroPhase,
                       case let .pomodoro(_, _, rounds) = companion.mode {
                        Text("· \(phase.kind == .focus ? "Focus" : "Rest") \(phase.round) of \(rounds)")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                if companion.intention.isEmpty == false {
                    Text(companion.intention)
                        .font(.subheadline)
                }
            }
            if session.targetDuration > 0 {
                ProgressView(value: min(1, session.focusedDuration() / max(1, session.targetDuration)))
                    .tint(Color(LifeBoardColorTokens.foundationFocusRing))
            }
            HStack {
                if session.state == .paused {
                    Button("Resume", systemImage: "play.fill") { Task { await store.resumeFocus() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause", systemImage: "pause.fill") { Task { await store.pauseFocus() } }
                        .buttonStyle(.borderedProminent)
                }
                if store.focusCompanion?.pomodoroPhase != nil {
                    Button("Next phase", systemImage: "forward.end.fill") {
                        Task { await store.advancePomodoro() }
                    }
                    .buttonStyle(.bordered)
                }
                Menu("Interrupted", systemImage: "bell.slash") {
                    Button("Call or message") {
                        Task { await store.recordInterruption(reason: "Call or message") }
                    }
                    Button("Someone needed me") {
                        Task { await store.recordInterruption(reason: "Someone needed me") }
                    }
                    Button("Lost focus") {
                        Task { await store.recordInterruption(reason: "Lost focus") }
                    }
                }
                .buttonStyle(.bordered)
                Menu("End", systemImage: "stop.fill") {
                    Button("Finish") { Task { await store.endFocus(outcome: .completed) } }
                    Button("Continue Later") { Task { await store.endFocus(outcome: .continueLater) } }
                    Button("Abandon", role: .destructive) { Task { await store.endFocus(outcome: .abandoned) } }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color(LifeBoardColorTokens.foundationFocusRing).opacity(0.25), lineWidth: 1) }
        .accessibilityIdentifier("plan.activeFocus")
    }

    @ViewBuilder
    private func focusClock(_ session: FocusSessionV2) -> some View {
        if case .openEnded? = store.focusCompanion?.mode {
            Text("Here with you")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .accessibilityLabel("Open-ended focus has no time limit")
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let display = focusClockDisplay(session, at: context.date)
                Text(duration(display.value))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
                    .accessibilityLabel(display.label)
            }
        }
    }

    private func focusClockDisplay(
        _ session: FocusSessionV2,
        at date: Date
    ) -> (value: TimeInterval, label: String) {
        switch store.focusCompanion?.mode {
        case .countdown:
            let value = max(0, session.targetDuration - session.focusedDuration(at: date))
            return (
                value,
                value == 0 ? "Time is up. Choose what happens next." : "\(duration(value)) remaining"
            )
        case .pomodoro:
            let value = max(
                0,
                (store.focusCompanion?.pomodoroPhase?.phaseEndsAt ?? date).timeIntervalSince(date)
            )
            return (value, value == 0 ? "This phase is complete." : "\(duration(value)) in this phase")
        case .stopwatch, .none:
            let value = session.focusedDuration(at: date)
            return (value, "\(duration(value)) elapsed")
        case .openEnded:
            return (0, "Open-ended focus")
        }
    }

    private func focusReflectionCard(_ receipt: FocusExecutionReceipt) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("How did that feel?")
                        .font(.headline)
                    Text(
                        "\(duration(receipt.actualFocusedDuration)) focused · "
                            + "\(duration(receipt.targetDuration)) planned"
                    )
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button {
                    store.dismissFocusReflection()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip reflection")
            }
            Picker("Energy after focus", selection: $focusReflectionEnergy) {
                ForEach(1...5, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityValue("\(focusReflectionEnergy) out of 5")
            TextField("A short note, if useful", text: $focusReflectionNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("plan.focus.reflection.note")
            HStack {
                if receipt.interruptionCount > 0 {
                    Label(
                        "\(receipt.interruptionCount) interruption\(receipt.interruptionCount == 1 ? "" : "s")",
                        systemImage: "bell.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button("Save reflection", systemImage: "checkmark") {
                    let energy = focusReflectionEnergy
                    let note = focusReflectionNote
                    focusReflectionNote = ""
                    focusReflectionEnergy = 3
                    Task { await store.saveFocusReflection(energy: energy, note: note) }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
            }
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.focus.reflection")
    }

    private func focusModeLabel(_ mode: FocusMode) -> String {
        switch mode {
        case .countdown: "Countdown"
        case .stopwatch: "Stopwatch"
        case let .pomodoro(_, _, rounds): "Pomodoro · \(rounds) rounds"
        case .openEnded: "Open-ended focus"
        }
    }

    @ViewBuilder
    private func calendarState(_ snapshot: PlanDaySnapshot) -> some View {
        switch snapshot.calendarState {
        case .notRequested:
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Calendar can reveal real openings").font(.subheadline.weight(.semibold))
                    Text("Optional and read-only.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button("Allow") {
                    Task {
                        // Record through the shared gate so the just-in-time
                        // layer knows we have asked and never double-prompts.
                        LifeBoardPermissionPromptState.recordRequested(.calendar)
                        await store.requestCalendarAccess()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
            .accessibilityIdentifier("plan.calendar.notRequested")
        case .denied:
            HStack(spacing: 10) {
                Label("Calendar off · planning still works", systemImage: "calendar.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
                Button("Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
            .accessibilityIdentifier("plan.calendar.denied")
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing read-only calendar context")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier("plan.calendar.loading")
        case .fresh(let fetchedAt):
            Label(
                "\(snapshot.commitments.count) read-only commitment\(snapshot.commitments.count == 1 ? "" : "s") · updated \(fetchedAt.formatted(date: .omitted, time: .shortened))",
                systemImage: "calendar.badge.checkmark"
            )
            .font(.caption)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier("plan.calendar.fresh")
        case .staleCached(let fetchedAt, let message):
            calendarCacheWarning(
                title: "Calendar may be stale",
                detail: "Last updated \(fetchedAt.formatted(date: .omitted, time: .shortened)). \(message)",
                symbol: "clock.arrow.circlepath",
                identifier: "plan.calendar.stale"
            )
        case .offlineCached(let fetchedAt):
            calendarCacheWarning(
                title: "Offline calendar cache",
                detail: "Openings use events from \(fetchedAt.formatted(date: .omitted, time: .shortened)).",
                symbol: "wifi.slash",
                identifier: "plan.calendar.offline"
            )
        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.exclamationmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar couldn’t refresh")
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .lineLimit(2)
                }
                Spacer()
                Button("Retry") { Task { await store.load() } }
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 12)
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier("plan.calendar.failed")
        }
    }

    private func calendarCacheWarning(
        title: String,
        detail: String,
        symbol: String,
        identifier: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry") { Task { await store.load() } }
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(
            Color(LifeBoardColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityIdentifier(identifier)
    }

    private func freeWindowButton(_ window: FreeWindow) -> some View {
        Button {
            Task {
                await store.createBlock(
                    title: "Focus block",
                    start: window.startAt,
                    duration: min(window.duration, 60 * 60)
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(time(window.startAt))–\(time(window.endAt))").font(.subheadline.weight(.semibold))
                Text("\(duration(window.duration)) open").font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Creates a one-hour LifeBoard block, or uses the full opening when shorter")
        .dropDestination(for: String.self) { values, _ in
            guard let taskID = values.lazy.compactMap({ UUID(uuidString: $0) }).first,
                  let task = store.task(for: taskID), task.dependenciesReady else { return false }
            Task {
                await store.createBlock(
                    title: task.title,
                    start: window.startAt,
                    duration: min(window.duration, task.estimatedDuration ?? 60 * 60),
                    taskID: task.id
                )
            }
            return true
        } isTargeted: { _ in }
    }

    @ViewBuilder
    private func fitsNextSurface(_ snapshot: PlanDaySnapshot) -> some View {
        if snapshot.fitsNextCandidates.isEmpty == false {
            sectionHeader("Fits next", systemImage: "sparkles.rectangle.stack")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(snapshot.fitsNextCandidates.prefix(12)) { candidate in
                        Button {
                            Task {
                                await store.createBlock(
                                    title: candidate.taskTitle,
                                    start: candidate.window.startAt,
                                    duration: candidate.estimate,
                                    taskID: candidate.taskID
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.taskTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(
                                    "\(duration(candidate.estimate)) · \(time(candidate.window.startAt))–\(time(candidate.window.endAt))"
                                )
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .frame(minHeight: 52)
                            .background(
                                Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            "Schedules this task into the displayed free window"
                        )
                        .accessibilityIdentifier(
                            "plan.fitsNext.\(candidate.taskID.uuidString)"
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("plan.fitsNext")
        }
    }

    private func commitmentCard(_ commitment: PlanningFixedCommitment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: commitment.source == .externalCalendar ? "calendar" : "rectangle.inset.filled")
                .font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title).font(.headline)
                Text("\(time(commitment.startAt))–\(time(commitment.endAt)) · read-only context")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.nextCommitment")
    }

    private func blockCard(_ block: InternalTimeBlock) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4).fill(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.72)).frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title).font(.headline)
                Text("\(time(block.startAt))–\(time(block.endAt)) · \(duration(block.duration))")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Start focus", systemImage: "timer") {
                    presentFocusSetup(for: block)
                }
                Button("Add 15 minutes", systemImage: "plus") { Task { await store.resizeBlock(block, minutesDelta: 15) } }
                Button("Remove 15 minutes", systemImage: "minus") { Task { await store.resizeBlock(block, minutesDelta: -15) } }
                Button("Move 15 minutes earlier", systemImage: "arrow.up") { Task { await store.moveBlock(block, minutesDelta: -15) } }
                Button("Move 15 minutes later", systemImage: "arrow.down") { Task { await store.moveBlock(block, minutesDelta: 15) } }
                Button("Split block", systemImage: "rectangle.split.2x1") { Task { await store.splitBlock(block) } }
                Button("Remove", systemImage: "trash", role: .destructive) { Task { await store.deleteBlock(block) } }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.block.\(block.id.uuidString)")
    }

    // MARK: - Daypart-grouped schedule (agenda)

    /// The commitments + blocks merged and chronologically ordered.
    private func scheduledEntries(_ snapshot: PlanDaySnapshot) -> [PlanScheduledEntry] {
        let entries = snapshot.commitments.map(PlanScheduledEntry.commitment)
            + snapshot.blocks.map(PlanScheduledEntry.block)
        return entries.sorted { $0.startAt < $1.startAt }
    }

    @ViewBuilder
    private func daypartGroupedSchedule(_ snapshot: PlanDaySnapshot) -> some View {
        let entries = scheduledEntries(snapshot)
        sectionHeader("Schedule", systemImage: "calendar.day.timeline.left", trailing: { scheduleSectionTrailing })
        if entries.isEmpty {
            emptyCard("Nothing scheduled yet", detail: "Add a calm focus window or let a commitment sync in — your day stays open until then.", symbol: "calendar.badge.plus")
        } else {
            ForEach(PlanScheduleDaypart.allCases) { daypart in
                let items = entries.filter { PlanScheduleDaypart.daypart(for: $0.startAt) == daypart }
                if items.isEmpty == false {
                    daypartSubheader(daypart, count: items.count)
                    ForEach(items) { scheduledEntryCard($0) }
                }
            }
        }
    }

    @ViewBuilder
    private func scheduledEntryCard(_ entry: PlanScheduledEntry) -> some View {
        switch entry {
        case .commitment(let commitment): commitmentCard(commitment)
        case .block(let block): blockCard(block)
        }
    }

    private func daypartSubheader(_ daypart: PlanScheduleDaypart, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: daypart.symbolName)
                .font(.caption.weight(.semibold))
            Text(daypart.title)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.14), in: Capsule())
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(daypart.title), \(count) scheduled")
    }

    /// Group-by menu plus the add-block button for the schedule section header.
    private var scheduleSectionTrailing: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Group schedule by", selection: $scheduleGrouping) {
                    ForEach(PlanScheduleGrouping.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(scheduleGrouping.rawValue).font(.caption.weight(.medium))
                }
            }
            .accessibilityLabel("Group schedule by")
            .accessibilityValue(scheduleGrouping.rawValue)

            Button { showsBlockComposer = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add time block")
        }
    }

    private var inboxContent: some View {
        LifeBoardInboxView(store: inboxStore, onReviewCapture: onReviewCapture)
    }

    private func taskCard(_ task: PlanningTaskSummary, planned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
            if V2FeatureFlags.lifeBoardDailyLoopV1Enabled {
                // `tasks` comes from `fetchOpenPlanningTasks()`, so a row on
                // screen is always incomplete; the control's job here is to
                // make it complete, and the row leaves on the next load.
                LifeBoardCompletionControl(
                    isComplete: false,
                    title: task.title,
                    isEnabled: task.dependenciesReady
                ) { _ in
                    Task { await store.setCompletion(task, to: true) }
                }
                .padding(.leading, -11)
            } else {
                Image(systemName: task.dependenciesReady ? "circle" : "lock.circle")
                    .foregroundStyle(
                        task.dependenciesReady
                            ? Color(LifeBoardColorTokens.inkTertiary)
                            : Color(LifeBoardColorTokens.foundationApricotAccent)
                    )
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(task.title).font(.body.weight(.medium)).lineLimit(2)
                    if task.metadata.commitmentLevel == .mustDo {
                        Text("MUST DO").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.22), in: Capsule())
                    }
                }
                Text(taskMetadataLine(task))
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                if lens == .backlog {
                    Button(selectedTaskIDs.contains(task.id) ? "Deselect" : "Select", systemImage: selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle") {
                        if selectedTaskIDs.contains(task.id) { selectedTaskIDs.remove(task.id) }
                        else { selectedTaskIDs.insert(task.id) }
                    }
                }
                Button(planned ? "Remove from day" : "Plan for this day", systemImage: "calendar") {
                    Task { await store.updateTask(task, planningDay: planned ? nil : store.selectedDay) }
                }
                Button(task.metadata.commitmentLevel == .mustDo ? "Make standard" : "Mark Must Do", systemImage: "exclamationmark.circle") {
                    Task { await store.updateTask(task, preserveDay: true, commitment: task.metadata.commitmentLevel == .mustDo ? .standard : .mustDo) }
                }
                Button("Waiting", systemImage: "hourglass") { Task { await store.updateTask(task, preserveDay: true, availability: .waiting) } }
                Button("Paused", systemImage: "pause.circle") { Task { await store.updateTask(task, preserveDay: true, availability: .paused) } }
                if task.metadata.unscheduledDisposition == .archived {
                    Button("Restore to inbox", systemImage: "tray.and.arrow.up") {
                        Task { await store.bulkUpdate([task.id], disposition: .inbox) }
                    }
                } else {
                    Button("Archive", systemImage: "archivebox") {
                        Task { await store.bulkUpdate([task.id], disposition: .archived) }
                    }
                }
                if lens == .backlog {
                    Divider()
                    Button("Delete from LifeBoard", systemImage: "trash", role: .destructive) {
                        pendingBacklogDeletionTaskIDs = [task.id]
                        showsBacklogDeletionConfirmation = true
                    }
                }
                Button("Start focus", systemImage: "timer") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    pendingFocusSetup = .init(
                        taskID: task.id,
                        timeBlockID: nil,
                        title: task.title,
                        suggestedDuration: task.estimatedDuration ?? 25 * 60,
                        subtaskID: nil
                    )
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Actions for \(task.title)")
            }
            if let suggestion = store.calibrationSuggestions[task.id] {
                calibrationSuggestionRow(suggestion)
            }
        }
        .foundationClayCard()
        .draggable(task.id.uuidString)
        .accessibilityIdentifier("plan.task.\(task.id.uuidString)")
    }

    private func presentFocusSetup(for block: InternalTimeBlock) {
        pendingFocusSetup = .init(
            taskID: block.taskID,
            timeBlockID: block.id,
            title: block.title,
            suggestedDuration: block.duration,
            subtaskID: nil
        )
    }

    private func calibrationSuggestionRow(
        _ suggestion: EstimateCalibrationSuggestion
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "timer.square")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 2) {
                Text("Observed median: \(duration(suggestion.suggestedDuration))")
                    .font(.caption.weight(.semibold))
                Text(
                    "\(suggestion.evidenceSessionCount) sessions · \(duration(suggestion.observedMinimum))–\(duration(suggestion.observedMaximum)) observed"
                )
                .font(.caption2)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer(minLength: 4)
            Button("Use estimate") {
                Task { await store.acceptCalibration(suggestion) }
            }
            .font(.caption.weight(.semibold))
            .frame(minHeight: 44)
        }
        .overlay(alignment: .top) {
            Divider()
                .offset(y: -5)
        }
        .accessibilityIdentifier(
            "plan.calibration.\(suggestion.taskID.uuidString)"
        )
    }

    private func repairCard(_ proposals: [PlanRepairProposal]) -> some View {
        let proposal = proposals.first
        // With the flagship stage off the deck keeps its original two
        // directions, so the rollback is a genuine return to the previous
        // behaviour rather than a half-lit four-way pad.
        let directionCount = V2FeatureFlags.taskProjectFlagshipV1Enabled
            ? PlanRepairDeckDragResolver.Direction.allCases.count
            : 2
        let dragCandidates = Array(
            (proposal?.actions ?? []).filter { $0 != .askEva }.prefix(directionCount)
        )
        return VStack(alignment: .leading, spacing: 10) {
            Label("Plan repair", systemImage: "wand.and.stars")
                .font(.headline)
            Text(proposal?.explanation ?? "Your day has changed. Choose what should move; nothing changes automatically.")
                .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            if dragCandidates.isEmpty == false {
                repairDirectionPad(dragCandidates)
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array((proposal?.actions ?? []).prefix(5)), id: \.self) { action in
                        Button(repairActionTitle(action), systemImage: repairActionSymbol(action)) {
                            performRepairAction(action, proposal: proposal)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .foundationClayCard()
        // Resolving one proposal used to appear to conjure another; the deck
        // depth says up front how many are queued.
        .lifeBoardDeckDepth(remaining: proposals.count)
        // Vertical travel is no longer decorative, so it tracks the finger as
        // openly as horizontal travel does.
        .offset(x: repairDragOffset.width * 0.22, y: repairDragOffset.height * 0.22)
        .scaleEffect(repairDragOffset == .zero ? 1 : 1.012)
        .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: repairDragOffset)
        .simultaneousGesture(repairGesture(proposal: proposal, candidates: dragCandidates))
        .modifier(
            PlanRepairAccessibilityActions(
                candidates: dragCandidates,
                title: repairActionTitle,
                perform: { performRepairAction($0, proposal: proposal) }
            )
        )
        .accessibilityIdentifier("plan.repair")
    }

    /// Says which way each repair lives, and lights the one the current flick
    /// would commit. Without it the extra two directions are invisible: a swipe
    /// deck that mutates the plan should never rely on the user guessing.
    private func repairDirectionPad(_ candidates: [PlanRepairAction]) -> some View {
        VStack(spacing: 3) {
            repairDirectionChip(.up, candidates: candidates)
            HStack(spacing: 6) {
                repairDirectionChip(.left, candidates: candidates)
                repairDirectionChip(.right, candidates: candidates)
            }
            repairDirectionChip(.down, candidates: candidates)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func repairDirectionChip(
        _ direction: PlanRepairDeckDragResolver.Direction,
        candidates: [PlanRepairAction]
    ) -> some View {
        if let action = PlanRepairDeckDragResolver.action(for: direction, candidates: candidates) {
            let armed = repairSnapAction == action
            HStack(spacing: 4) {
                Image(systemName: repairDirectionSymbol(direction))
                Text(repairActionTitle(action)).lineLimit(1)
            }
            .font(.caption2.weight(armed ? .bold : .regular))
            .foregroundStyle(
                Color(armed ? LifeBoardColorTokens.inkPrimary : LifeBoardColorTokens.inkSecondary)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color(LifeBoardColorTokens.foundationApricotAccent)
                    .opacity(armed ? 0.30 : 0.10),
                in: Capsule()
            )
            .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: armed)
        }
    }

    private func repairDirectionSymbol(_ direction: PlanRepairDeckDragResolver.Direction) -> String {
        switch direction {
        case .right: "chevron.right"
        case .left: "chevron.left"
        case .up: "chevron.up"
        case .down: "chevron.down"
        }
    }

    private func repairGesture(
        proposal: PlanRepairProposal?,
        candidates: [PlanRepairAction]
    ) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                repairDragOffset = value.translation
                let candidate = PlanRepairDeckDragResolver.action(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    candidates: candidates
                )
                if candidate != nil, repairSnapAction == nil { LifeBoardFeedback.selection() }
                repairSnapAction = candidate
            }
            .onEnded { value in
                let direction = PlanRepairDeckDragResolver.direction(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation
                )
                let action = direction.flatMap {
                    PlanRepairDeckDragResolver.action(for: $0, candidates: candidates)
                }
                repairSnapAction = nil
                guard let action, let direction else {
                    withAnimation(reduceMotion ? nil : LifeBoardAnimation.directManipulation) {
                        repairDragOffset = .zero
                    }
                    return
                }
                LifeBoardFeedback.medium()
                withAnimation(reduceMotion ? nil : LifeBoardAnimation.panelOut) {
                    // The card leaves the way it was thrown, so the gesture and
                    // the result read as one motion.
                    repairDragOffset = PlanRepairDeckDragResolver.exitOffset(for: direction)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.18)) {
                    repairDragOffset = .zero
                    performRepairAction(action, proposal: proposal)
                }
            }
    }

    private func performRepairAction(_ action: PlanRepairAction, proposal: PlanRepairProposal?) {
        LifeBoardFeedback.light()
        if action == .askEva {
            onAskEva()
        } else if let proposal {
            store.previewRepair(proposal, action: action)
        }
    }

    private func emptyCard(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            if symbol == "sun.max" {
                Image(decorative: LifeBoardAtmosphereDescriptor.descriptor(for: .midday).celestialAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
    }

    private var openDayRescueCard: some View {
        Button(action: openOverdueRescue) {
            HStack(spacing: 14) {
                Image(decorative: LifeBoardAtmosphereDescriptor.descriptor(for: .midday).celestialAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("This day is open")
                        .font(.headline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    Text("Choose overdue work that still deserves a place.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foundationClayCard()
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .hoverEffect(.highlight)
        .accessibilityIdentifier("plan.day.openRescue")
        .accessibilityLabel("Plan this day with Overdue Rescue")
        .accessibilityHint("Review overdue tasks and keep, move, edit, or remove them.")
    }

    private func openOverdueRescue() {
        let metadataByTaskID = Dictionary(uniqueKeysWithValues: store.tasks.map { ($0.id, $0.metadata) })
        let context = OverdueRescueLaunchContext.plan(
            selectedDay: store.selectedDay,
            planningMetadataByTaskID: metadataByTaskID
        )
        onOpenOverdueRescue(context)
        LifeBoardFeedback.light()
    }

    private func sectionHeader<Content: View>(_ title: String, systemImage: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(LifeBoardFoundationTypography.sectionTitle())
            Spacer()
            trailing()
        }
        .padding(.top, 6)
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        sectionHeader(title, systemImage: systemImage) { EmptyView() }
    }

    private var dayPresentationControl: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker("Day presentation", selection: $dayPresentation) {
                ForEach(PlanDayPresentation.allCases) { presentation in
                    Text(presentation.rawValue).tag(presentation)
                }
            }
            .pickerStyle(.segmented)
            .disabled(requiresAgendaPresentation)
            .accessibilityIdentifier("plan.day.presentation")
            if requiresAgendaPresentation {
                Text("Agenda is active for VoiceOver, accessibility text, or Reduce Motion so every time block remains linear and fully operable.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
    }

    private var requiresAgendaPresentation: Bool {
        voiceOverEnabled || dynamicTypeSize.isAccessibilitySize || reduceMotion
    }

    private var effectiveDayPresentation: PlanDayPresentation {
        requiresAgendaPresentation ? .agenda : dayPresentation
    }

    private var contextLine: String {
        guard let capacity = store.daySnapshot?.capacity else { return "Loading capacity…" }
        return capacity.overloadDuration > 0 ? "\(duration(capacity.overloadDuration)) overloaded" : "\(duration(capacity.remainingKnownCapacity)) known room"
    }

    private func taskIsPlanned(_ task: PlanningTaskSummary) -> Bool { task.metadata.planningDay != nil }
    private func loadFraction(_ value: CapacityBudget) -> Double { value.usableDuration > 0 ? min(1, value.plannedEstimatedDuration / value.usableDuration) : 0 }
    private func loadColor(_ value: CapacityBudget) -> Color {
        value.overloadDuration > 0
            ? Color(LifeBoardColorTokens.foundationApricotAccent)
            : Color(LifeBoardColorTokens.foundationFocusRing)
    }
    private func loadLabel(_ value: CapacityBudget) -> String {
        if value.overloadDuration > 0 { return "\(duration(value.overloadDuration)) over usable capacity" }
        return "\(duration(value.remainingKnownCapacity)) known capacity remains"
    }
    private func taskMetadataLine(_ task: PlanningTaskSummary) -> String {
        var values: [String] = [task.estimatedDuration.map(duration) ?? "Estimate incomplete"]
        if let due = task.dueDate { values.append("Due \(due.formatted(date: .abbreviated, time: .omitted))") }
        if task.metadata.availability != .actionable { values.append(task.metadata.availability.rawValue.capitalized) }
        if !task.dependenciesReady { values.append("Waiting on dependency") }
        return values.joined(separator: " · ")
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
    private func dayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? "Selected day" }
    private func shortDayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.abbreviated).day()) ?? "Day" }
    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func backlogTitle(_ group: BacklogGroup) -> String {
        switch group { case .thisWeek: "This Week"; case .nextWeek: "Next Week"; default: group.rawValue.capitalized }
    }
    private func backlogSymbol(_ group: BacklogGroup) -> String {
        switch group {
        case .inbox: "tray"; case .thisWeek: "calendar"; case .nextWeek: "calendar.badge.plus"
        case .later: "clock"; case .someday: "sparkles"; case .reference: "books.vertical"
        case .waiting: "hourglass"; case .paused: "pause.circle"; case .archived: "archivebox"
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
        .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14))
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
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("plan.backlog.bulkActions")
    }

    private func backlogDeletionUndoBanner(_ state: BacklogDeletionUndoState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.slash.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.deletedCount) item\(state.deletedCount == 1 ? "" : "s") removed")
                    .font(.subheadline.weight(.semibold))
                Text("Deletion is synced as a reversible tombstone.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Button("Undo") { Task { await store.undoLastMutation() } }
                .buttonStyle(.bordered)
                .accessibilityHint("Restores the deleted backlog items exactly as they were")
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.backlog.deletionUndo")
    }

    private var backlogDeletionTitle: String {
        let count = pendingBacklogDeletionTaskIDs.count
        return count == 1 ? "Delete this backlog item?" : "Delete \(count) backlog items?"
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

    private func weekDayCard(_ day: PlanWeekDaySummary) -> some View {
        Button {
            lens = .day
            Task { await store.select(day: day.day) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(shortDayTitle(day.day)).font(.headline)
                    Spacer()
                    if day.mustDoCount > 0 {
                        Label("\(day.mustDoCount)", systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
                ProgressView(value: loadFraction(day.capacity)).tint(loadColor(day.capacity))
                VStack(alignment: .leading, spacing: 3) {
                    Text(loadLabel(day.capacity)).lineLimit(2)
                    Text("\(day.deadlineCount) due")
                }
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .foundationClayCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .dropDestination(for: String.self) { values, _ in
            guard let taskID = values.lazy.compactMap(UUID.init(uuidString:)).first,
                  let task = store.task(for: taskID), task.dependenciesReady else { return false }
            Task { await store.updateTask(task, planningDay: day.day) }
            return true
        } isTargeted: { _ in }
        .accessibilityLabel("\(shortDayTitle(day.day)), \(loadLabel(day.capacity)), \(day.deadlineCount) due")
        .accessibilityHint("Open the day. Tasks can be dropped here to move them to this day.")
        .accessibilityIdentifier("plan.week.\(day.day.year)-\(day.day.month)-\(day.day.day)")
    }

    private func weekTaskRow(_ task: PlanningTaskSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title).font(.body.weight(.medium))
                Text(task.metadata.planningDay.map(shortDayTitle) ?? "No day")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Move one day earlier", systemImage: "arrow.left") {
                    if let day = task.metadata.planningDay, let moved = shifted(day, by: -1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("Move one day later", systemImage: "arrow.right") {
                    if let day = task.metadata.planningDay, let moved = shifted(day, by: 1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("Remove from week", systemImage: "tray") {
                    Task { await store.updateTask(task, planningDay: nil) }
                }
            } label: { Image(systemName: "arrow.left.arrow.right.circle") }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .draggable(task.id.uuidString)
        .hoverEffect(.highlight)
        .focusable()
        .focused($focusedWeekTaskID, equals: task.id)
        .onKeyPress(.leftArrow) {
            moveWeekTask(task, by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveWeekTask(task, by: 1)
            return .handled
        }
        .accessibilityIdentifier("plan.week.task.\(task.id.uuidString)")
    }

    private func moveWeekTask(_ task: PlanningTaskSummary, by offset: Int) {
        guard let day = task.metadata.planningDay, let moved = shifted(day, by: offset) else { return }
        Task { await store.updateTask(task, planningDay: moved) }
    }

    private func shifted(_ day: PlanningDay, by offset: Int) -> PlanningDay? {
        guard let date = day.startDate(), let moved = Calendar.current.date(byAdding: .day, value: offset, to: date) else { return nil }
        return PlanningDay(date: moved, timeZone: TimeZone(identifier: day.timeZoneIdentifier) ?? .current)
    }

    private func repairActionTitle(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "Resume"
        case .moveLaterToday: "Later today"
        case .moveToAnotherDay: "Another day"
        case .split: "Split"
        case .defer: "Defer"
        case .leaveUnchanged: "Leave unchanged"
        case .askEva: "Ask Eva"
        }
    }

    private func repairActionSymbol(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "play.fill"
        case .moveLaterToday: "clock.arrow.circlepath"
        case .moveToAnotherDay: "calendar.badge.plus"
        case .split: "rectangle.split.2x1"
        case .defer: "tray"
        case .leaveUnchanged: "minus.circle"
        case .askEva: "sparkles"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil && store.daySnapshot != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )
    }
}

private struct FocusSetupSheet: View {
    let context: FocusSetupContext
    let onCancel: () -> Void
    let onStart: (FocusMode, String) -> Void

    @State private var mode: FocusSetupMode = .countdown
    @State private var countdownMinutes: Int
    @State private var pomodoroFocusMinutes = 25
    @State private var pomodoroBreakMinutes = 5
    @State private var pomodoroRounds = 4
    @State private var intention = ""

    init(
        context: FocusSetupContext,
        onCancel: @escaping () -> Void,
        onStart: @escaping (FocusMode, String) -> Void
    ) {
        self.context = context
        self.onCancel = onCancel
        self.onStart = onStart
        _countdownMinutes = State(
            initialValue: max(5, Int((context.suggestedDuration / 60).rounded()))
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.title)
                            .font(.title2.weight(.semibold))
                        Text("Choose the rhythm that fits this moment.")
                            .font(.subheadline)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }

                    Picker("Focus mode", selection: $mode) {
                        ForEach(FocusSetupMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("plan.focus.setup.mode")

                    modeControls

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intention")
                            .font(.subheadline.weight(.semibold))
                        TextField("What would make this session enough?", text: $intention, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("plan.focus.setup.intention")
                    }

                    Button {
                        onStart(resolvedMode, intention)
                    } label: {
                        Label(startTitle, systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("plan.focus.setup.start")
                }
                .padding(20)
            }
            .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
            .navigationTitle("Start focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .frame(minHeight: 44)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var modeControls: some View {
        switch mode {
        case .countdown:
            Stepper(value: $countdownMinutes, in: 5...240, step: 5) {
                settingLabel("Duration", value: "\(countdownMinutes) min")
            }
            .frame(minHeight: 44)
        case .stopwatch:
            settingExplanation(
                title: "Count upward",
                detail: "Elapsed time stays primary. Stop whenever the work reaches a natural edge.",
                symbol: "stopwatch"
            )
        case .pomodoro:
            VStack(spacing: 12) {
                Stepper(value: $pomodoroFocusMinutes, in: 5...90, step: 5) {
                    settingLabel("Focus", value: "\(pomodoroFocusMinutes) min")
                }
                Stepper(value: $pomodoroBreakMinutes, in: 1...30) {
                    settingLabel("Rest", value: "\(pomodoroBreakMinutes) min")
                }
                Stepper(value: $pomodoroRounds, in: 1...8) {
                    settingLabel("Rounds", value: "\(pomodoroRounds)")
                }
            }
            .frame(minHeight: 44)
        case .openEnded:
            settingExplanation(
                title: "No clock pressure",
                detail: "The timer recedes. This session ends only when you choose Finish, Continue Later, or Abandon.",
                symbol: "infinity"
            )
        }
    }

    private var resolvedMode: FocusMode {
        switch mode {
        case .countdown:
            .countdown(duration: TimeInterval(countdownMinutes * 60))
        case .stopwatch:
            .stopwatch
        case .pomodoro:
            .pomodoro(
                focus: TimeInterval(pomodoroFocusMinutes * 60),
                breakDuration: TimeInterval(pomodoroBreakMinutes * 60),
                rounds: pomodoroRounds
            )
        case .openEnded:
            .openEnded
        }
    }

    private var startTitle: String {
        switch mode {
        case .countdown: "Start \(countdownMinutes)-minute focus"
        case .stopwatch: "Start stopwatch"
        case .pomodoro: "Start Pomodoro"
        case .openEnded: "Begin open-ended focus"
        }
    }

    private func settingLabel(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .monospacedDigit()
        }
    }

    private func settingExplanation(title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
                .background(
                    Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
        .frame(minHeight: 52)
    }
}

private struct PlanDayTimeCanvas: View {
    let snapshot: PlanDaySnapshot
    let taskForID: (UUID) -> PlanningTaskSummary?
    let createBlock: (String, Date, TimeInterval, UUID?) -> Void
    let moveBlock: (InternalTimeBlock, Int) -> Void
    let resizeBlock: (InternalTimeBlock, Int) -> Void
    let resizeBlockEdges: (InternalTimeBlock, Int, Int) -> Void
    let splitBlock: (InternalTimeBlock) -> Void
    let deleteBlock: (InternalTimeBlock) -> Void
    let startFocus: (InternalTimeBlock) -> Void

    private let hourHeight: CGFloat = 66
    private let rulerWidth: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Label("Time canvas", systemImage: "clock")
                    .font(.headline)
                Spacer()
                if conflictCount > 0 {
                    Label("\(conflictCount) conflict\(conflictCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        .accessibilityHint("Overlapping commitments and LifeBoard blocks are highlighted in the timeline")
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    hourGrid(width: proxy.size.width)
                    freeWindowLayer(width: proxy.size.width)
                    clusterLayer(width: proxy.size.width)
                }
            }
            .frame(height: timelineHeight)
            .accessibilityIdentifier("plan.day.canvas")

            HStack(spacing: 14) {
                canvasLegend("Open", color: Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.28))
                canvasLegend("Calendar", color: Color(LifeBoardColorTokens.foundationSurfaceRecessed))
                canvasLegend("LifeBoard", color: Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.62))
            }
            .font(.caption2)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .foundationClayCard()
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(0...hourSpan, id: \.self) { offset in
            let hour = startHour + offset
            HStack(spacing: 8) {
                Text(hourLabel(hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                    .frame(width: rulerWidth - 8, alignment: .trailing)
                Rectangle()
                    .fill(Color(LifeBoardColorTokens.foundationHairline).opacity(offset % 2 == 0 ? 0.72 : 0.42))
                    .frame(width: max(0, width - rulerWidth), height: 1)
            }
            .offset(y: CGFloat(offset) * hourHeight)
        }
    }

    private func freeWindowLayer(width: CGFloat) -> some View {
        ForEach(snapshot.freeWindows) { window in
            Button {
                createBlock("Focus block", window.startAt, min(window.duration, 60 * 60), nil)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open · \(durationLabel(window.duration))")
                        .font(.caption.weight(.semibold))
                    if blockHeight(from: window.startAt, to: window.endAt) >= 46 {
                        Text("Drop a task or tap to reserve")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .padding(.horizontal, 9)
                .frame(width: max(1, width - rulerWidth - 8), height: blockHeight(from: window.startAt, to: window.endAt), alignment: .topLeading)
                .background(Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
            }
            .buttonStyle(.plain)
            .offset(x: rulerWidth, y: yPosition(window.startAt))
            .dropDestination(for: String.self) { values, _ in
                guard let id = values.lazy.compactMap(UUID.init(uuidString:)).first,
                      let task = taskForID(id), task.dependenciesReady else { return false }
                createBlock(task.title, window.startAt, min(window.duration, task.estimatedDuration ?? 60 * 60), task.id)
                return true
            } isTargeted: { _ in }
            .accessibilityLabel("Open window, \(timeLabel(window.startAt)) to \(timeLabel(window.endAt))")
            .accessibilityHint("Creates a focus block. A task can also be dropped here.")
            .accessibilityIdentifier("plan.canvas.freeWindow.\(window.id)")
        }
    }

    /// Every scheduled thing on the spine, as intervals the lane resolver can
    /// pack. Commitments and blocks share one lane space because they overlap
    /// each other, not just their own kind.
    private var lanePlacements: [String: PlanTimelineLaneResolver.Placement] {
        let items = snapshot.commitments.map {
            PlanTimelineLaneResolver.Item(id: "commitment:\($0.id)", start: $0.startAt, end: $0.endAt)
        } + snapshot.blocks.map {
            PlanTimelineLaneResolver.Item(id: "block:\($0.id.uuidString)", start: $0.startAt, end: $0.endAt)
        }
        return PlanTimelineLaneResolver.placements(for: items)
    }

    /// One horizontally scrollable strip per overlapping cluster.
    ///
    /// Concurrent items used to be drawn at the same x, so a busy hour rendered
    /// as an unreadable pile. Each cluster now gets its own lane space: two
    /// abreast share the width, and anything denser keeps a readable lane width
    /// and scrolls sideways inside its own time band, so the vertical position
    /// still tells the truth about when things happen.
    private func clusterLayer(width: CGFloat) -> some View {
        let placements = lanePlacements
        let contentWidth = max(1, width - rulerWidth - 18)
        let clusters = timelineClusters(placements: placements)
        return ForEach(clusters) { cluster in
            let metrics = PlanTimelineLaneResolver.laneMetrics(
                laneCount: cluster.laneCount,
                availableWidth: contentWidth,
                spacing: laneSpacing
            )
            // Sizing happens inside `clusterBody`. A second frame out here used
            // to wrap the scrolling case, and the pair of them left the
            // ScrollView free to size itself to its content: nothing scrolled,
            // and the lanes past the edge were merely clipped by the card.
            clusterBody(cluster, metrics: metrics, contentWidth: contentWidth)
                .offset(x: rulerWidth + 6, y: cluster.top)
        }
    }

    @ViewBuilder
    private func clusterBody(
        _ cluster: TimelineCluster,
        metrics: (laneWidth: CGFloat, scrolls: Bool),
        contentWidth: CGFloat
    ) -> some View {
        if metrics.scrolls {
            PlanClusterStrip(
                contentWidth: contentWidth,
                laneCount: cluster.laneCount,
                laneWidth: metrics.laneWidth,
                spacing: laneSpacing,
                height: cluster.height
            ) {
                clusterLanes(cluster, laneWidth: metrics.laneWidth)
            }
            .accessibilityLabel("\(cluster.laneCount) overlapping items, swipe sideways to see the rest")
        } else {
            clusterLanes(cluster, laneWidth: metrics.laneWidth)
                .frame(width: contentWidth, height: cluster.height, alignment: .topLeading)
        }
    }

    private func clusterLanes(_ cluster: TimelineCluster, laneWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(cluster.commitments) { entry in
                commitmentCard(entry.commitment, width: laneWidth)
                    .offset(
                        x: CGFloat(entry.lane) * (laneWidth + laneSpacing),
                        y: yPosition(entry.commitment.startAt) - cluster.top
                    )
            }
            ForEach(cluster.blocks) { entry in
                blockCard(entry.block, width: laneWidth)
                    .offset(
                        x: CGFloat(entry.lane) * (laneWidth + laneSpacing),
                        y: yPosition(entry.block.startAt) - cluster.top
                    )
            }
        }
        .frame(
            width: CGFloat(cluster.laneCount) * laneWidth + CGFloat(max(0, cluster.laneCount - 1)) * laneSpacing,
            alignment: .topLeading
        )
    }

    private func commitmentCard(_ commitment: PlanningFixedCommitment, width: CGFloat) -> some View {
        let conflict = conflicts(
            start: commitment.startAt,
            end: commitment.endAt,
            excludingCommitmentID: commitment.id,
            excludingBlockID: UUID(uuidString: commitment.id)
        )
        // Same reasoning as the block card: once lanes split the canvas the
        // icons eat the title, and the tint already says "conflict".
        let compact = width < 140
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if compact == false {
                    Image(systemName: commitment.source == .externalCalendar ? "calendar" : "lock.fill")
                }
                Text(commitment.title).lineLimit(1)
                if conflict, compact == false { Image(systemName: "exclamationmark.triangle.fill") }
            }
            .font(.caption.weight(.semibold))
            Text(
                compact
                    ? timeLabel(commitment.startAt)
                    : "\(timeLabel(commitment.startAt))–\(timeLabel(commitment.endAt)) · read-only"
            )
            .font(.caption2).lineLimit(1)
        }
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
        .padding(.horizontal, compact ? 5 : 9)
        .frame(
            width: max(1, width),
            height: blockHeight(from: commitment.startAt, to: commitment.endAt),
            alignment: .topLeading
        )
        .background(
            conflict
                ? Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.20)
                : Color(LifeBoardColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(commitment.title), \(timeLabel(commitment.startAt)) to \(timeLabel(commitment.endAt))\(conflict ? ", conflicts with another item" : "")")
    }

    private func blockCard(_ block: InternalTimeBlock, width: CGFloat) -> some View {
        PlanCanvasBlock(
                block: block,
                width: max(1, width),
                height: blockHeight(from: block.startAt, to: block.endAt),
                hourHeight: hourHeight,
                hasConflict: conflicts(
                    start: block.startAt,
                    end: block.endAt,
                    excludingCommitmentID: block.id.uuidString,
                    excludingBlockID: block.id
                ),
                // Evaluated against the snapped candidate slot while dragging,
                // so a conflict is shown on the spine before the drop rather
                // than reported afterwards.
                conflictAt: { minutesDelta in
                    conflicts(
                        start: block.startAt.addingTimeInterval(TimeInterval(minutesDelta * 60)),
                        end: block.endAt.addingTimeInterval(TimeInterval(minutesDelta * 60)),
                        excludingCommitmentID: block.id.uuidString,
                        excludingBlockID: block.id
                    )
                },
                minuteBounds: minuteBounds(for: block),
                boundaryDates: boundaryDates(excluding: block.id),
                move: { moveBlock(block, $0) },
                resize: { resizeBlock(block, $0) },
                resizeEdges: { resizeBlockEdges(block, $0, $1) },
                split: { splitBlock(block) },
                delete: { deleteBlock(block) },
                focus: { startFocus(block) }
        )
    }

    private func boundaryDates(excluding blockID: UUID) -> [Date] {
        snapshot.commitments.flatMap { [$0.startAt, $0.endAt] }
            + snapshot.blocks
                .filter { $0.id != blockID }
                .flatMap { [$0.startAt, $0.endAt] }
    }

    private var laneSpacing: CGFloat { 6 }

    /// A group of items that overlap each other, positioned as one band.
    struct TimelineCluster: Identifiable {
        struct CommitmentEntry: Identifiable {
            let commitment: PlanningFixedCommitment
            let lane: Int
            var id: String { commitment.id }
        }

        struct BlockEntry: Identifiable {
            let block: InternalTimeBlock
            let lane: Int
            var id: UUID { block.id }
        }

        let id: Int
        let laneCount: Int
        let top: CGFloat
        let height: CGFloat
        let commitments: [CommitmentEntry]
        let blocks: [BlockEntry]
    }

    private func timelineClusters(
        placements: [String: PlanTimelineLaneResolver.Placement]
    ) -> [TimelineCluster] {
        var commitmentsByCluster: [Int: [TimelineCluster.CommitmentEntry]] = [:]
        var blocksByCluster: [Int: [TimelineCluster.BlockEntry]] = [:]
        var laneCounts: [Int: Int] = [:]
        var spans: [Int: (top: CGFloat, bottom: CGFloat)] = [:]

        func extend(_ clusterID: Int, start: Date, end: Date) {
            let top = yPosition(start)
            let bottom = top + blockHeight(from: start, to: end)
            let current = spans[clusterID]
            spans[clusterID] = (
                min(current?.top ?? top, top),
                max(current?.bottom ?? bottom, bottom)
            )
        }

        for commitment in snapshot.commitments {
            guard let placement = placements["commitment:\(commitment.id)"] else { continue }
            commitmentsByCluster[placement.clusterID, default: []].append(
                .init(commitment: commitment, lane: placement.lane)
            )
            laneCounts[placement.clusterID] = placement.laneCount
            extend(placement.clusterID, start: commitment.startAt, end: commitment.endAt)
        }
        for block in snapshot.blocks {
            guard let placement = placements["block:\(block.id.uuidString)"] else { continue }
            blocksByCluster[placement.clusterID, default: []].append(
                .init(block: block, lane: placement.lane)
            )
            laneCounts[placement.clusterID] = placement.laneCount
            extend(placement.clusterID, start: block.startAt, end: block.endAt)
        }

        return laneCounts.keys.sorted().compactMap { clusterID in
            guard let span = spans[clusterID] else { return nil }
            return TimelineCluster(
                id: clusterID,
                laneCount: laneCounts[clusterID] ?? 1,
                top: span.top,
                height: max(1, span.bottom - span.top),
                commitments: commitmentsByCluster[clusterID] ?? [],
                blocks: blocksByCluster[clusterID] ?? []
            )
        }
    }

    private var timelineStart: Date {
        let base = snapshot.day.startDate() ?? Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: base) ?? base
    }

    private var startHour: Int {
        let dates = snapshot.commitments.map(\.startAt) + snapshot.blocks.map(\.startAt) + snapshot.freeWindows.map(\.startAt)
        guard let first = dates.min() else { return 8 }
        return max(0, Calendar.current.component(.hour, from: first) - 1)
    }

    private var endHour: Int {
        let dates = snapshot.commitments.map(\.endAt) + snapshot.blocks.map(\.endAt) + snapshot.freeWindows.map(\.endAt)
        guard let last = dates.max() else { return 18 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: last)
        return min(24, max(startHour + 4, (components.hour ?? 17) + ((components.minute ?? 0) > 0 ? 2 : 1)))
    }

    private var hourSpan: Int { max(4, endHour - startHour) }
    private var timelineHeight: CGFloat { CGFloat(hourSpan) * hourHeight + 1 }

    /// How far a block may travel, in minutes, before it would leave the drawn
    /// day. The drag rubber-bands past these rather than stopping dead, so the
    /// edge of the canvas is felt instead of just refusing to move.
    private func minuteBounds(for block: InternalTimeBlock) -> ClosedRange<Int> {
        let timelineEnd = timelineStart.addingTimeInterval(TimeInterval(hourSpan) * 3_600)
        let earliest = Int(timelineStart.timeIntervalSince(block.startAt) / 60)
        let latest = Int(timelineEnd.timeIntervalSince(block.endAt) / 60)
        guard earliest <= latest else { return 0...0 }
        return earliest...latest
    }

    private func yPosition(_ date: Date) -> CGFloat {
        max(0, CGFloat(date.timeIntervalSince(timelineStart) / 3_600) * hourHeight)
    }

    private func blockHeight(from start: Date, to end: Date) -> CGFloat {
        max(30, CGFloat(max(0, end.timeIntervalSince(start)) / 3_600) * hourHeight - 3)
    }

    private var conflictCount: Int {
        let commitments = snapshot.commitments.filter {
            conflicts(start: $0.startAt, end: $0.endAt, excludingCommitmentID: $0.id, excludingBlockID: UUID(uuidString: $0.id))
        }.count
        let blocks = snapshot.blocks.filter {
            conflicts(start: $0.startAt, end: $0.endAt, excludingCommitmentID: $0.id.uuidString, excludingBlockID: $0.id)
        }.count
        return commitments + blocks
    }

    private func conflicts(start: Date, end: Date, excludingCommitmentID: String?, excludingBlockID: UUID?) -> Bool {
        let overlapsCommitment = snapshot.commitments.contains { value in
            value.id != excludingCommitmentID && value.startAt < end && value.endAt > start
        }
        let overlapsBlock = snapshot.blocks.contains { value in
            value.id != excludingBlockID && value.startAt < end && value.endAt > start
        }
        return overlapsCommitment || overlapsBlock
    }

    private func canvasLegend(_ title: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 8)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        guard hour < 24 else { return "12 AM" }
        let base = Calendar.current.startOfDay(for: Date())
        let date = Calendar.current.date(byAdding: .hour, value: hour, to: base) ?? base
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func timeLabel(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func durationLabel(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h\(minutes % 60 == 0 ? "" : " \(minutes % 60)m")"
    }
}

/// A horizontally pannable band of overlapping lanes.
///
/// This does by hand what a `ScrollView(.horizontal)` should have done. Nested
/// inside the canvas — a `GeometryReader` holding a `ZStack` of `.offset` layers,
/// itself inside the page's vertical scroll — the scroll view never received a
/// pan: it sized itself to its content and the lanes past the edge were simply
/// clipped, unreachable. Owning the offset makes the behaviour explicit and
/// testable instead of dependent on how SwiftUI arbitrates nested scrolling.
///
/// The gesture is attached simultaneously so a vertical drag still scrolls the
/// page underneath; only the horizontal component is consumed here.
/// One VoiceOver action per repair the deck offers.
///
/// Written as a modifier because `accessibilityAction` cannot be applied in a
/// loop over a variable-length list; each direction needs its own named action
/// so a flick and a rotor selection reach exactly the same set of repairs.
private struct PlanRepairAccessibilityActions: ViewModifier {
    let candidates: [PlanRepairAction]
    let title: (PlanRepairAction) -> String
    let perform: (PlanRepairAction) -> Void

    private func action(_ slot: Int) -> PlanRepairAction? {
        slot < candidates.count ? candidates[slot] : nil
    }

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: action(0).map { Text(title($0)) } ?? Text("Apply first repair")) {
                if let value = action(0) { perform(value) }
            }
            .accessibilityAction(named: action(1).map { Text(title($0)) } ?? Text("Apply second repair")) {
                if let value = action(1) { perform(value) }
            }
            .accessibilityAction(named: action(2).map { Text(title($0)) } ?? Text("Apply third repair")) {
                if let value = action(2) { perform(value) }
            }
            .accessibilityAction(named: action(3).map { Text(title($0)) } ?? Text("Apply fourth repair")) {
                if let value = action(3) { perform(value) }
            }
    }
}

private struct PlanClusterStrip<Content: View>: View {
    let contentWidth: CGFloat
    let laneCount: Int
    let laneWidth: CGFloat
    let spacing: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    @State private var committed: CGFloat = 0
    @GestureState private var live: CGFloat = 0

    private var totalWidth: CGFloat {
        PlanTimelineLaneResolver.stripWidth(
            laneCount: laneCount, laneWidth: laneWidth, spacing: spacing
        )
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        PlanTimelineLaneResolver.clampedStripOffset(
            value, contentWidth: contentWidth, stripWidth: totalWidth
        )
    }

    var body: some View {
        content
            .frame(width: totalWidth, alignment: .topLeading)
            .offset(x: clamp(committed + live))
            .frame(width: contentWidth, height: height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .updating($live) { value, state, _ in
                        // Vertical intent belongs to the page, not the strip.
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        committed = clamp(committed + value.translation.width)
                    }
            )
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.86), value: committed)
    }
}

private struct PlanCanvasBlock: View {
    let block: InternalTimeBlock
    let width: CGFloat
    let height: CGFloat
    let hourHeight: CGFloat
    let hasConflict: Bool
    let conflictAt: (Int) -> Bool
    let minuteBounds: ClosedRange<Int>
    let boundaryDates: [Date]
    let move: (Int) -> Void
    let resize: (Int) -> Void
    let resizeEdges: (Int, Int) -> Void
    let split: () -> Void
    let delete: () -> Void
    let focus: () -> Void

    /// The snapped candidate, in minutes from the block's current start. Held as
    /// gesture state so an interrupted drag cannot strand the block off-grid.
    @GestureState private var draggedMinutes: Int = 0
    @GestureState private var topResizeMinutes: Int = 0
    @GestureState private var bottomResizeMinutes: Int = 0
    /// Mirrors `draggedMinutes` outside the gesture so the detent haptic fires
    /// exactly once per crossing rather than on every touch sample.
    @State private var lastDetent: Int = 0

    private func snapped(_ translation: CGFloat) -> Int {
        PlanBlockSnapResolver.snappedMinutes(
            translation: translation,
            hourHeight: hourHeight,
            bounds: minuteBounds
        )
    }

    /// A lane is this narrow as soon as anything overlaps, since two lanes split
    /// the canvas. At that width the chrome costs more than it says: the accent
    /// bar, the inline conflict triangle and a full-size menu button together
    /// squeeze the title down to "Foc…". Conflict still reads from the card's
    /// tint and border and from the count in the canvas header, so the
    /// decoration goes and the name stays.
    private var isCompact: Bool { width < 140 }

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 4 : 7) {
            if isCompact == false {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(LifeBoardColorTokens.foundationApricotAccent))
                    .frame(width: 5)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(block.title).lineLimit(1)
                    if showsConflict, isCompact == false {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                // While dragging, the row reads out the slot it would land in,
                // so the commitment is legible before the finger lifts.
                Text("\(candidateStart.formatted(date: .omitted, time: .shortened))–\(candidateEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).lineLimit(1)
                    .monospacedDigit()
            }
            Spacer(minLength: 2)
            Menu {
                Button("Start focus", systemImage: "timer", action: focus)
                // The drag snaps to five minutes for small corrections, so the
                // menu has to offer the same granularity or the pointer and
                // keyboard paths cannot reach every slot the finger can.
                Button("Move 5 minutes earlier", systemImage: "arrow.up") { move(-5) }
                Button("Move 5 minutes later", systemImage: "arrow.down") { move(5) }
                Button("Move 15 minutes earlier", systemImage: "arrow.up.to.line") { move(-15) }
                Button("Move 15 minutes later", systemImage: "arrow.down.to.line") { move(15) }
                Button("Add 15 minutes", systemImage: "plus") { resize(15) }
                Button("Remove 15 minutes", systemImage: "minus") { resize(-15) }
                Button("Split", systemImage: "rectangle.split.2x1", action: split)
                Button("Remove", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: isCompact ? 22 : 30, height: 30)
            }
        }
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
        .padding(.leading, isCompact ? 5 : 7)
        .padding(.trailing, isCompact ? 2 : 5)
        .frame(
            width: width,
            height: max(
                16,
                height + CGFloat(bottomResizeMinutes - topResizeMinutes) / 60 * hourHeight
            ),
            alignment: .topLeading
        )
        .background(
            showsConflict
                ? Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.34)
                : Color(LifeBoardColorTokens.foundationSurfaceSelected),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    Color(LifeBoardColorTokens.foundationApricotAccent)
                        .opacity(isDragging ? 0.9 : 0.48),
                    lineWidth: isDragging ? 2 : 1
                )
        }
        .offset(y: CGFloat(draggedMinutes + topResizeMinutes) / 60 * hourHeight)
        .contentShape(Rectangle())
        // Press and hold before moving, the way the system calendar does.
        //
        // A plain drag here used to claim every touch that landed on a block,
        // and blocks cover nearly all of a crowded cluster — so the horizontal
        // scroll that reaches the lanes past the second one could never win the
        // gesture, and those items were unreachable. Requiring the press frees
        // ordinary drags to scroll the strip and keeps the move deliberate.
        .gesture(
            LongPressGesture(minimumDuration: 0.28)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($draggedMinutes) { value, state, _ in
                    guard case .second(true, let drag?) = value else { return }
                    state = PlanBlockSnapResolver.snappedMinutes(
                        translation: drag.translation.height,
                        hourHeight: hourHeight,
                        bounds: minuteBounds
                    )
                }
                .onChanged { value in
                    switch value {
                    case .second(true, nil):
                        // The hold registered: say so, or the block feels dead
                        // until the finger has already moved.
                        LifeBoardHaptic.settle.play()
                    case .second(true, let drag?):
                        let snapped = snapped(drag.translation.height)
                        guard snapped != lastDetent else { return }
                        lastDetent = snapped
                        LifeBoardHaptic.pick.play()
                    default:
                        break
                    }
                }
                .onEnded { value in
                    lastDetent = 0
                    guard case .second(true, let drag?) = value else { return }
                    let snapped = snapped(drag.translation.height)
                    if snapped != 0 {
                        LifeBoardHaptic.commit.play()
                        move(snapped)
                    } else if abs(drag.translation.height) > 8 {
                        LifeBoardHaptic.settle.play()
                    }
                }
        )
        .overlay(alignment: .top) {
            resizeHandle(label: "Resize start")
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($topResizeMinutes) { value, state, _ in
                            state = resizeSnap(
                                value.translation.height,
                                bounds: -1_440...max(0, Int(block.duration / 60) - 15),
                                movingEdgeAt: block.startAt
                            )
                        }
                        .onEnded { value in
                            let delta = resizeSnap(
                                value.translation.height,
                                bounds: -1_440...max(0, Int(block.duration / 60) - 15),
                                movingEdgeAt: block.startAt
                            )
                            guard delta != 0 else { return }
                            LifeBoardHaptic.commit.play()
                            resizeEdges(delta, 0)
                        }
                )
        }
        .overlay(alignment: .bottom) {
            resizeHandle(label: "Resize end")
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($bottomResizeMinutes) { value, state, _ in
                            state = resizeSnap(
                                value.translation.height,
                                bounds: min(0, 15 - Int(block.duration / 60))...1_440,
                                movingEdgeAt: block.endAt
                            )
                        }
                        .onEnded { value in
                            let delta = resizeSnap(
                                value.translation.height,
                                bounds: min(0, 15 - Int(block.duration / 60))...1_440,
                                movingEdgeAt: block.endAt
                            )
                            guard delta != 0 else { return }
                            LifeBoardHaptic.commit.play()
                            resizeEdges(0, delta)
                        }
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.startAt.formatted(date: .omitted, time: .shortened)) to \(block.endAt.formatted(date: .omitted, time: .shortened))\(hasConflict ? ", conflicts with another item" : "")")
        .accessibilityAdjustableAction { direction in move(direction == .increment ? 15 : -15) }
        .accessibilityAction(named: "Move 5 minutes earlier") { move(-5) }
        .accessibilityAction(named: "Move 5 minutes later") { move(5) }
        .accessibilityAction(named: "Add 15 minutes") { resize(15) }
        .accessibilityAction(named: "Remove 15 minutes") { resize(-15) }
        .accessibilityAction(named: "Start focus", focus)
        .accessibilityIdentifier("plan.canvas.block.\(block.id.uuidString)")
    }

    private var isDragging: Bool {
        draggedMinutes != 0 || topResizeMinutes != 0 || bottomResizeMinutes != 0
    }

    private var candidateStart: Date {
        block.startAt.addingTimeInterval(TimeInterval((draggedMinutes + topResizeMinutes) * 60))
    }

    private var candidateEnd: Date {
        block.endAt.addingTimeInterval(TimeInterval((draggedMinutes + bottomResizeMinutes) * 60))
    }

    private func resizeSnap(
        _ translation: CGFloat,
        bounds: ClosedRange<Int>,
        movingEdgeAt: Date
    ) -> Int {
        PlanBlockSnapResolver.boundaryAwareSnappedMinutes(
            translation: translation,
            hourHeight: hourHeight,
            movingEdgeAt: movingEdgeAt,
            boundaries: boundaryDates,
            bounds: bounds
        )
    }

    private func resizeHandle(label: String) -> some View {
        Capsule()
            .fill(Color(LifeBoardColorTokens.foundationApricotAccent))
            .frame(width: 30, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .accessibilityHint("Drag, or use the duration actions in the menu")
    }

    /// During a drag the block reports the candidate slot's conflict, not its
    /// current one — otherwise dragging *out* of a clash keeps showing the
    /// warning and dragging *into* one shows nothing until the drop.
    private var showsConflict: Bool {
        isDragging ? conflictAt(draggedMinutes) : hasConflict
    }
}

private struct ProjectTemplatePicker: View {
    let service: ProjectTemplateInstantiationService
    let onCreated: (ProjectTemplateCreationReceipt) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templates: [Project] = []
    @State private var selectedTemplateID: UUID?
    @State private var projectName = ""
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Finding project templates…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if templates.isEmpty {
                    ContentUnavailableView(
                        "No project templates",
                        systemImage: "folder.badge.plus",
                        description: Text(
                            "Archive a project marked as a template source, then return here to create a fresh copy."
                        )
                    )
                } else {
                    List {
                        Section("Choose a template") {
                            ForEach(templates, id: \.id) { template in
                                templateButton(template)
                            }
                        }

                        Section("New project") {
                            TextField("Project name", text: $projectName)
                                .textInputAutocapitalization(.words)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("plan.projectTemplates.name")

                            Button {
                                createProject()
                            } label: {
                                HStack {
                                    if isCreating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isCreating ? "Creating…" : "Create project")
                                        .frame(maxWidth: .infinity)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                selectedTemplateID == nil
                                    || projectName.trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ).isEmpty
                                    || isCreating
                            )
                            .accessibilityIdentifier("plan.projectTemplates.create")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Project template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadTemplates() }
        .alert(
            "Template unavailable",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if $0 == false { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func loadTemplates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            templates = try await service.templates()
            if let first = templates.first {
                selectedTemplateID = first.id
                projectName = defaultName(for: first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createProject() {
        guard let selectedTemplateID else { return }
        let resolvedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedName.isEmpty == false else { return }
        isCreating = true
        Task {
            do {
                let receipt = try await service.instantiate(
                    sourceProjectID: selectedTemplateID,
                    name: resolvedName
                )
                await MainActor.run {
                    isCreating = false
                    onCreated(receipt)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func defaultName(for template: Project) -> String {
        template.name.replacingOccurrences(of: " Template", with: "")
    }

    private func templateButton(_ template: Project) -> some View {
        let isSelected = selectedTemplateID == template.id
        let identifier = "plan.projectTemplates.template." + template.id.uuidString
        return Button {
            selectedTemplateID = template.id
            projectName = defaultName(for: template)
        } label: {
            templateRow(template)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier(identifier)
    }

    private func templateRow(_ template: Project) -> some View {
        let isSelected = selectedTemplateID == template.id
        return HStack(spacing: 12) {
            Image(systemName: template.icon.rawValue)
                .frame(width: 28)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                if let description = template.projectDescription,
                   description.isEmpty == false {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(
                    isSelected
                        ? Color.lifeboard(.statusSuccess)
                        : Color(LifeBoardColorTokens.inkSecondary)
                )
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct PlanBlockComposer: View {
    let day: PlanningDay
    let save: (String, Date, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start: Date
    @State private var minutes = 45.0

    init(day: PlanningDay, save: @escaping (String, Date, TimeInterval) -> Void) {
        self.day = day
        self.save = save
        let base = day.startDate() ?? Date()
        _start = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Block title", text: $title)
                DatePicker("Starts", selection: $start, displayedComponents: [.hourAndMinute])
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(minutes)) minutes")
                    Slider(value: $minutes, in: 15...180, step: 15)
                }
            }
            .navigationTitle("New time block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(title, start, minutes * 60); dismiss() }
                }
            }
        }
    }
}

private struct PlanWorkingHoursComposer: View {
    let save: (Set<Int>, Int, Int, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var activeWeekdays: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var bufferMinutes: Double

    init(profile: WorkingHoursProfile?, save: @escaping (Set<Int>, Int, Int, TimeInterval) -> Void) {
        self.save = save
        let intervals = profile?.intervalsByWeekday ?? [:]
        let first = intervals.values.flatMap { $0 }.first ?? WorkingHoursInterval(startMinute: 8 * 60, endMinute: 18 * 60)
        let base = Calendar.current.startOfDay(for: Date())
        _activeWeekdays = State(initialValue: Set(intervals.keys.isEmpty ? Array(2...6) : Array(intervals.keys)))
        _start = State(initialValue: Calendar.current.date(byAdding: .minute, value: first.startMinute, to: base) ?? base)
        _end = State(initialValue: Calendar.current.date(byAdding: .minute, value: first.endMinute, to: base) ?? base.addingTimeInterval(10 * 3_600))
        _bufferMinutes = State(initialValue: (profile?.bufferDuration ?? 30 * 60) / 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Working days") {
                    HStack {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                if activeWeekdays.contains(weekday) { activeWeekdays.remove(weekday) }
                                else { activeWeekdays.insert(weekday) }
                            } label: {
                                Text(weekdayLabel(weekday))
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(activeWeekdays.contains(weekday) ? Color(LifeBoardColorTokens.foundationSurfaceSelected) : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(activeWeekdays.contains(weekday) ? .isSelected : [])
                        }
                    }
                }
                Section("Daily window") {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                }
                Section("Protected buffer") {
                    Text("\(Int(bufferMinutes)) minutes remains unallocated.")
                    Slider(value: $bufferMinutes, in: 0...180, step: 15)
                }
            }
            .navigationTitle("Working hours")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let startMinute = Calendar.current.component(.hour, from: start) * 60 + Calendar.current.component(.minute, from: start)
                        let endMinute = Calendar.current.component(.hour, from: end) * 60 + Calendar.current.component(.minute, from: end)
                        save(activeWeekdays, startMinute, endMinute, bufferMinutes * 60)
                        dismiss()
                    }
                    .disabled(activeWeekdays.isEmpty)
                }
            }
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }
}

private extension View {
    /// Delegates to the canonical clay depth scale so Plan cards match Home
    /// and Track. This used to carry its own radius-4 shadow and 0.75pt
    /// stroke, which made Plan read subtly flatter than every other root.
    func foundationClayCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: LifeBoardFoundationRadius.card)
    }
}

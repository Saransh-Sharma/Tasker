import SwiftUI
import SwiftData
import CoreData
import LifeBoardTranscription
import UIKit
import VisionKit

struct RootActivityState: Hashable, Sendable {
    let isSelected: Bool
    let sceneIsActive: Bool

    static let active = RootActivityState(isSelected: true, sceneIsActive: true)

    var performsContinuousWork: Bool { isSelected && sceneIsActive }
}

private struct RootActivityStateKey: EnvironmentKey {
    static let defaultValue = RootActivityState.active
}

extension EnvironmentValues {
    var lifeBoardRootActivity: RootActivityState {
        get { self[RootActivityStateKey.self] }
        set { self[RootActivityStateKey.self] = newValue }
    }
}

/// Where each root rests relative to the one on screen.
///
/// A root change should read as travelling along the dock rather than as one
/// screen dissolving into another, so a root waits on the side it occupies in
/// the dock order: roots to the left of the current one wait on the left, roots
/// to the right wait on the right. Moving from Home to Track therefore carries
/// the eye left-to-right, the same direction the selected well travels.
///
/// The distance is deliberately short. A full-width page slide would fight the
/// dock's own selection movement and make every root change feel like a journey.
enum RootTransition {
    /// Far enough to give the change a direction, near enough to stay calm.
    static let slideDistance: CGFloat = 24

    /// Horizontal resting offset for `destination` while `selected` is on screen.
    ///
    /// The sign comes from dock order, and the magnitude is capped: roots three
    /// slots away are no further off than roots one slot away, because they are
    /// invisible either way and a longer throw only makes the arrival slower.
    static func offset(
        for destination: Destination,
        selected: Destination,
        distance: CGFloat = slideDistance
    ) -> CGFloat {
        guard destination != selected else { return 0 }
        let order = Destination.allCases
        guard let from = order.firstIndex(of: destination),
              let to = order.firstIndex(of: selected) else { return 0 }
        return from < to ? -distance : distance
    }
}

/// Which roots exist in the compact shell's stack, and which survive a change.
///
/// These are two different questions, and conflating them is what put a blank
/// frame between Home and Plan. The stack used to render a root only once
/// `visitedRoots` contained it, but that set is written from `onChange`, which
/// runs *after* the render pass that observed the new selection. So the first
/// pass after "Open Plan" drew a Plan that did not exist yet and a Home already
/// faded to zero — no visible root at all, and the system's white window
/// backing showed through for as long as Plan's stores took to build.
///
/// Selection is therefore sufficient on its own to render a root, and the
/// visited set answers only the second question: what stays behind afterwards.
enum RootRetention {
    /// True when `destination` belongs in the stack this render pass.
    ///
    /// Being selected is enough. There is no transaction in which the selected
    /// root is absent, so there is no interval with nothing on screen.
    static func isRendered(
        _ destination: Destination,
        selected: Destination,
        visited: Set<Destination>
    ) -> Bool {
        destination == selected || visited.contains(destination)
    }

    /// The visited set after a selection change.
    ///
    /// Dashboard roots accumulate so their scroll position and navigation depth
    /// survive. Eva is dropped on the way out because its chat runtime owns
    /// visibility-scoped work that should not keep running off screen — it is
    /// still rendered while selected, so eviction never blanks it either.
    static func retained(
        visited: Set<Destination>,
        previous: Destination?,
        selected: Destination
    ) -> Set<Destination> {
        var next = visited
        next.insert(selected)
        if previous == .eva, selected != .eva {
            next.remove(.eva)
        }
        return next
    }
}

// MARK: - Display panel

/// Visual clock only. Domain sessions always retain their canonical timestamps.
struct ActiveVisibleTimeline<Content: View>: View {
    let interval: TimeInterval
    var isActive: Bool
    let content: (VisibleTimelineContext) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardRootActivity) private var rootActivity
    @State private var isVisible = true

    init(every interval: TimeInterval, isActive: Bool = true,
         @ViewBuilder content: @escaping (VisibleTimelineContext) -> Content) {
        self.interval = interval
        self.isActive = isActive
        self.content = content
    }

    var body: some View {
        let active = isActive && isVisible && scenePhase == .active && rootActivity.performsContinuousWork
        TimelineView(VisiblePeriodicSchedule(interval: interval, active: active)) { context in
            content(VisibleTimelineContext(date: context.date))
        }
        .modifier(VisualTimelineRegistration(isActive: active))
        .onScrollVisibilityChange(threshold: 0.001) { isVisible = $0 }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

struct VisibleTimelineContext { let date: Date }

struct VisiblePeriodicSchedule: TimelineSchedule {
    let interval: TimeInterval
    let active: Bool
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        if !active { return AnySequence([startDate]) }
        return AnySequence(PeriodicTimelineSchedule(from: startDate, by: interval).entries(from: startDate, mode: mode))
    }
}

struct ActiveVisibleAnimationTimeline<Content: View>: View {
    var minimumInterval: Double? = nil
    let content: (VisibleTimelineContext) -> Content

    init(minimumInterval: Double? = nil,
         @ViewBuilder content: @escaping (VisibleTimelineContext) -> Content) {
        self.minimumInterval = minimumInterval
        self.content = content
    }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardRootActivity) private var rootActivity
    @State private var isVisible = true

    var body: some View {
        let active = isVisible && scenePhase == .active && rootActivity.performsContinuousWork
        TimelineView(.animation(minimumInterval: minimumInterval, paused: !active)) { context in
            content(VisibleTimelineContext(date: context.date))
        }
        .modifier(VisualTimelineRegistration(isActive: active))
        .onScrollVisibilityChange(threshold: 0.001) { isVisible = $0 }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

@MainActor
enum VisualTimelineDiagnostics {
    private(set) static var activeIDs: Set<UUID> = []

    static func setActive(_ active: Bool, id: UUID) {
        let changed = active ? activeIDs.insert(id).inserted : activeIDs.remove(id) != nil
        if changed { PerformanceTrace.event("ActiveVisualTimelines", value: activeIDs.count) }
    }
}

struct VisualTimelineRegistration: ViewModifier {
    let isActive: Bool
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content
            .onChange(of: isActive, initial: true) { _, active in
                VisualTimelineDiagnostics.setActive(active, id: id)
            }
            .onAppear { VisualTimelineDiagnostics.setActive(isActive, id: id) }
            .onDisappear { VisualTimelineDiagnostics.setActive(false, id: id) }
    }
}

/// One producer owns refresh work. Each caller waits for the revision it requested;
/// cancellation removes only that waiter, never the producer used by newer callers.
@MainActor
final class PresentationRefreshDrain {
    private var worker: Task<Void, Never>?
    private var pending: (@MainActor () async -> Void)?
    private var requested: UInt64 = 0
    private var completed: UInt64 = 0
    var revision: UInt64 { requested }
    var isRunning: Bool { worker != nil }
    private var waiters: [UUID: (UInt64, CheckedContinuation<Void, Never>)] = [:]

    func run(_ operation: @escaping @MainActor () async -> Void) async {
        guard !Task.isCancelled else { return }
        requested &+= 1
        let revision = requested
        pending = operation
        if worker == nil {
            worker = Task { [weak self] in
                await self?.drain()
            }
        }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled || completed >= revision { continuation.resume() }
                else { waiters[id] = (revision, continuation) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.waiters.removeValue(forKey: id)?.1.resume()
            }
        }
    }

    private func drain() async {
        while let operation = pending {
            pending = nil
            let revision = requested
            await operation()
            // If another request arrived during the read, its committed data
            // may be newer. Release callers only after that pass is published.
            guard pending == nil else { continue }
            completed = revision
            let ready = waiters.filter { $0.value.0 <= completed }
            for (id, waiter) in ready {
                waiters.removeValue(forKey: id)
                waiter.1.resume()
            }
        }
        worker = nil
    }
}

enum ProjectionRefreshOutcome: Equatable, Sendable {
    case applied(SourceRevisionVector)
    case failed(String)
    case cancelled
}

/// Shared mutation refreshes release each caller when its required revisions
/// have published, without waiting for newer or unrelated requests to settle.
@MainActor
final class CommittedProjectionRefresh {
    typealias Operation = @MainActor () async -> ProjectionRefreshOutcome
    private struct Waiter {
        let required: SourceRevisionVector
        let domains: Set<ProjectionDomain>
        let continuation: CheckedContinuation<ProjectionRefreshOutcome, Never>
    }
    private var waiters: [UUID: Waiter] = [:]
    private struct Request {
        let domains: Set<ProjectionDomain>
        let operation: Operation
    }
    private var pending: Request?
    private var worker: Task<Void, Never>?
    private var generation = 0

    func run(required: SourceRevisionVector, domains: Set<ProjectionDomain>,
             operation: @escaping Operation) async -> ProjectionRefreshOutcome {
        guard !Task.isCancelled else { return .cancelled }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(returning: .cancelled); return }
                waiters[id] = .init(required: required, domains: domains, continuation: continuation)
                pending = Request(domains: domains, operation: operation)
                if worker == nil {
                    let current = generation
                    worker = Task { [weak self] in await self?.drain(generation: current) }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.waiters.removeValue(forKey: id)?.continuation.resume(returning: .cancelled)
            }
        }
    }

    /// Presentation cancellation is distinct from cancellation of one waiter.
    /// A new generation may start before a non-cancellable repository read ends.
    func cancel() {
        generation &+= 1
        worker?.cancel()
        worker = nil
        pending = nil
        let unfinished = waiters.values
        waiters.removeAll()
        for waiter in unfinished { waiter.continuation.resume(returning: .cancelled) }
    }

    private func drain(generation current: Int) async {
        while let request = pending {
            pending = nil
            let outcome = await request.operation()
            guard current == generation, !Task.isCancelled else { return }
            if case .applied(let published) = outcome {
                let satisfied = waiters.filter {
                    $0.value.domains.isSubset(of: request.domains)
                        && published.represents($0.value.required, domains: $0.value.domains)
                }
                for (id, waiter) in satisfied {
                    waiters.removeValue(forKey: id)
                    waiter.continuation.resume(returning: outcome)
                }
            }
            if pending == nil {
                // A successful read older than the required commit is not success
                // for the remaining callers. Never silently finish with old data.
                let remaining: ProjectionRefreshOutcome = if case .applied = outcome {
                    .failed("The committed change has not reached this projection.")
                } else { outcome }
                let unfinished = waiters.values
                waiters.removeAll()
                for waiter in unfinished { waiter.continuation.resume(returning: remaining) }
            }
        }
        worker = nil
    }
}

enum ProjectionDomain: String, CaseIterable, Hashable, Sendable {
    case tasks, planning, focus, tracking, journal, wellness, nutrition, fasting, goals, routines, calendar
}

struct SourceRevisionVector: Equatable, Sendable {
    private var values: [ProjectionDomain: UInt64] = [:]
    subscript(_ domain: ProjectionDomain) -> UInt64 { values[domain, default: 0] }

    mutating func advance(_ domains: Set<ProjectionDomain>) {
        for domain in domains { values[domain, default: 0] &+= 1 }
    }

    func merged(with other: Self) -> Self {
        var result = self
        for domain in ProjectionDomain.allCases where other[domain] > result[domain] {
            result.values[domain] = other[domain]
        }
        return result
    }

    func matches(_ other: Self, domains: Set<ProjectionDomain>) -> Bool {
        domains.allSatisfy { self[$0] == other[$0] }
    }

    func represents(_ required: Self, domains: Set<ProjectionDomain>) -> Bool {
        domains.allSatisfy { self[$0] >= required[$0] }
    }
}

enum ProjectionRecordKind: Hashable, Sendable { case hydration, mood }

struct DomainInvalidation: Sendable {
    let containerID: ObjectIdentifier
    let domains: Set<ProjectionDomain>
    let affectedIDs: Set<UUID>
    let revisions: SourceRevisionVector
    let transactionAuthor: String?
    var recordKinds: Set<ProjectionRecordKind> = []
    var requiresFullDomainRefresh = false

    func merged(with other: Self) -> Self {
        precondition(containerID == other.containerID)
        let ids = affectedIDs.union(other.affectedIDs)
        let full = requiresFullDomainRefresh || other.requiresFullDomainRefresh || ids.count > 256
        return .init(containerID: containerID, domains: domains.union(other.domains),
            affectedIDs: full ? [] : ids, revisions: revisions.merged(with: other.revisions),
            transactionAuthor: transactionAuthor == other.transactionAuthor ? transactionAuthor : nil,
            recordKinds: recordKinds.union(other.recordKinds), requiresFullDomainRefresh: full)
    }
}

/// One merged immutable invalidation and one wake-up, regardless of save burst
/// size. Slow consumers retain all affected domains; IDs fall back to a full
/// domain refresh above the bounded targeting budget.
final class ProjectionInvalidationSubscription: @unchecked Sendable {
    let wakes: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let lock = NSLock()
    private let recordKinds: Set<ProjectionRecordKind>
    private let onCancel: @Sendable () -> Void
    private var pending: DomainInvalidation?
    private var finished = false

    init(recordKinds: Set<ProjectionRecordKind>, onCancel: @escaping @Sendable () -> Void) {
        let channel = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        wakes = channel.stream
        continuation = channel.continuation
        self.recordKinds = recordKinds
        self.onCancel = onCancel
        continuation.onTermination = { [weak self] _ in self?.cancel() }
    }

    func enqueue(_ event: DomainInvalidation) {
        guard !event.recordKinds.isDisjoint(with: recordKinds) else { return }
        lock.lock()
        guard !finished else { lock.unlock(); return }
        // Merging with itself also bounds a single large durable transaction.
        pending = pending.map { $0.merged(with: event) } ?? event.merged(with: event)
        lock.unlock()
        continuation.yield(())
    }

    func takePending() -> DomainInvalidation? {
        lock.lock(); defer { lock.unlock() }
        let result = pending
        pending = nil
        return result
    }

    func cancel() {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        pending = nil
        lock.unlock()
        continuation.finish()
        onCancel()
    }
}

/// One observer per live persistence container. Saves advance the ledger on the
/// saving queue before context.save() returns. No managed objects cross queues.
final class ProjectionRevisionLedger: @unchecked Sendable {
    private final class WeakEntry {
        weak var value: ProjectionRevisionLedger?
        init(_ value: ProjectionRevisionLedger) { self.value = value }
    }
    private final class Registry: @unchecked Sendable {
        let lock = NSLock()
        var entries: [ObjectIdentifier: WeakEntry] = [:]
    }
    private static let registry = Registry()
    private let lock = NSLock()
    private var revisions = SourceRevisionVector()
    private var lastInvalidation: DomainInvalidation?
    private var subscriptions: [UUID: ProjectionInvalidationSubscription] = [:]
    private let containerID: ObjectIdentifier
    private let coordinator: NSPersistentStoreCoordinator
    private var observer: NSObjectProtocol?

    static func shared(for container: NSPersistentContainer) -> ProjectionRevisionLedger {
        let id = ObjectIdentifier(container.persistentStoreCoordinator)
        registry.lock.lock()
        defer { registry.lock.unlock() }
        registry.entries = registry.entries.filter { $0.value.value != nil }
        if let existing = registry.entries[id]?.value { return existing }
        let ledger = ProjectionRevisionLedger(coordinator: container.persistentStoreCoordinator)
        registry.entries[id] = WeakEntry(ledger)
        return ledger
    }

    private init(coordinator: NSPersistentStoreCoordinator) {
        self.coordinator = coordinator
        self.containerID = ObjectIdentifier(coordinator)
        observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave,
            object: nil, queue: nil) { [weak self] notification in
                self?.record(notification)
            }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        for subscription in subscriptions.values { subscription.cancel() }
    }

    func subscribe(recordKinds: Set<ProjectionRecordKind>) -> ProjectionInvalidationSubscription {
        let id = UUID()
        let subscription = ProjectionInvalidationSubscription(recordKinds: recordKinds) { [weak self] in
            self?.removeSubscription(id)
        }
        lock.lock()
        subscriptions[id] = subscription
        let current = revisions
        lock.unlock()
        // Replay the current revision to close registration and foreground gaps.
        // A later concurrent save is merged by max revision, never replaced by it.
        subscription.enqueue(.init(containerID: containerID, domains: [.tracking, .wellness],
            affectedIDs: [], revisions: current, transactionAuthor: nil, recordKinds: recordKinds,
            requiresFullDomainRefresh: true))
        return subscription
    }

    private func removeSubscription(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        subscriptions.removeValue(forKey: id)
    }

    var subscriptionCount: Int {
        lock.lock(); defer { lock.unlock() }
        return subscriptions.count
    }

    func snapshot() -> SourceRevisionVector {
        lock.lock(); defer { lock.unlock() }
        return revisions
    }

    func latestInvalidation() -> DomainInvalidation? {
        lock.lock(); defer { lock.unlock() }
        return lastInvalidation
    }

    private func record(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              let coordinator = context.persistentStoreCoordinator,
              ObjectIdentifier(coordinator) == containerID else { return }
        var domains: Set<ProjectionDomain> = []
        var ids: Set<UUID> = []
        var recordKinds: Set<ProjectionRecordKind> = []
        for key in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] {
            for object in notification.userInfo?[key] as? Set<NSManagedObject> ?? [] {
                let entity = object.entity.name ?? ""
                let affected = Self.domains(for: entity)
                if entity == "HydrationLog" || entity == "HydrationTarget" { recordKinds.insert(.hydration) }
                if entity == "MoodEnergyCheckIn" { recordKinds.insert(.mood) }
                guard !affected.isEmpty else { continue }
                domains.formUnion(affected)
                if object.entity.attributesByName["id"] != nil,
                   let id = object.value(forKey: "id") as? UUID { ids.insert(id) }
            }
        }
        guard !domains.isEmpty else { return }
        lock.lock()
        revisions.advance(domains)
        let event = DomainInvalidation(containerID: containerID, domains: domains, affectedIDs: ids,
            revisions: revisions, transactionAuthor: context.transactionAuthor, recordKinds: recordKinds)
        lastInvalidation = event
        let listeners = Array(subscriptions.values)
        lock.unlock()
        for listener in listeners { listener.enqueue(event) }
    }

    private static func domains(for entity: String) -> Set<ProjectionDomain> {
        switch entity {
        case "TaskDefinition", "TaskDependency", "Project", "ProjectMilestone": return [.tasks, .planning]
        case "InternalTimeBlock", "WorkingHoursProfile", "PlanningMutationReceipt": return [.planning]
        case "FocusSession": return [.focus]
        case "HydrationLog", "HydrationTarget", "TrackerDefinition", "TrackerEntry", "Occurrence",
             "HabitGroup", "HabitResiliencePolicy": return [.tracking]
        case "MoodEnergyCheckIn", "SleepContextRecord": return [.wellness, .tracking]
        case "MedicationDefinition", "MedicationSchedule", "MedicationEvent": return [.wellness, .tracking]
        default:
            if entity.hasPrefix("Journal") { return [.journal] }
            if entity.hasPrefix("Fasting") { return [.fasting] }
            if entity.hasPrefix("Goal") { return [.goals, .tracking] }
            if entity.hasPrefix("Routine") { return [.routines, .tracking] }
            if entity.hasPrefix("Nutrition") || entity == "FoodItem" { return [.nutrition] }
            return []
        }
    }
}

/// Independent backoff per maintenance domain. A failed read must not postpone
/// recovery until the next day, and unrelated successful work must not reset it.
struct MaintenanceRetryState<Domain: Hashable> {
    private var attempts: [Domain: Int] = [:]
    private(set) var errors: [Domain: String] = [:]

    mutating func failed(_ domain: Domain, message: String, at now: Date) -> Date {
        let attempt = min((attempts[domain] ?? 0) + 1, 7)
        attempts[domain] = attempt
        errors[domain] = message
        return now.addingTimeInterval(min(300, 5 * pow(2, Double(attempt - 1))))
    }

    mutating func succeeded(_ domain: Domain) {
        attempts.removeValue(forKey: domain)
        errors.removeValue(forKey: domain)
    }
}

/// Application-scoped reconciliation. Screen reads never perform these writes.
@MainActor
final class FoundationDomainMaintenance {
    private let drain = PresentationRefreshDrain()
    private var deadlines: [Invalidation.Domain: Date] = [:]
    private var retries = MaintenanceRetryState<Invalidation.Domain>()
    private var nextDeadline: Date? { deadlines.values.min() }

    struct Invalidation: Sendable {
        enum Domain: Hashable, Sendable { case focus, medication, routine, profile }
        let containerID: ObjectIdentifier
        let domains: Set<Domain>
        let affectedIDs: Set<UUID>
    }

    private var activeScenes: Set<String> = []
    private var isReconciling = false
    private var pendingDomains: Set<Invalidation.Domain> = []
    private var revision: UInt64 = 0
    private var deadlineTask: Task<Void, Never>?
    private final class ObservationToken: @unchecked Sendable {
        let token: NSObjectProtocol
        init(_ token: NSObjectProtocol) { self.token = token }
        deinit { NotificationCenter.default.removeObserver(token) }
    }
    private var observer: ObservationToken?
    private let planning: CoreDataPlanningRepository
    private let track: CoreDataTrackFoundationRepository
    private let phaseII: any PhaseIIRepository
    private let focusCommands: FocusSessionCommands?
    private let containerID: ObjectIdentifier

    init(container: NSPersistentContainer, planning: CoreDataPlanningRepository,
         track: CoreDataTrackFoundationRepository, phaseII: any PhaseIIRepository,
         focusCommands: FocusSessionCommands?) {
        self.planning = planning; self.track = track; self.phaseII = phaseII
        self.focusCommands = focusCommands
        containerID = ObjectIdentifier(container.persistentStoreCoordinator)
        observer = ObservationToken(NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave,
            object: nil, queue: nil) { @Sendable [weak self] notification in
            guard let event = Self.invalidation(notification) else { return }
            Task { @MainActor [weak self] in self?.receive(event) }
        })
    }

    deinit {
        deadlineTask?.cancel()
    }

    func setScene(_ id: String, active: Bool) {
        if active {
            guard activeScenes.insert(id).inserted else { return }
            pendingDomains.formUnion([.focus, .medication, .routine, .profile])
            schedule(after: 0)
        } else {
            activeScenes.remove(id)
            if activeScenes.isEmpty, !isReconciling { deadlineTask?.cancel(); deadlineTask = nil }
        }
    }

    private func receive(_ event: Invalidation) {
        guard event.containerID == containerID else { return }
        revision &+= 1
        pendingDomains.formUnion(event.domains)
        PerformanceTrace.event("DomainInvalidationCommitted", value: Int(truncatingIfNeeded: revision))
        schedule(after: 0.1)
    }

    private func schedule(after delay: TimeInterval) {
        guard !activeScenes.isEmpty, !isReconciling else { return }
        deadlineTask?.cancel()
        deadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !activeScenes.isEmpty else { return }
            let due = deadlines.filter { $0.value <= Date() }.map(\.key)
            let domains = pendingDomains.union(due)
            pendingDomains.removeAll()
            isReconciling = true
            await reconcile(planning: planning, track: track, phaseII: phaseII,
                focusCommands: focusCommands, domains: domains)
            isReconciling = false
            guard !Task.isCancelled, !activeScenes.isEmpty else { return }
            if !pendingDomains.isEmpty { schedule(after: 0.1) }
            else if let nextDeadline {
                schedule(after: max(0.1, nextDeadline.timeIntervalSinceNow))
            }
        }
    }

    nonisolated static func invalidation(_ notification: Notification) -> Invalidation? {
        guard let context = notification.object as? NSManagedObjectContext,
              let coordinator = context.persistentStoreCoordinator else { return nil }
        var domains: Set<Invalidation.Domain> = []
        var ids: Set<UUID> = []
        for key in [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey] {
            for object in notification.userInfo?[key] as? Set<NSManagedObject> ?? [] {
                switch object.entity.name {
                case "FocusSession", "TaskDefinition": domains.insert(.focus)
                case "WorkingHoursProfile": domains.insert(.profile)
                case "MedicationDefinition", "MedicationSchedule", "MedicationEvent": domains.insert(.medication)
                case "RoutineRun", "RoutineDefinition": domains.insert(.routine)
                default: continue
                }
                if object.entity.attributesByName["id"] != nil,
                   let id = object.value(forKey: "id") as? UUID { ids.insert(id) }
            }
        }
        guard !domains.isEmpty else { return nil }
        return .init(containerID: ObjectIdentifier(coordinator), domains: domains, affectedIDs: ids)
    }

    func reconcile(planning: CoreDataPlanningRepository, track: CoreDataTrackFoundationRepository,
                   phaseII: any PhaseIIRepository, focusCommands: FocusSessionCommands?,
                   domains: Set<Invalidation.Domain>) async {
        await drain.run { [self] in
            let interval = PerformanceTrace.begin("FoundationDomainMaintenance")
            defer { PerformanceTrace.end(interval) }
            let now = Date()
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
            for domain in domains { deadlines[domain] = end }
            var changed = false
            if domains.contains(.profile) { do {
                let profiles = try await planning.fetchWorkingHoursProfiles()
                if profiles.isEmpty {
                    try await planning.saveWorkingHoursProfile(PlanStore.defaultWorkingProfile())
                    changed = true
                }
                retries.succeeded(.profile)
            } catch {
                deadlines[.profile] = retries.failed(.profile, message: error.localizedDescription, at: Date())
                logError(event: "profile_maintenance_failed", message: error.localizedDescription)
            } }
            if domains.contains(.focus) { do {
                var session = try await planning.activeSession()
                if let current = session, let repair = FocusStartupRepairPolicy.commandKind(for: current, now: now) {
                    if let focusCommands, repair == .pause { session = try await focusCommands.pause(sessionID: current.id).session }
                    else { session = try await planning.handle(.init(sessionID: current.id, kind: repair, occurredAt: now)) }
                    changed = true
                }
                await FocusLiveActivityCoordinator.shared.endOrphanedActivities(except: session?.id)
                if let session {
                    let title = try await planning.focusTaskTitle(taskID: session.taskID) ?? "Protected focus"
                    let available = await FocusLiveActivityCoordinator.shared.synchronize(session: session, title: title)
                    await FocusNotificationFallbackCoordinator.shared.synchronize(session: session, title: title, liveActivitiesAvailable: available)
                    if session.state == .running {
                        let deadline = now.addingTimeInterval(max(0.1, session.targetDuration - session.focusedDuration(at: now)))
                        deadlines[.focus] = min(deadlines[.focus] ?? end, deadline)
                    }
                } else { await FocusNotificationFallbackCoordinator.shared.cancelAll() }
                retries.succeeded(.focus)
            } catch {
                deadlines[.focus] = retries.failed(.focus, message: error.localizedDescription, at: Date())
                logError(event: "focus_maintenance_failed", message: error.localizedDescription)
            } }
            if domains.contains(.medication) { do {
                let events = try await phaseII.fetchMedicationEvents(from: start, to: end)
                let schedules = try await phaseII.fetchMedicationSchedules(medicationID: nil)
                let medications = try await phaseII.fetchMedications()
                for event in events where event.status == .scheduled {
                    if TrackFoundationStore.medicationWindowEnded(event, schedules: schedules, now: now) {
                        if let medication = medications.first(where: { $0.id == event.medicationID }) {
                            var unresolved = event
                            unresolved.status = .unresolved
                            unresolved.resolvedAt = nil
                            try await MedicationScheduleService(repository: phaseII).saveEvent(medication: medication, event: unresolved)
                            changed = true
                        }
                    } else {
                        let schedule = schedules.first { $0.medicationID == event.medicationID }
                        let seconds = schedule.map { max(0, $0.windowEndMinutes - $0.windowStartMinutes) * 60 } ?? 0
                        deadlines[.medication] = min(deadlines[.medication] ?? end, event.scheduledAt.addingTimeInterval(Double(seconds) + 0.1))
                    }
                }
                retries.succeeded(.medication)
            } catch {
                deadlines[.medication] = retries.failed(.medication, message: error.localizedDescription, at: Date())
                logError(event: "medication_maintenance_failed", message: error.localizedDescription)
            } }
            if domains.contains(.routine) { do {
                let runs = try await track.fetchRoutineRuns(routineID: nil)
                if let run = runs.first(where: { $0.status == .running || $0.status == .paused || $0.status == .interrupted }) {
                    await RoutineLiveActivityCoordinator.shared.synchronize(run: run)
                } else { await RoutineLiveActivityCoordinator.shared.endOrphanedActivities(except: nil) }
                retries.succeeded(.routine)
            } catch {
                deadlines[.routine] = retries.failed(.routine, message: error.localizedDescription, at: Date())
                logError(event: "routine_maintenance_failed", message: error.localizedDescription)
            } }
            if changed { NotificationCenter.default.post(name: .foundationDomainMaintenanceCommitted, object: nil) }
        }
    }
}

extension Notification.Name {
    static let foundationDomainMaintenanceCommitted = Notification.Name("LifeBoardDomainMaintenanceCommitted")
}

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

    /// Bumped each time Overdue Rescue launched from Plan closes.
    ///
    /// An environment value, not an initializer argument: `StableDestinationRoot`
    /// builds each root once and keeps that view, so an argument stays frozen at
    /// its first value and Plan never reloaded after a rescue. The environment
    /// still flows into the kept view, like `lifeBoardRootActivity` above.
    var planRescueRefreshGeneration: Int {
        get { self[PlanRescueRefreshGenerationKey.self] }
        set { self[PlanRescueRefreshGenerationKey.self] = newValue }
    }
}

private struct PlanRescueRefreshGenerationKey: EnvironmentKey {
    static let defaultValue = 0
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

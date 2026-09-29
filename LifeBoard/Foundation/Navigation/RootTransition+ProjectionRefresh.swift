import Foundation

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
                    .failed(String(localized: "Your change hasn’t loaded yet."))
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

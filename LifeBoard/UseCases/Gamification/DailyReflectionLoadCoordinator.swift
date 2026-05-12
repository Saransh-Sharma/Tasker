import Foundation
import SwiftData

public enum DailyReflectionUseCaseError: LocalizedError {
    case unavailableTarget
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailableTarget:
            return "No open reflection is available right now."
        case .persistenceFailed(let message):
            return message
        }
    }
}

public struct SaveDailyReflectionAndPlanResult: Sendable {
    public let target: DailyReflectionTarget
    public let reflectionPayload: ReflectionPayload?
    public let planDraft: DailyPlanDraft?
    public let xpResult: XPEventResult
    public let preservedExistingManualDraft: Bool

    public init(
        target: DailyReflectionTarget,
        reflectionPayload: ReflectionPayload?,
        planDraft: DailyPlanDraft?,
        xpResult: XPEventResult,
        preservedExistingManualDraft: Bool
    ) {
        self.target = target
        self.reflectionPayload = reflectionPayload
        self.planDraft = planDraft
        self.xpResult = xpResult
        self.preservedExistingManualDraft = preservedExistingManualDraft
    }
}

public final class ResolveDailyReflectionTargetUseCase: @unchecked Sendable {
    private let reflectionStore: DailyReflectionStoreProtocol
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date

    public init(
        reflectionStore: DailyReflectionStoreProtocol,
        calendar: Calendar = .autoupdatingCurrent,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.reflectionStore = reflectionStore
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    public func execute(preferredReflectionDate _: Date? = nil) -> DailyReflectionTarget? {
        let today = calendar.startOfDay(for: nowProvider())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }

        if reflectionStore.isCompleted(on: yesterday) == false {
            return DailyReflectionTarget(
                mode: .catchUpYesterday,
                reflectionDate: yesterday,
                planningDate: today
            )
        }

        if reflectionStore.isCompleted(on: today) == false {
            return DailyReflectionTarget(
                mode: .sameDay,
                reflectionDate: today,
                planningDate: tomorrow
            )
        }

        return nil
    }
}

struct ReflectionCalendarContextSnapshot: Equatable, Sendable {
    let eventCount: Int
    let busyBlocks: [LifeBoardCalendarBusyBlock]
    let bestFocusWindow: DateInterval?
    let firstHardStop: Date?
    let meetingMinutes: Int
}

private struct ReflectionCalendarBusyBlockPayload: Codable, Equatable {
    let startDate: Date
    let endDate: Date

    init(_ block: LifeBoardCalendarBusyBlock) {
        self.startDate = block.startDate
        self.endDate = block.endDate
    }

    var model: LifeBoardCalendarBusyBlock {
        LifeBoardCalendarBusyBlock(startDate: startDate, endDate: endDate)
    }
}

private struct ReflectionCalendarContextCachePayload: Codable, Equatable {
    let eventCount: Int
    let meetingMinutes: Int
    let firstHardStop: Date?
    let bestFocusWindow: DateInterval?
    let busyBlocks: [ReflectionCalendarBusyBlockPayload]

    init(snapshot: ReflectionCalendarContextSnapshot) {
        eventCount = snapshot.eventCount
        meetingMinutes = snapshot.meetingMinutes
        firstHardStop = snapshot.firstHardStop
        bestFocusWindow = snapshot.bestFocusWindow
        busyBlocks = snapshot.busyBlocks.map(ReflectionCalendarBusyBlockPayload.init)
    }

    var snapshot: ReflectionCalendarContextSnapshot {
        ReflectionCalendarContextSnapshot(
            eventCount: eventCount,
            busyBlocks: busyBlocks.map(\.model),
            bestFocusWindow: bestFocusWindow,
            firstHardStop: firstHardStop,
            meetingMinutes: meetingMinutes
        )
    }
}

struct ReflectionCalendarContextCacheKey: Equatable, Hashable, Sendable {
    let dayStart: Date
    let dayEnd: Date
    let timezoneID: String
    let selectedCalendarIDsHash: String

    var storageKey: String {
        let startStamp = Int(dayStart.timeIntervalSince1970)
        let endStamp = Int(dayEnd.timeIntervalSince1970)
        return "\(startStamp)|\(endStamp)|\(timezoneID)|\(selectedCalendarIDsHash)"
    }
}

struct ReflectionCalendarContextCacheLookup: Equatable, Sendable {
    let snapshot: ReflectionCalendarContextSnapshot
    let isStale: Bool
}

protocol ReflectionCalendarContextCacheStoreProtocol: Sendable {
    func load(
        key: ReflectionCalendarContextCacheKey,
        freshnessSeconds: TimeInterval,
        now: Date
    ) async -> ReflectionCalendarContextCacheLookup?
    func save(
        snapshot: ReflectionCalendarContextSnapshot,
        key: ReflectionCalendarContextCacheKey,
        cachedAt: Date
    ) async
}

@Model
final class ReflectionCalendarContextCacheRecord {
    var storageKey: String
    var dayStart: Date
    var dayEnd: Date
    var timezoneID: String
    var selectedCalendarIDsHash: String
    var cachedAt: Date
    var payloadData: Data

    init(
        storageKey: String,
        dayStart: Date,
        dayEnd: Date,
        timezoneID: String,
        selectedCalendarIDsHash: String,
        cachedAt: Date,
        payloadData: Data
    ) {
        self.storageKey = storageKey
        self.dayStart = dayStart
        self.dayEnd = dayEnd
        self.timezoneID = timezoneID
        self.selectedCalendarIDsHash = selectedCalendarIDsHash
        self.cachedAt = cachedAt
        self.payloadData = payloadData
    }
}

enum ReflectionCalendarContextCacheSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [ReflectionCalendarContextCacheRecord.self]
    }
}

enum ReflectionCalendarContextCacheMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ReflectionCalendarContextCacheSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum ReflectionCalendarContextCacheDataController {
    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(ReflectionCalendarContextCacheSchemaV1.models),
            migrationPlan: ReflectionCalendarContextCacheMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static let shared: ModelContainer? = {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        do {
            try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        } catch {
            logWarning(
                event: "reflection_cache_directory_create_failed",
                message: "Failed to create reflection cache directory; using in-memory fallback",
                fields: ["error": error.localizedDescription]
            )
            return nil
        }
        let storeURL = appSupportURL.appendingPathComponent("reflection-calendar-context.store")
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        do {
            return try makeModelContainer(configuration: configuration)
        } catch {
            logWarning(
                event: "reflection_cache_swiftdata_degraded",
                message: "Reflection calendar context cache fell back to in-memory storage",
                fields: ["error": error.localizedDescription]
            )
            return nil
        }
    }()
}

actor ReflectionCalendarContextCacheStore: ReflectionCalendarContextCacheStoreProtocol {
    static let shared = ReflectionCalendarContextCacheStore()

    private let container: ModelContainer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var inMemoryFallback: [String: (snapshot: ReflectionCalendarContextSnapshot, cachedAt: Date)] = [:]

    init(container: ModelContainer? = ReflectionCalendarContextCacheDataController.shared) {
        self.container = container
    }

    func load(
        key: ReflectionCalendarContextCacheKey,
        freshnessSeconds: TimeInterval,
        now: Date
    ) async -> ReflectionCalendarContextCacheLookup? {
        if let container {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<ReflectionCalendarContextCacheRecord>()
            if let records = try? context.fetch(descriptor),
               let record = records.first(where: { $0.storageKey == key.storageKey }),
               let payload = try? decoder.decode(ReflectionCalendarContextCachePayload.self, from: record.payloadData) {
                let age = max(0, now.timeIntervalSince(record.cachedAt))
                return ReflectionCalendarContextCacheLookup(
                    snapshot: payload.snapshot,
                    isStale: age > freshnessSeconds
                )
            }
        }

        guard let fallback = inMemoryFallback[key.storageKey] else {
            return nil
        }
        let age = max(0, now.timeIntervalSince(fallback.cachedAt))
        return ReflectionCalendarContextCacheLookup(
            snapshot: fallback.snapshot,
            isStale: age > freshnessSeconds
        )
    }

    func save(
        snapshot: ReflectionCalendarContextSnapshot,
        key: ReflectionCalendarContextCacheKey,
        cachedAt: Date
    ) async {
        let payload = ReflectionCalendarContextCachePayload(snapshot: snapshot)
        guard let data = try? encoder.encode(payload) else { return }

        if let container {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<ReflectionCalendarContextCacheRecord>()
            var records = (try? context.fetch(descriptor)) ?? []
            if let existing = records.first(where: { $0.storageKey == key.storageKey }) {
                existing.cachedAt = cachedAt
                existing.payloadData = data
                existing.dayStart = key.dayStart
                existing.dayEnd = key.dayEnd
                existing.timezoneID = key.timezoneID
                existing.selectedCalendarIDsHash = key.selectedCalendarIDsHash
                for duplicate in records where duplicate.storageKey == key.storageKey && duplicate !== existing {
                    context.delete(duplicate)
                }
            } else {
                context.insert(
                    ReflectionCalendarContextCacheRecord(
                        storageKey: key.storageKey,
                        dayStart: key.dayStart,
                        dayEnd: key.dayEnd,
                        timezoneID: key.timezoneID,
                        selectedCalendarIDsHash: key.selectedCalendarIDsHash,
                        cachedAt: cachedAt,
                        payloadData: data
                    )
                )
            }

            let pruneBefore = cachedAt.addingTimeInterval(-(7 * 24 * 60 * 60))
            records = (try? context.fetch(descriptor)) ?? records
            for record in records where record.cachedAt < pruneBefore {
                context.delete(record)
            }

            do {
                try context.save()
            } catch {
                logWarning(
                    event: "reflection_cache_save_failed",
                    message: "Failed to persist reflection calendar context cache; retaining in-memory fallback",
                    fields: ["error": error.localizedDescription]
                )
            }
        }

        inMemoryFallback[key.storageKey] = (snapshot: snapshot, cachedAt: cachedAt)
    }

    func clearAll() async {
        inMemoryFallback.removeAll()
        guard let container else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ReflectionCalendarContextCacheRecord>()
        let records: [ReflectionCalendarContextCacheRecord]
        do {
            records = try context.fetch(descriptor)
        } catch {
            logWarning(
                event: "reflection_cache_clear_fetch_failed",
                message: "Failed to fetch reflection calendar context cache records for clearing",
                fields: ["error": error.localizedDescription]
            )
            return
        }
        for record in records {
            context.delete(record)
        }
        do {
            try context.save()
        } catch {
            logWarning(
                event: "reflection_cache_clear_failed",
                message: "Failed to clear reflection calendar context cache",
                fields: ["error": error.localizedDescription]
            )
        }
    }
}

public final class BuildNextDayPlanSuggestionUseCase: @unchecked Sendable {
    private final class CalendarContextLoadGate: @unchecked Sendable {
        private let lock = NSLock()
        private var didFinish = false

        func finishOnce(_ operation: () -> Void) {
            lock.lock()
            guard didFinish == false else {
                lock.unlock()
                return
            }
            didFinish = true
            lock.unlock()
            operation()
        }

        func shouldContinue() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return didFinish == false
        }
    }

    public struct CalendarContext: Equatable, Sendable {
        public let eventCount: Int
        public let busyBlocks: [LifeBoardCalendarBusyBlock]
        public let bestFocusWindow: DateInterval?
        public let firstHardStop: Date?
        public let meetingMinutes: Int

        public init(
            eventCount: Int,
            busyBlocks: [LifeBoardCalendarBusyBlock],
            bestFocusWindow: DateInterval?,
            firstHardStop: Date?,
            meetingMinutes: Int
        ) {
            self.eventCount = eventCount
            self.busyBlocks = busyBlocks
            self.bestFocusWindow = bestFocusWindow
            self.firstHardStop = firstHardStop
            self.meetingMinutes = meetingMinutes
        }
    }

    public struct CalendarContextLoadResult: Equatable, Sendable {
        public let context: CalendarContext?
        public let status: DailyReflectionOptionalLoadStatus

        public init(context: CalendarContext?, status: DailyReflectionOptionalLoadStatus) {
            self.context = context
            self.status = status
        }
    }

    public enum CachedCalendarContextLookup: Equatable, Sendable {
        case fresh(CalendarContext)
        case stale(CalendarContext)
        case miss
    }

    private let calendarEventsProvider: CalendarEventsProviderProtocol?
    private let calendar: Calendar
    private let contextBuildQueue: DispatchQueue
    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore
    private let calendarContextCacheStore: ReflectionCalendarContextCacheStoreProtocol
    private let nowProvider: @Sendable () -> Date
    private let mergeGapThreshold: TimeInterval

    public init(
        calendarEventsProvider: CalendarEventsProviderProtocol?,
        buildCalendarBusyBlocks: BuildCalendarBusyBlocksUseCase = BuildCalendarBusyBlocksUseCase(),
        calendar: Calendar = .autoupdatingCurrent,
        contextBuildQueue: DispatchQueue = DispatchQueue(
            label: "com.lifeboard.reflection.calendar-context-build",
            qos: .userInitiated
        )
    ) {
        _ = buildCalendarBusyBlocks
        self.calendarEventsProvider = calendarEventsProvider
        self.calendar = calendar
        self.contextBuildQueue = contextBuildQueue
        self.workspacePreferencesStore = .shared
        self.calendarContextCacheStore = ReflectionCalendarContextCacheStore.shared
        self.nowProvider = { Date() }
        self.mergeGapThreshold = 5 * 60
    }

    init(
        calendarEventsProvider: CalendarEventsProviderProtocol?,
        calendar: Calendar = .autoupdatingCurrent,
        contextBuildQueue: DispatchQueue = DispatchQueue(
            label: "com.lifeboard.reflection.calendar-context-build",
            qos: .userInitiated
        ),
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared,
        calendarContextCacheStore: ReflectionCalendarContextCacheStoreProtocol = ReflectionCalendarContextCacheStore.shared,
        mergeGapThreshold: TimeInterval = 5 * 60,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.calendarEventsProvider = calendarEventsProvider
        self.calendar = calendar
        self.contextBuildQueue = contextBuildQueue
        self.workspacePreferencesStore = workspacePreferencesStore
        self.calendarContextCacheStore = calendarContextCacheStore
        self.nowProvider = nowProvider
        self.mergeGapThreshold = max(0, mergeGapThreshold)
    }

    public func execute(
        planningDate: Date,
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition],
        atRiskHabit: HabitOccurrenceSummary?,
        completion: @escaping @Sendable (Result<DailyPlanSuggestion, Error>) -> Void
    ) {
        Task {
            if Task.isCancelled {
                completion(.failure(CancellationError()))
                return
            }
            let loadResult = await loadCalendarContext(for: planningDate)
            let suggestion = buildSuggestion(
                planningDate: planningDate,
                carryoverTasks: carryoverTasks,
                planningDateTasks: planningDateTasks,
                atRiskHabit: atRiskHabit,
                calendarContext: loadResult.context
            )
            completion(.success(suggestion))
        }
    }

    public func buildCalendarSummary(
        for planningDate: Date,
        completion: @escaping @Sendable (Result<CalendarReflectionSummary?, Error>) -> Void
    ) {
        Task {
            if Task.isCancelled {
                completion(.failure(CancellationError()))
                return
            }
            let loadResult = await loadCalendarContext(for: planningDate)
            completion(.success(makeCalendarSummary(from: loadResult.context)))
        }
    }

    public func loadCalendarContext(
        for planningDate: Date,
        timeoutSeconds: TimeInterval = 2.0
    ) async -> CalendarContextLoadResult {
        guard let calendarEventsProvider,
              calendarEventsProvider.authorizationStatus().isAuthorizedForRead else {
            return CalendarContextLoadResult(
                context: nil,
                status: .degraded("Calendar context unavailable. Suggestions use tasks and habits only.")
            )
        }

        let query = calendarContextQuery(for: planningDate)
        guard query.selectedCalendarIDs.isEmpty == false else {
            return CalendarContextLoadResult(
                context: nil,
                status: .degraded("Calendar context unavailable. Suggestions use tasks and habits only.")
            )
        }
        let interval = LifeBoardPerformanceTrace.begin("ReflectionOptionalLoad")
        return await withCheckedContinuation { continuation in
            let gate = CalendarContextLoadGate()

            @Sendable func finish(_ result: CalendarContextLoadResult) {
                gate.finishOnce {
                    LifeBoardPerformanceTrace.end(interval)
                    continuation.resume(returning: result)
                }
            }

            @Sendable func shouldContinue() -> Bool {
                gate.shouldContinue()
            }

            let timeoutNanoseconds = UInt64(max(0.25, timeoutSeconds) * 1_000_000_000)
            let timeoutTask = _Concurrency.Task {
                do {
                    try await _Concurrency.Task.sleep(nanoseconds: timeoutNanoseconds)
                } catch {
                    return
                }
                guard _Concurrency.Task.isCancelled == false else { return }
                LifeBoardPerformanceTrace.event("ReflectionEnrichmentTimedOut")
                finish(
                    CalendarContextLoadResult(
                        context: nil,
                        status: .degraded("Calendar context timed out. Suggestions use tasks and habits only.")
                    )
                )
            }

            let fetchInterval = LifeBoardPerformanceTrace.begin("ReflectionCalendarFetch")
            calendarEventsProvider.fetchEventSlices(
                startDate: query.dayStart,
                endDate: query.dayEnd,
                calendarIDs: query.selectedCalendarIDs
            ) { result in
                defer { LifeBoardPerformanceTrace.end(fetchInterval) }
                timeoutTask.cancel()
                switch result {
                case .failure:
                    finish(
                        CalendarContextLoadResult(
                            context: nil,
                            status: .degraded("Calendar context unavailable. Suggestions use tasks and habits only.")
                        )
                    )
                case .success(let eventSlices):
                    let contextBuildQueue = self.contextBuildQueue
                    let mergeGapThreshold = self.mergeGapThreshold
                    let calendarContextCacheStore = self.calendarContextCacheStore
                    let nowProvider = self.nowProvider
                    contextBuildQueue.async {
                        guard shouldContinue() else { return }
                        LifeBoardPerformanceTrace.event("ReflectionContextBuildStart")
                        let buildInterval = LifeBoardPerformanceTrace.begin("ReflectionCalendarContextBuild")
                        let context = Self.buildCalendarContext(
                            eventSlices: eventSlices,
                            dayStart: query.dayStart,
                            dayEnd: query.dayEnd,
                            mergeGapThreshold: mergeGapThreshold
                        )
                        LifeBoardPerformanceTrace.end(buildInterval)
                        LifeBoardPerformanceTrace.event("ReflectionContextBuildFinish")
                        let snapshot = Self.snapshot(from: context)
                        Task {
                            await calendarContextCacheStore.save(
                                snapshot: snapshot,
                                key: query.cacheKey,
                                cachedAt: nowProvider()
                            )
                        }
                        finish(CalendarContextLoadResult(context: context, status: .loaded))
                    }
                }
            }
        }
    }

    public func loadCachedOrStaleCalendarContext(
        for planningDate: Date,
        freshnessSeconds: TimeInterval = 30 * 60
    ) async -> CachedCalendarContextLookup {
        guard let calendarEventsProvider,
              calendarEventsProvider.authorizationStatus().isAuthorizedForRead else {
            return .miss
        }

        let query = calendarContextQuery(for: planningDate)
        guard query.selectedCalendarIDs.isEmpty == false else {
            return .miss
        }
        guard let lookup = await calendarContextCacheStore.load(
            key: query.cacheKey,
            freshnessSeconds: max(60, freshnessSeconds),
            now: nowProvider()
        ) else {
            return .miss
        }

        let context = Self.context(from: lookup.snapshot)
        if lookup.isStale {
            LifeBoardPerformanceTrace.event("ReflectionContextCacheStaleHit")
            return .stale(context)
        }
        LifeBoardPerformanceTrace.event("ReflectionContextCacheHit")
        return .fresh(context)
    }

    public func prefetchCalendarContext(
        for planningDate: Date,
        timeoutSeconds: TimeInterval = 0.8
    ) async {
        _ = await loadCalendarContext(for: planningDate, timeoutSeconds: timeoutSeconds)
    }

    public func buildSuggestion(
        planningDate _: Date,
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition],
        atRiskHabit: HabitOccurrenceSummary?,
        calendarContext: CalendarContext?
    ) -> DailyPlanSuggestion {
        let planInterval = LifeBoardPerformanceTrace.begin("ReflectionPlanBuild")
        defer { LifeBoardPerformanceTrace.end(planInterval) }

        let ranked = rankCandidates(
            carryoverTasks: carryoverTasks,
            planningDateTasks: planningDateTasks
        )
        let selected = selectTopTasks(from: ranked)
        let selectedIDs = Set(selected.map(\.id))
        let swapPool = ranked.filter { !selectedIDs.contains($0.id) }
        let swapPools = Dictionary(
            uniqueKeysWithValues: selected.indices.map { index in
                (EditableDailyPlan.swapPoolKey(for: index), swapPool)
            }
        )

        let risk = resolvePrimaryRisk(
            carryoverTasks: carryoverTasks,
            planningDateTasks: planningDateTasks,
            calendarContext: calendarContext,
            atRiskHabit: atRiskHabit
        )

        return DailyPlanSuggestion(
            topTasks: selected,
            swapPoolsBySlot: swapPools,
            focusWindow: calendarContext?.bestFocusWindow,
            protectedHabitID: atRiskHabit?.habitID,
            protectedHabitTitle: atRiskHabit?.title,
            protectedHabitStreak: atRiskHabit?.currentStreak,
            primaryRisk: risk.0,
            primaryRiskDetail: risk.1
        )
    }

    public func makeCalendarSummary(from context: CalendarContext?) -> CalendarReflectionSummary? {
        guard let context,
              context.eventCount > 0 || context.bestFocusWindow != nil else {
            return nil
        }
        return CalendarReflectionSummary(
            eventCount: context.eventCount,
            meetingMinutes: context.meetingMinutes,
            bestFocusWindow: context.bestFocusWindow,
            firstHardStop: context.firstHardStop
        )
    }

    private static func buildCalendarContext(
        eventSlices: [LifeBoardCalendarEventSlice],
        dayStart: Date,
        dayEnd: Date,
        mergeGapThreshold: TimeInterval
    ) -> CalendarContext {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif

        let clampedAndSorted = eventSlices
            .compactMap { slice -> LifeBoardCalendarEventSlice? in
                let clampedStart = max(dayStart, slice.startDate)
                let clampedEnd = min(dayEnd, slice.endDate)
                guard clampedEnd > clampedStart else { return nil }
                return LifeBoardCalendarEventSlice(
                    startDate: clampedStart,
                    endDate: clampedEnd,
                    isAllDay: slice.isAllDay,
                    isBusy: slice.isBusy
                )
            }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }

        var busyBlocks: [LifeBoardCalendarBusyBlock] = []
        var currentBusy: LifeBoardCalendarBusyBlock?
        var firstHardStop: Date?
        var meetingMinutes = 0

        for slice in clampedAndSorted where slice.isBusy && !slice.isAllDay {
            if firstHardStop == nil {
                firstHardStop = slice.startDate
            }
            meetingMinutes += max(0, Int(slice.endDate.timeIntervalSince(slice.startDate) / 60.0))

            let block = LifeBoardCalendarBusyBlock(startDate: slice.startDate, endDate: slice.endDate)
            if let existing = currentBusy {
                if block.startDate <= existing.endDate.addingTimeInterval(mergeGapThreshold) {
                    currentBusy = LifeBoardCalendarBusyBlock(
                        startDate: existing.startDate,
                        endDate: max(existing.endDate, block.endDate)
                    )
                } else {
                    busyBlocks.append(existing)
                    currentBusy = block
                }
            } else {
                currentBusy = block
            }
        }
        if let currentBusy {
            busyBlocks.append(currentBusy)
        }

        let bestFocusWindow = Self.resolveBestFocusWindow(
            start: dayStart,
            end: dayEnd,
            busyBlocks: busyBlocks,
            firstHardStop: firstHardStop
        )

        return CalendarContext(
            eventCount: clampedAndSorted.count,
            busyBlocks: busyBlocks,
            bestFocusWindow: bestFocusWindow,
            firstHardStop: firstHardStop,
            meetingMinutes: meetingMinutes
        )
    }

    private static func resolveBestFocusWindow(
        start: Date,
        end: Date,
        busyBlocks: [LifeBoardCalendarBusyBlock],
        firstHardStop: Date?
    ) -> DateInterval? {
        let windows = Self.freeWindows(start: start, end: end, busyBlocks: busyBlocks)
        guard windows.isEmpty == false else { return nil }

        let minimumUsefulDuration: TimeInterval = 45 * 60
        if let firstHardStop {
            let preHardStop = windows
                .compactMap { interval -> DateInterval? in
                    guard interval.start < firstHardStop else { return nil }
                    let clampedEnd = min(interval.end, firstHardStop)
                    guard clampedEnd > interval.start else { return nil }
                    let candidate = DateInterval(start: interval.start, end: clampedEnd)
                    return candidate.duration >= minimumUsefulDuration ? candidate : nil
                }
                .sorted { $0.duration > $1.duration }
                .first
            if let preHardStop {
                return preHardStop
            }
        }

        return windows
            .filter { $0.duration >= minimumUsefulDuration }
            .sorted { $0.duration > $1.duration }
            .first ?? windows.sorted { $0.duration > $1.duration }.first
    }

    private static func freeWindows(
        start: Date,
        end: Date,
        busyBlocks: [LifeBoardCalendarBusyBlock]
    ) -> [DateInterval] {
        var cursor = start
        var intervals: [DateInterval] = []

        for block in busyBlocks {
            let clampedStart = max(start, block.startDate)
            let clampedEnd = min(end, block.endDate)
            if clampedStart > cursor {
                intervals.append(DateInterval(start: cursor, end: clampedStart))
            }
            cursor = max(cursor, clampedEnd)
        }

        if cursor < end {
            intervals.append(DateInterval(start: cursor, end: end))
        }

        return intervals.filter { $0.duration > 0 }
    }

    private struct CalendarContextQuery {
        let dayStart: Date
        let dayEnd: Date
        let selectedCalendarIDs: Set<String>
        let cacheKey: ReflectionCalendarContextCacheKey
    }

    private func calendarContextQuery(for planningDate: Date) -> CalendarContextQuery {
        let dayStart = calendar.startOfDay(for: planningDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let normalizedIDs = LifeBoardWorkspacePreferences.normalizeSelectedCalendarIDs(
            workspacePreferencesStore.load().selectedCalendarIDs
        )
        let selectionHash = normalizedIDs.joined(separator: "|")
        return CalendarContextQuery(
            dayStart: dayStart,
            dayEnd: dayEnd,
            selectedCalendarIDs: Set(normalizedIDs),
            cacheKey: ReflectionCalendarContextCacheKey(
                dayStart: dayStart,
                dayEnd: dayEnd,
                timezoneID: calendar.timeZone.identifier,
                selectedCalendarIDsHash: selectionHash
            )
        )
    }

    private static func snapshot(from context: CalendarContext) -> ReflectionCalendarContextSnapshot {
        ReflectionCalendarContextSnapshot(
            eventCount: context.eventCount,
            busyBlocks: context.busyBlocks,
            bestFocusWindow: context.bestFocusWindow,
            firstHardStop: context.firstHardStop,
            meetingMinutes: context.meetingMinutes
        )
    }

    private static func context(from snapshot: ReflectionCalendarContextSnapshot) -> CalendarContext {
        CalendarContext(
            eventCount: snapshot.eventCount,
            busyBlocks: snapshot.busyBlocks,
            bestFocusWindow: snapshot.bestFocusWindow,
            firstHardStop: snapshot.firstHardStop,
            meetingMinutes: snapshot.meetingMinutes
        )
    }

    private func rankCandidates(
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition]
    ) -> [DailyPlanTaskOption] {
        let carryovers = carryoverTasks
            .filter { !$0.isComplete }
            .sorted(by: taskSort)
            .map { makeOption(from: $0, isCarryover: true) }

        let dueAndPriority = planningDateTasks
            .filter { !$0.isComplete }
            .sorted(by: taskSort)
            .map { task -> DailyPlanTaskOption in
                makeOption(
                    from: task,
                    isCarryover: false,
                    isQuickStabilizer: isQuickStabilizer(task)
                )
            }

        var seen = Set<UUID>()
        return (carryovers + dueAndPriority).filter { option in
            seen.insert(option.id).inserted
        }
    }

    private func selectTopTasks(from ranked: [DailyPlanTaskOption]) -> [DailyPlanTaskOption] {
        var selected: [DailyPlanTaskOption] = []
        var deepCount = 0
        var quickStabilizerCount = 0

        for option in ranked {
            let isDeep = isDeepWork(option)
            if option.isQuickStabilizer && quickStabilizerCount >= 1 {
                continue
            }
            if isDeep && deepCount >= 2 && selected.count >= 2 {
                continue
            }

            selected.append(option)
            if option.isQuickStabilizer {
                quickStabilizerCount += 1
            }
            if isDeep {
                deepCount += 1
            }

            if selected.count == 3 {
                break
            }
        }

        return selected
    }

    private func resolvePrimaryRisk(
        carryoverTasks: [TaskDefinition],
        planningDateTasks: [TaskDefinition],
        calendarContext: CalendarContext?,
        atRiskHabit: HabitOccurrenceSummary?
    ) -> (DailyPlanRisk?, String?) {
        if carryoverTasks.isEmpty == false {
            return (.carryoverPressure, "Clear yesterday's carryover first so today doesn't stack.")
        }
        if planningDateTasks.contains(where: { $0.isOverdue }) {
            return (.overdueBacklogPressure, "An overdue task can steal the day early.")
        }
        if let calendarContext, calendarContext.meetingMinutes >= 180 {
            return (.meetingCongestion, "Calendar load is high, so protect a real focus window early.")
        }
        if let atRiskHabit {
            return (
                .habitContinuityRisk,
                "Protect \(atRiskHabit.title) before the streak slips further."
            )
        }
        return (nil, nil)
    }

    private func isQuickStabilizer(_ task: TaskDefinition) -> Bool {
        let shortDuration = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 30 * 60
        return task.energy == .low || shortDuration || task.priority == .none
    }

    private func isDeepWork(_ option: DailyPlanTaskOption) -> Bool {
        option.priority == .max || option.priority == .high
    }

    private func makeOption(
        from task: TaskDefinition,
        isCarryover: Bool,
        isQuickStabilizer: Bool = false
    ) -> DailyPlanTaskOption {
        DailyPlanTaskOption(
            id: task.id,
            title: task.title,
            projectName: task.projectName,
            dueDate: task.dueDate,
            priority: task.priority,
            isCarryover: isCarryover,
            isQuickStabilizer: isQuickStabilizer
        )
    }

    private func taskSort(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

public struct DailyReflectionCoreLoadBundle: Sendable {
    public let target: DailyReflectionTarget
    public let coreSnapshot: DailyReflectionCoreSnapshot
    public let carryoverTasks: [TaskDefinition]
    public let planningTasks: [TaskDefinition]
    public let atRiskHabit: HabitOccurrenceSummary?

    public init(
        target: DailyReflectionTarget,
        coreSnapshot: DailyReflectionCoreSnapshot,
        carryoverTasks: [TaskDefinition],
        planningTasks: [TaskDefinition],
        atRiskHabit: HabitOccurrenceSummary?
    ) {
        self.target = target
        self.coreSnapshot = coreSnapshot
        self.carryoverTasks = carryoverTasks
        self.planningTasks = planningTasks
        self.atRiskHabit = atRiskHabit
    }
}

public struct DailyReflectionCachedOptionalContext: Equatable, Sendable {
    public let optionalContext: DailyReflectionOptionalContext
    public let isStale: Bool

    public init(optionalContext: DailyReflectionOptionalContext, isStale: Bool) {
        self.optionalContext = optionalContext
        self.isStale = isStale
    }
}

public protocol DailyReflectionLoadCoordinatorProtocol: Sendable {
    func resolveTarget(preferredReflectionDate: Date?) async -> DailyReflectionTarget?
    func loadCore(target: DailyReflectionTarget) async throws -> DailyReflectionCoreLoadBundle
    func makeBaselineOptionalContext(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle
    ) async -> DailyReflectionOptionalContext
    func loadCachedOrStaleContext(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle
    ) async -> DailyReflectionCachedOptionalContext?
    func refreshContextInBackground(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle,
        timeoutSeconds: TimeInterval
    ) async -> DailyReflectionOptionalContext
    func prefetchContext(
        for target: DailyReflectionTarget,
        timeoutSeconds: TimeInterval
    ) async
    func loadOptionalContext(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle,
        timeoutSeconds: TimeInterval
    ) async -> DailyReflectionOptionalContext
}

public actor DailyReflectionLoadCoordinator: DailyReflectionLoadCoordinatorProtocol {
    private let resolveTargetUseCase: ResolveDailyReflectionTargetUseCase
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol
    private let habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol
    private let buildNextDayPlanSuggestionUseCase: BuildNextDayPlanSuggestionUseCase
    private let calendar: Calendar

    public init(
        resolveTargetUseCase: ResolveDailyReflectionTargetUseCase,
        taskReadModelRepository: TaskReadModelRepositoryProtocol,
        habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol,
        buildNextDayPlanSuggestionUseCase: BuildNextDayPlanSuggestionUseCase,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.resolveTargetUseCase = resolveTargetUseCase
        self.taskReadModelRepository = taskReadModelRepository
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
        self.buildNextDayPlanSuggestionUseCase = buildNextDayPlanSuggestionUseCase
        self.calendar = calendar
    }

    public func resolveTarget(preferredReflectionDate: Date?) async -> DailyReflectionTarget? {
        let interval = LifeBoardPerformanceTrace.begin("ReflectionResolveTarget")
        defer { LifeBoardPerformanceTrace.end(interval) }
        return resolveTargetUseCase.execute(preferredReflectionDate: preferredReflectionDate)
    }

    public func loadCore(target: DailyReflectionTarget) async throws -> DailyReflectionCoreLoadBundle {
        let interval = LifeBoardPerformanceTrace.begin("ReflectionCoreLoad")
        defer { LifeBoardPerformanceTrace.end(interval) }

        async let projectionTask = fetchTaskProjection(target: target)
        async let habitsTask = fetchHabits(for: target.reflectionDate)

        let projection = try await projectionTask
        let habits = try await habitsTask
        try Task.checkCancellation()

        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif

        let taskSummary = makeTaskSummary(from: projection, on: target.reflectionDate)
        let habitSummary = makeHabitSummary(from: habits)
        let closedTasks = makeClosedTasks(from: projection.reflectionCompletedTasks)
        let habitGrid = makeHabitGrid(from: habits)
        let narrativeSummary = ReflectionNarrativeSummary.make(
            completedCount: taskSummary.completedCount,
            keptCount: habitSummary?.keptCount ?? 0,
            missedTitles: missedHabitTitles(from: habits)
        )
        let atRiskHabit = habits
            .sorted { lhs, rhs in
                if lhs.riskState != rhs.riskState {
                    return lhs.riskState.rawValue > rhs.riskState.rawValue
                }
                return lhs.currentStreak > rhs.currentStreak
            }
            .first(where: { $0.riskState != .stable })

        let carryoverTasks = projection.reflectionOpenTasks.filter { task in
            guard let dueDate = task.dueDate else { return true }
            return calendar.startOfDay(for: dueDate) <= calendar.startOfDay(for: target.reflectionDate)
        }
        let planningTasks = projection.planningOpenTasks

        let coreSnapshot = DailyReflectionCoreSnapshot(
            reflectionDate: target.reflectionDate,
            planningDate: target.planningDate,
            mode: target.mode,
            pulseNote: makePulseNote(
                taskSummary: taskSummary,
                habitSummary: habitSummary,
                calendarSummary: nil
            ),
            biggestWins: makeBiggestWins(
                completedTasks: projection.reflectionCompletedTasks,
                habits: habits,
                taskSummary: taskSummary
            ),
            closedTasks: closedTasks,
            habitGrid: habitGrid,
            narrativeSummary: narrativeSummary,
            tasksSummary: taskSummary,
            habitsSummary: habitSummary
        )

        return DailyReflectionCoreLoadBundle(
            target: target,
            coreSnapshot: coreSnapshot,
            carryoverTasks: carryoverTasks,
            planningTasks: planningTasks,
            atRiskHabit: atRiskHabit
        )
    }

    public func makeBaselineOptionalContext(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle
    ) async -> DailyReflectionOptionalContext {
        let suggestion = buildNextDayPlanSuggestionUseCase.buildSuggestion(
            planningDate: target.planningDate,
            carryoverTasks: coreBundle.carryoverTasks,
            planningDateTasks: coreBundle.planningTasks,
            atRiskHabit: coreBundle.atRiskHabit,
            calendarContext: nil
        )
        return DailyReflectionOptionalContext(
            calendarSummary: nil,
            suggestedPlan: suggestion,
            status: .loading
        )
    }

    public func loadCachedOrStaleContext(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle
    ) async -> DailyReflectionCachedOptionalContext? {
        let lookup = await buildNextDayPlanSuggestionUseCase.loadCachedOrStaleCalendarContext(
            for: target.planningDate
        )

        let resolvedContext: BuildNextDayPlanSuggestionUseCase.CalendarContext?
        let isStale: Bool
        switch lookup {
        case .fresh(let context):
            resolvedContext = context
            isStale = false
        case .stale(let context):
            resolvedContext = context
            isStale = true
        case .miss:
            resolvedContext = nil
            isStale = false
        }
        guard let resolvedContext else { return nil }

        let suggestion = buildNextDayPlanSuggestionUseCase.buildSuggestion(
            planningDate: target.planningDate,
            carryoverTasks: coreBundle.carryoverTasks,
            planningDateTasks: coreBundle.planningTasks,
            atRiskHabit: coreBundle.atRiskHabit,
            calendarContext: resolvedContext
        )
        let optionalContext = DailyReflectionOptionalContext(
            calendarSummary: buildNextDayPlanSuggestionUseCase.makeCalendarSummary(from: resolvedContext),
            suggestedPlan: suggestion,
            status: .loaded
        )
        return DailyReflectionCachedOptionalContext(
            optionalContext: optionalContext,
            isStale: isStale
        )
    }

    public func refreshContextInBackground(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle,
        timeoutSeconds: TimeInterval
    ) async -> DailyReflectionOptionalContext {
        let loadResult = await buildNextDayPlanSuggestionUseCase.loadCalendarContext(
            for: target.planningDate,
            timeoutSeconds: timeoutSeconds
        )
        let suggestion = buildNextDayPlanSuggestionUseCase.buildSuggestion(
            planningDate: target.planningDate,
            carryoverTasks: coreBundle.carryoverTasks,
            planningDateTasks: coreBundle.planningTasks,
            atRiskHabit: coreBundle.atRiskHabit,
            calendarContext: loadResult.context
        )
        return DailyReflectionOptionalContext(
            calendarSummary: buildNextDayPlanSuggestionUseCase.makeCalendarSummary(from: loadResult.context),
            suggestedPlan: suggestion,
            status: loadResult.status
        )
    }

    public func prefetchContext(
        for target: DailyReflectionTarget,
        timeoutSeconds: TimeInterval
    ) async {
        await buildNextDayPlanSuggestionUseCase.prefetchCalendarContext(
            for: target.planningDate,
            timeoutSeconds: timeoutSeconds
        )
    }

    public func loadOptionalContext(
        target: DailyReflectionTarget,
        coreBundle: DailyReflectionCoreLoadBundle,
        timeoutSeconds: TimeInterval
    ) async -> DailyReflectionOptionalContext {
        await refreshContextInBackground(
            target: target,
            coreBundle: coreBundle,
            timeoutSeconds: timeoutSeconds
        )
    }

    private func fetchTaskProjection(target: DailyReflectionTarget) async throws -> DailyReflectionTaskProjection {
        try await withCheckedThrowingContinuation { continuation in
            taskReadModelRepository.fetchDailyReflectionProjection(
                query: DailyReflectionTaskProjectionQuery(
                    reflectionDate: target.reflectionDate,
                    planningDate: target.planningDate
                )
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func fetchHabits(for reflectionDate: Date) async throws -> [HabitOccurrenceSummary] {
        try await withCheckedThrowingContinuation { continuation in
            habitRuntimeReadRepository.fetchAgendaHabits(for: reflectionDate) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func makeTaskSummary(from projection: DailyReflectionTaskProjection, on date: Date) -> TaskReflectionSummary {
        let scheduledCount = projection.reflectionCompletedTasks.count + projection.reflectionOpenTasks.count
        let carryOverCount = projection.reflectionOpenTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.startOfDay(for: dueDate) <= calendar.startOfDay(for: date)
            }
            .count

        return TaskReflectionSummary(
            completedCount: projection.reflectionCompletedTasks.count,
            scheduledCount: scheduledCount,
            carryOverCount: carryOverCount,
            overdueOpenCount: projection.reflectionOpenTasks.filter { $0.isOverdue }.count
        )
    }

    private func makeHabitSummary(from habits: [HabitOccurrenceSummary]) -> HabitReflectionSummary? {
        guard habits.isEmpty == false else { return nil }
        let keptCount = habits.filter { $0.state == .completed }.count
        let missedCount = habits.filter { $0.state == .missed || $0.state == .skipped }.count
        let atRisk = habits
            .filter { $0.riskState != .stable }
            .sorted { lhs, rhs in
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak > rhs.currentStreak
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .first

        return HabitReflectionSummary(
            keptCount: keptCount,
            targetCount: habits.count,
            missedCount: missedCount,
            atRiskHabitID: atRisk?.habitID,
            atRiskHabitTitle: atRisk?.title,
            currentStreak: atRisk?.currentStreak
        )
    }

    private func makePulseNote(
        taskSummary: TaskReflectionSummary,
        habitSummary: HabitReflectionSummary?,
        calendarSummary: CalendarReflectionSummary?
    ) -> String {
        if taskSummary.completedCount >= max(1, taskSummary.scheduledCount / 2) {
            return "Strong close. Keep the next day tight and protect the first real focus window."
        }
        if let habitSummary, let habitTitle = habitSummary.atRiskHabitTitle {
            return "Reset the day by protecting \(habitTitle) early and shrinking the task list."
        }
        if let calendarSummary, calendarSummary.meetingMinutes >= 180 {
            return "Your calendar is doing damage tomorrow. Start with one important task before meetings spread."
        }
        return "Keep the next day deliberate: one clear priority, one protected habit, one smaller stabilizer."
    }

    private func makeBiggestWins(
        completedTasks: [TaskDefinition],
        habits: [HabitOccurrenceSummary],
        taskSummary: TaskReflectionSummary
    ) -> [ReflectionHighlight] {
        var wins: [ReflectionHighlight] = completedTasks
            .sorted { lhs, rhs in
                if lhs.priority.scorePoints != rhs.priority.scorePoints {
                    return lhs.priority.scorePoints > rhs.priority.scorePoints
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(2)
            .map {
                ReflectionHighlight(title: $0.title, detail: $0.projectName)
            }

        if wins.count < 2, taskSummary.carryOverCount == 0, taskSummary.completedCount > 0 {
            wins.append(ReflectionHighlight(title: "Cleared the day without carryover", detail: nil))
        }

        if wins.count < 2,
           let rescuedHabit = habits.first(where: { $0.riskState != .stable && $0.state == .completed }) {
            wins.append(
                ReflectionHighlight(
                    title: "Protected \(rescuedHabit.title)",
                    detail: "Streak at \(rescuedHabit.currentStreak)"
                )
            )
        }

        return Array(wins.prefix(2))
    }

    private func makeClosedTasks(from completedTasks: [TaskDefinition]) -> [ReflectionTaskMiniRow] {
        completedTasks
            .sorted { lhs, rhs in
                if lhs.priority.scorePoints != rhs.priority.scorePoints {
                    return lhs.priority.scorePoints > rhs.priority.scorePoints
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(3)
            .map { task in
                ReflectionTaskMiniRow(
                    id: task.id,
                    title: task.title,
                    projectName: task.projectName
                )
            }
    }

    private func makeHabitGrid(from habits: [HabitOccurrenceSummary]) -> [ReflectionHabitMiniRow] {
        habits
            .sorted { lhs, rhs in
                let lhsRisk = habitRiskRank(lhs.riskState)
                let rhsRisk = habitRiskRank(rhs.riskState)
                if lhsRisk != rhsRisk {
                    return lhsRisk > rhsRisk
                }
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak > rhs.currentStreak
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(4)
            .map { habit in
                ReflectionHabitMiniRow(
                    id: habit.habitID,
                    title: habit.title,
                    colorFamily: HabitColorFamily.family(for: habit.colorHex),
                    currentStreak: habit.currentStreak,
                    last7Days: Array(habit.last14Days.suffix(7))
                )
            }
    }

    private func missedHabitTitles(from habits: [HabitOccurrenceSummary]) -> [String] {
        habits
            .filter { $0.state == .missed || $0.state == .skipped }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map(\.title)
    }

    private func habitRiskRank(_ risk: HabitRiskState) -> Int {
        switch risk {
        case .broken:
            return 2
        case .atRisk:
            return 1
        case .stable:
            return 0
        }
    }
}

public final class SaveDailyReflectionAndPlanUseCase: @unchecked Sendable {
    private let reflectionStore: DailyReflectionStoreProtocol
    private let markDailyReflection: MarkDailyReflectionCompleteUseCase
    private let notificationCenter: NotificationCenter
    private let calendar: Calendar

    public init(
        reflectionStore: DailyReflectionStoreProtocol,
        markDailyReflection: MarkDailyReflectionCompleteUseCase,
        notificationCenter: NotificationCenter = .default,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.reflectionStore = reflectionStore
        self.markDailyReflection = markDailyReflection
        self.notificationCenter = notificationCenter
        self.calendar = calendar
    }

    public func execute(
        snapshot: DailyReflectionSnapshot,
        input: DailyReflectionInput,
        plan: EditableDailyPlan,
        replaceExistingManualDraft: Bool = false,
        completion: @escaping @Sendable (Result<SaveDailyReflectionAndPlanResult, Error>) -> Void
    ) {
        let payload = ReflectionPayload(
            reflectionDate: snapshot.reflectionDate,
            planningDate: snapshot.planningDate,
            mode: snapshot.mode,
            mood: input.mood,
            energy: input.energy,
            frictionTags: input.frictionTags,
            note: input.note
        )

        markDailyReflection.execute(on: snapshot.reflectionDate, payload: payload) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let xpResult):
                do {
                    let existingDraft = self.reflectionStore.fetchPlanDraft(on: plan.planningDate)
                    let preservedManualDraft = existingDraft?.source == .manual && replaceExistingManualDraft == false
                    let savedDraft: DailyPlanDraft?
                    if preservedManualDraft {
                        savedDraft = existingDraft
                    } else {
                        var draft = plan.makeDraft(updatedAt: Date())
                        draft = DailyPlanDraft(
                            date: draft.date,
                            topTasks: draft.topTasks,
                            suggestedFocusBlock: draft.suggestedFocusBlock,
                            protectedHabitID: draft.protectedHabitID,
                            protectedHabitTitle: draft.protectedHabitTitle,
                            protectedHabitStreak: draft.protectedHabitStreak,
                            primaryRisk: draft.primaryRisk,
                            primaryRiskDetail: draft.primaryRiskDetail,
                            source: .reflection,
                            updatedAt: draft.updatedAt
                        )
                        savedDraft = try self.reflectionStore.savePlanDraft(draft, replaceExisting: true)
                    }

                    let dateKey = self.dateStamp(for: snapshot.reflectionDate)

                    LifeBoardNotificationRuntime.orchestrator?.reconcile(reason: "daily_reflection_saved")
                    self.notificationCenter.post(
                        name: .dailyReflectionCompleted,
                        object: nil,
                        userInfo: [
                            "dateKey": dateKey,
                            "planningDateKey": self.dateStamp(for: snapshot.planningDate),
                            "planningDate": self.calendar.startOfDay(for: snapshot.planningDate),
                            "preservedManualDraft": preservedManualDraft
                        ]
                    )

                    completion(
                        .success(
                            SaveDailyReflectionAndPlanResult(
                                target: DailyReflectionTarget(
                                    mode: snapshot.mode,
                                    reflectionDate: snapshot.reflectionDate,
                                    planningDate: snapshot.planningDate
                                ),
                                reflectionPayload: self.reflectionStore.fetchReflectionPayload(on: snapshot.reflectionDate),
                                planDraft: savedDraft,
                                xpResult: xpResult,
                                preservedExistingManualDraft: preservedManualDraft
                            )
                        )
                    )
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func dateStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: calendar.startOfDay(for: date))
    }
}

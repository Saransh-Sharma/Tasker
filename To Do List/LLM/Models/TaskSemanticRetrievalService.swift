import Foundation

struct TaskSemanticHit {
    let taskID: UUID
    let score: Double
    let text: String
}

struct TaskSemanticSearchResult {
    let hits: [TaskSemanticHit]
    let fallbackReason: String?
}

final class TaskSemanticRetrievalService {
    static let shared = TaskSemanticRetrievalService()

    private let embeddingEngine: TaskEmbeddingEngine
    private let indexStore: TaskSemanticIndexStore

    /// Initializes a new instance.
    init(
        embeddingEngine: TaskEmbeddingEngine = TaskEmbeddingEngine(),
        indexStore: TaskSemanticIndexStore = TaskSemanticIndexStore()
    ) {
        self.embeddingEngine = embeddingEngine
        self.indexStore = indexStore
    }

    /// Executes loadPersistedIndex.
    func loadPersistedIndex() {
        indexStore.loadPersisted()
    }

    /// Executes persistIndex.
    func persistIndex() {
        indexStore.persist()
    }

    /// Executes index.
    func index(tasks: [TaskDefinition], tagNameLookup: [UUID: String] = [:]) {
        for task in tasks {
            let text = makeIndexText(task: task, tagNameLookup: tagNameLookup)
            guard let vector = embeddingEngine.vector(for: text) else { continue }
            indexStore.upsert(taskID: task.id, text: text, vector: vector)
        }
    }

    /// Executes rebuildIndex.
    func rebuildIndex(tasks: [TaskDefinition], tagNameLookup: [UUID: String] = [:]) {
        let items: [(taskID: UUID, text: String, vector: [Double])] = tasks.compactMap { task in
            let text = makeIndexText(task: task, tagNameLookup: tagNameLookup)
            guard let vector = embeddingEngine.vector(for: text) else { return nil }
            return (task.id, text, vector)
        }
        indexStore.replaceAll(items)
    }

    /// Executes remove.
    func remove(taskID: UUID) {
        indexStore.remove(taskID: taskID)
    }

    /// Executes search.
    func search(query: String, topK: Int = 8) -> [TaskSemanticHit] {
        searchDetailed(query: query, topK: topK).hits
    }

    /// Executes searchDetailed.
    func searchDetailed(query: String, topK: Int = 8) -> TaskSemanticSearchResult {
        guard let queryVector = embeddingEngine.vector(for: query) else {
            logWarning(
                event: "assistant_semantic_fallback_lexical",
                message: "Semantic fallback to lexical because embedding unavailable",
                fields: ["reason": "embedding_unavailable"]
            )
            return TaskSemanticSearchResult(hits: [], fallbackReason: "embedding_unavailable")
        }

        let snapshot = indexStore.snapshot()
        guard snapshot.isEmpty == false else {
            logWarning(
                event: "assistant_semantic_fallback_lexical",
                message: "Semantic fallback to lexical because semantic index is empty",
                fields: ["reason": "index_empty"]
            )
            return TaskSemanticSearchResult(hits: [], fallbackReason: "index_empty")
        }

        let hits = snapshot.map { item in
            TaskSemanticHit(
                taskID: item.taskID,
                score: TaskEmbeddingEngine.cosineSimilarity(queryVector, item.vector),
                text: item.text
            )
        }

        return TaskSemanticSearchResult(
            hits: hits
                .sorted { $0.score > $1.score }
                .prefix(topK)
                .map { $0 },
            fallbackReason: nil
        )
    }

    /// Executes rerank.
    func rerank(taskIDs: [UUID], query: String) -> [UUID] {
        let result = searchDetailed(query: query, topK: max(20, taskIDs.count))
        let scores = Dictionary(uniqueKeysWithValues: result.hits.map { ($0.taskID, $0.score) })
        guard scores.isEmpty == false else { return taskIDs }
        let originalOrder = Dictionary(uniqueKeysWithValues: taskIDs.enumerated().map { ($1, $0) })
        return taskIDs.sorted { lhs, rhs in
            let ls = scores[lhs] ?? 0
            let rs = scores[rhs] ?? 0
            if ls == rs {
                return (originalOrder[lhs] ?? 0) < (originalOrder[rhs] ?? 0)
            }
            return ls > rs
        }
    }

    /// Executes makeIndexText.
    private func makeIndexText(task: TaskDefinition, tagNameLookup: [UUID: String]) -> String {
        let tags = task.tagIDs.compactMap { tagNameLookup[$0] }
        return [
            task.title,
            task.details ?? "",
            task.projectName ?? "",
            tags.joined(separator: " ")
        ].joined(separator: " ")
    }

    /// Executes indexMetadata.
    func indexMetadata() -> (taskCount: Int, lastIndexedAt: Date?) {
        indexStore.metadataSnapshot()
    }
}

actor TaskSemanticIndexRefreshCoordinator {
    static let shared = TaskSemanticIndexRefreshCoordinator()

    private let semanticService: TaskSemanticRetrievalService
    private let rebuildQueue = DispatchQueue(
        label: "tasker.semantic-index-refresh",
        qos: .utility
    )
    private let debounceNanoseconds: UInt64

    private var taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private var tagRepository: TagRepositoryProtocol?
    private var pendingDebounceTask: _Concurrency.Task<Void, Never>?
    private var isRefreshing = false
    private var refreshRequestedWhileInFlight = false
    private var pendingReasons: Set<String> = []
    private var lastStalenessProbeAt: Date?
    private var lastStalenessProbeResult: Bool?
    private var lastKnownRepositoryWatermark: Date?

    init(
        semanticService: TaskSemanticRetrievalService = .shared,
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.semanticService = semanticService
        self.debounceNanoseconds = debounceNanoseconds
    }

    func configure(
        taskReadModelRepository: TaskReadModelRepositoryProtocol?,
        tagRepository: TagRepositoryProtocol?
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.tagRepository = tagRepository
    }

    nonisolated func requestRefreshSoon(reason: String) {
        _Concurrency.Task {
            await self.requestRefresh(reason: reason)
        }
    }

    nonisolated func requestRefreshIfStaleSoon(reason: String) {
        _Concurrency.Task {
            let stale = await self.isIndexStale()
            if stale {
                await self.requestRefresh(reason: "\(reason)_stale")
            }
        }
    }

    @discardableResult
    func shouldUseSemanticIndex(reason: String) async -> Bool {
        let stale = await isIndexStale()
        if stale {
            requestRefresh(reason: "\(reason)_stale")
            logWarning(
                event: "assistant_semantic_index_stale_fallback",
                message: "Semantic index is stale; scheduling background refresh and falling back",
                fields: [
                    "reason": reason,
                    "index_task_count": String(semanticService.indexMetadata().taskCount)
                ]
            )
            return false
        }
        return true
    }

    @discardableResult
    func refreshIfStaleNow(reason: String) async -> Bool {
        let stale = await isIndexStale()
        guard stale else { return false }
        await runRefresh(reason: "\(reason)_stale")
        return true
    }

    func requestRefresh(reason: String) {
        pendingReasons.insert(reason)
        pendingDebounceTask?.cancel()
        let debounce = debounceNanoseconds
        pendingDebounceTask = _Concurrency.Task {
            if debounce > 0 {
                try? await _Concurrency.Task.sleep(nanoseconds: debounce)
            }
            await self.flushDebouncedRefresh()
        }
    }

    private func flushDebouncedRefresh() async {
        pendingDebounceTask = nil
        guard isRefreshing == false else {
            refreshRequestedWhileInFlight = true
            return
        }

        let reasons = pendingReasons
        pendingReasons.removeAll()
        let reason = reasons.isEmpty ? "unknown" : reasons.sorted().joined(separator: ",")
        await runRefresh(reason: reason)
    }

    private func runRefresh(reason: String) async {
        guard let taskReadModelRepository else {
            logWarning(
                event: "assistant_semantic_index_refresh_skipped",
                message: "Semantic index refresh skipped because repository is unavailable",
                fields: ["reason": reason]
            )
            return
        }

        guard isRefreshing == false else {
            refreshRequestedWhileInFlight = true
            return
        }

        isRefreshing = true
        let startedAt = Date()
        defer {
            isRefreshing = false
            if refreshRequestedWhileInFlight {
                refreshRequestedWhileInFlight = false
                requestRefresh(reason: "coalesced_followup")
            }
        }

        do {
            let taskSlice = try await taskReadModelRepository.fetchTasksAsync(
                query: TaskReadQuery(
                    includeCompleted: true,
                    sortBy: .updatedAtDescending,
                    limit: 5_000,
                    offset: 0
                )
            )
            let tags = try await tagRepository?.fetchAllAsync() ?? []
            let tagLookup = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
            let latestUpdatedAt = try await taskReadModelRepository.fetchLatestTaskUpdatedAtAsync()

            await rebuildIndexOnUtilityQueue(tasks: taskSlice.tasks, tagLookup: tagLookup)
            semanticService.persistIndex()

            lastKnownRepositoryWatermark = latestUpdatedAt
            lastStalenessProbeAt = Date()
            lastStalenessProbeResult = false

            logWarning(
                event: "assistant_semantic_index_refresh_completed",
                message: "Semantic index refresh completed off CRUD path",
                fields: [
                    "reason": reason,
                    "task_count": String(taskSlice.tasks.count),
                    "duration_ms": String(Int(Date().timeIntervalSince(startedAt) * 1_000))
                ]
            )
        } catch {
            logWarning(
                event: "assistant_semantic_index_refresh_failed",
                message: "Semantic index refresh failed",
                fields: [
                    "reason": reason,
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func isIndexStale() async -> Bool {
        // Short cache to avoid repeated read-model probes during one assistant interaction burst.
        if let lastStalenessProbeAt,
           let lastStalenessProbeResult,
           Date().timeIntervalSince(lastStalenessProbeAt) < 0.75 {
            return lastStalenessProbeResult
        }

        let metadata = semanticService.indexMetadata()
        guard let taskReadModelRepository else {
            lastStalenessProbeAt = Date()
            lastStalenessProbeResult = false
            return false
        }

        do {
            let latestUpdatedAt = try await taskReadModelRepository.fetchLatestTaskUpdatedAtAsync()
            lastKnownRepositoryWatermark = latestUpdatedAt
            let stale: Bool
            if let latestUpdatedAt {
                guard let lastIndexedAt = metadata.lastIndexedAt else {
                    stale = true
                    lastStalenessProbeAt = Date()
                    lastStalenessProbeResult = stale
                    return stale
                }
                stale = latestUpdatedAt > lastIndexedAt
            } else {
                stale = metadata.taskCount > 0
            }

            lastStalenessProbeAt = Date()
            lastStalenessProbeResult = stale
            return stale
        } catch {
            logWarning(
                event: "assistant_semantic_index_staleness_probe_failed",
                message: "Semantic index staleness probe failed",
                fields: ["error": error.localizedDescription]
            )
            lastStalenessProbeAt = Date()
            lastStalenessProbeResult = false
            return false
        }
    }

    private func rebuildIndexOnUtilityQueue(
        tasks: [TaskDefinition],
        tagLookup: [UUID: String]
    ) async {
        let semanticService = self.semanticService
        await withCheckedContinuation { continuation in
            rebuildQueue.async {
                semanticService.rebuildIndex(tasks: tasks, tagNameLookup: tagLookup)
                continuation.resume()
            }
        }
    }
}

private extension TaskReadModelRepositoryProtocol {
    func fetchTasksAsync(query: TaskReadQuery) async throws -> TaskDefinitionSliceResult {
        try await withCheckedThrowingContinuation { continuation in
            fetchTasks(query: query) { result in
                continuation.resume(with: result)
            }
        }
    }

    func fetchLatestTaskUpdatedAtAsync() async throws -> Date? {
        try await withCheckedThrowingContinuation { continuation in
            fetchLatestTaskUpdatedAt { result in
                continuation.resume(with: result)
            }
        }
    }
}

private extension TagRepositoryProtocol {
    func fetchAllAsync() async throws -> [TagDefinition] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAll { result in
                continuation.resume(with: result)
            }
        }
    }
}

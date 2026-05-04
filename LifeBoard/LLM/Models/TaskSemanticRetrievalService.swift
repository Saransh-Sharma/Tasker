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
    private let activationStateQueue = DispatchQueue(label: "TaskSemanticRetrievalService.activationState")
    private var activationState: SemanticActivationState = .inactive
    private var needsFullRebuild = false

    private enum SemanticActivationState {
        case inactive
        case activating
        case active
    }

    /// Initializes a new instance.
    init(
        embeddingEngine: TaskEmbeddingEngine = TaskEmbeddingEngine(),
        indexStore: TaskSemanticIndexStore = TaskSemanticIndexStore()
    ) {
        self.embeddingEngine = embeddingEngine
        self.indexStore = indexStore
    }

    var isActivated: Bool {
        activationStateQueue.sync {
            activationState == .active
        }
    }

    var shouldPersistOnBackgroundTransition: Bool {
        isActivated && indexStore.hasDirtyChanges
    }

    var hasPersistedIndex: Bool {
        indexStore.hasPersistedIndex
    }

    var itemCount: Int {
        indexStore.itemCount
    }

    /// Executes loadPersistedIndex.
    func loadPersistedIndex() {
        indexStore.loadPersisted()
    }

    /// Executes persistIndex.
    func persistIndex() {
        indexStore.persist()
    }

    func markIndexOutdated() {
        activationStateQueue.sync {
            needsFullRebuild = true
        }
    }

    func releaseInMemoryResources() {
        indexStore.unloadFromMemory()
        activationStateQueue.sync {
            activationState = .inactive
        }
    }

    func activateIfNeeded(rebuildIfMissing: @escaping () async -> Void) async {
        let activationDecision = activationStateQueue.sync { () -> (shouldLoadPersisted: Bool, shouldRebuild: Bool)? in
            switch activationState {
            case .activating, .active:
                return nil
            case .inactive:
                activationState = .activating
                let shouldLoadPersisted = indexStore.hasPersistedIndex
                let shouldRebuild = needsFullRebuild || shouldLoadPersisted == false
                return (shouldLoadPersisted, shouldRebuild)
            }
        }
        guard let activationDecision else { return }

        TaskerMemoryDiagnostics.checkpoint(
            event: "semantic_activation_started",
            message: "Activating semantic retrieval resources",
            fields: [
                "has_persisted_index": activationDecision.shouldLoadPersisted ? "true" : "false",
                "should_rebuild": activationDecision.shouldRebuild ? "true" : "false"
            ],
            counts: ["semantic_items": indexStore.itemCount]
        )

        if activationDecision.shouldRebuild {
            await rebuildIfMissing()
        } else if activationDecision.shouldLoadPersisted {
            indexStore.loadPersisted()
        }

        activationStateQueue.sync {
            activationState = .active
            needsFullRebuild = false
        }

        TaskerMemoryDiagnostics.checkpoint(
            event: "semantic_activation_finished",
            message: "Semantic retrieval resources are ready",
            counts: ["semantic_items": indexStore.itemCount]
        )
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
        activationStateQueue.sync {
            needsFullRebuild = false
        }
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
    func searchDetailed(
        query: String,
        topK: Int = 8,
        limitingTo taskIDs: Set<UUID>? = nil
    ) -> TaskSemanticSearchResult {
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

        let candidates: [(taskID: UUID, text: String, vector: [Double])]
        if let taskIDs {
            candidates = snapshot.filter { taskIDs.contains($0.taskID) }
        } else {
            candidates = snapshot
        }
        guard candidates.isEmpty == false else {
            return TaskSemanticSearchResult(hits: [], fallbackReason: "candidate_filter_empty")
        }

        let hits = candidates.map { item in
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
        let result = searchDetailed(
            query: query,
            topK: max(20, taskIDs.count),
            limitingTo: Set(taskIDs)
        )
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
}

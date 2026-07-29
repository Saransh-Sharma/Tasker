import Foundation

/// Turns a reviewed capture into a canonical `TaskDefinition`.
///
/// This is the adapter half of `InboxTaskWriting`: the coordinator owns
/// ordering and reversal, and everything here is name-to-identifier resolution
/// against the repositories the parser deliberately does not have.
///
/// All three repository protocols are completion-based, so each call is bridged
/// with a checked continuation rather than reimplemented.
public struct CoreDataInboxTaskWriter: InboxTaskWriting {
    private let tasks: any TaskDefinitionRepositoryProtocol
    private let projects: any ProjectRepositoryProtocol
    private let tags: any TagRepositoryProtocol
    private let taskTagLinks: (any TaskTagLinkRepositoryProtocol)?

    public init(
        tasks: any TaskDefinitionRepositoryProtocol,
        projects: any ProjectRepositoryProtocol,
        tags: any TagRepositoryProtocol,
        taskTagLinks: (any TaskTagLinkRepositoryProtocol)? = nil
    ) {
        self.tasks = tasks
        self.projects = projects
        self.tags = tags
        self.taskTagLinks = taskTagLinks
    }

    // MARK: - InboxTaskWriting

    public func createTask(_ request: InboxCaptureCommitRequest) async throws -> UUID {
        let projectID = try await resolveProjectID(named: request.projectName)
        let resolvedContext = Self.context(for: request.contextName)
        // An unrecognized "@somewhere" becomes a tag rather than being dropped.
        // The review chips showed it to the user; discarding it at commit time
        // would be the same silent-loss problem the chips exist to prevent, and
        // `TaskContext` is a closed enum that cannot grow to fit free text.
        var tagNames = request.tagNames
        if let contextName = request.contextName, resolvedContext == nil {
            tagNames.append(contextName)
        }
        let tagIDs = try await resolveTagIDs(named: tagNames)

        var create = CreateTaskDefinitionRequest(
            title: request.title,
            details: nil,
            projectID: projectID,
            dueDate: request.dueDate,
            createdAt: Date()
        )
        create.isAllDay = request.isAllDay
        create.estimatedDuration = request.estimatedDuration
        create.repeatPattern = request.repeatPattern
        create.tagIDs = tagIDs
        if let priority = request.priority { create.priority = priority }
        if let resolvedContext { create.context = resolvedContext }

        let created: TaskDefinition = try await withCheckedThrowingContinuation { continuation in
            tasks.create(request: create) { continuation.resume(with: $0) }
        }
        return created.id
    }

    public func deleteTask(id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tasks.delete(id: id) { continuation.resume(with: $0) }
        }
    }

    public func moveTask(id: UUID, toProject projectID: UUID?) async throws {
        // A nil destination means "no project", which the schema expresses as
        // the Inbox project rather than a null column — every task belongs
        // somewhere, and Inbox is where untriaged work lives.
        // Written out rather than with `??` because its right-hand side is an
        // autoclosure, which cannot be async.
        let destination: UUID
        if let projectID {
            destination = projectID
        } else {
            destination = try await inboxProjectID()
        }
        var update = UpdateTaskDefinitionRequest(id: id)
        update.projectID = destination
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TaskDefinition, Error>) in
            tasks.update(request: update) { continuation.resume(with: $0) }
        }
    }

    public func task(id: UUID) async throws -> TaskDefinition? {
        try await withCheckedThrowingContinuation { continuation in
            tasks.fetchTaskDefinition(id: id) { continuation.resume(with: $0) }
        }
    }

    public func mergeTask(id: UUID, request: InboxCaptureCommitRequest) async throws -> TaskDefinition {
        guard let existing = try await task(id: id) else {
            throw InboxCommitFailure.mergeUnavailable
        }
        let resolvedContext = Self.context(for: request.contextName)
        var incomingTagNames = request.tagNames
        if let contextName = request.contextName, resolvedContext == nil {
            incomingTagNames.append(contextName)
        }
        let incomingTagIDs = try await resolveTagIDs(named: incomingTagNames)

        var update = UpdateTaskDefinitionRequest(id: id)
        update.title = request.title
        update.tagIDs = Array(Set(existing.tagIDs).union(incomingTagIDs))
            .sorted { $0.uuidString < $1.uuidString }
        if existing.dueDate == nil, let dueDate = request.dueDate {
            update.dueDate = dueDate
            update.isAllDay = request.isAllDay
        }
        if existing.estimatedDuration == nil {
            update.estimatedDuration = request.estimatedDuration
        }
        if existing.repeatPattern == nil {
            update.repeatPattern = request.repeatPattern
        }
        if existing.priority == .low {
            update.priority = request.priority
        }
        if existing.context == .anywhere {
            update.context = resolvedContext
        }
        return try await withCheckedThrowingContinuation { continuation in
            tasks.update(request: update) { continuation.resume(with: $0) }
        }
    }

    public func restoreTask(_ snapshot: TaskDefinition) async throws {
        let _: TaskDefinition = try await withCheckedThrowingContinuation { continuation in
            tasks.update(snapshot) { continuation.resume(with: $0) }
        }
    }

    // MARK: - Resolution

    /// Maps a parsed `@token` onto the closed `TaskContext` enum.
    ///
    /// Synonyms are included because people write where they are, not the
    /// vocabulary an enum happens to use: "work" and "desk" both mean office.
    static func context(for name: String?) -> TaskContext? {
        guard let name = name?.lowercased(), name.isEmpty == false else { return nil }
        switch name {
        case "anywhere": return .anywhere
        case "home", "house": return .home
        case "office", "work", "desk": return .office
        case "computer", "laptop", "mac": return .computer
        case "phone", "call", "calls": return .phone
        case "errands", "errand", "store", "shop": return .errands
        case "outdoor", "outdoors", "outside": return .outdoor
        case "gym", "workout": return .gym
        case "commute", "transit", "train": return .commute
        case "meeting", "meetings": return .meeting
        default: return nil
        }
    }

    private func resolveProjectID(named name: String?) async throws -> UUID {
        guard let name, name.isEmpty == false else { return try await inboxProjectID() }
        let existing: Project? = try await withCheckedThrowingContinuation { continuation in
            projects.fetchProject(withName: name) { continuation.resume(with: $0) }
        }
        // A capture naming an unknown project files into the Inbox rather than
        // creating one. Project creation is a deliberate act with its own
        // review; inventing projects from a typo would quietly litter the
        // sidebar, and the name survives on the review chip either way.
        if let existing { return existing.id }
        return try await inboxProjectID()
    }

    private func inboxProjectID() async throws -> UUID {
        let inbox: Project = try await withCheckedThrowingContinuation { continuation in
            projects.fetchInboxProject { continuation.resume(with: $0) }
        }
        return inbox.id
    }

    /// Get-or-create, matched case-insensitively.
    ///
    /// Unlike projects, tags *are* created on demand: a tag is a lightweight
    /// label with no structure behind it, and requiring the user to pre-create
    /// one would make `#tag` in a capture useless the first time it is typed.
    private func resolveTagIDs(named names: [String]) async throws -> [UUID] {
        guard names.isEmpty == false else { return [] }
        let existing: [TagDefinition] = try await withCheckedThrowingContinuation { continuation in
            tags.fetchAll { continuation.resume(with: $0) }
        }
        var byName = Dictionary(
            existing.map { ($0.name.lowercased(), $0.id) },
            uniquingKeysWith: { first, _ in first }
        )

        var result: [UUID] = []
        for name in names {
            let key = name.lowercased()
            if let id = byName[key] {
                result.append(id)
                continue
            }
            let definition = TagDefinition(id: UUID(), name: name, sortOrder: existing.count + result.count)
            let created: TagDefinition = try await withCheckedThrowingContinuation { continuation in
                tags.create(definition) { continuation.resume(with: $0) }
            }
            byName[key] = created.id
            result.append(created.id)
        }
        return result
    }
}

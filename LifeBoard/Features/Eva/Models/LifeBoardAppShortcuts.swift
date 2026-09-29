import AppIntents
import CoreData
import Foundation

enum ShortcutDeepLink {
    static func chatURL(prompt: String?) -> URL {
        var components = URLComponents()
        components.scheme = "lifeboard"
        components.host = "chat"

        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedPrompt, trimmedPrompt.isEmpty == false {
            var allowedCharacters = CharacterSet.urlQueryAllowed
            allowedCharacters.remove(charactersIn: "?&=+#")
            let encodedPrompt = trimmedPrompt.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? trimmedPrompt
            components.percentEncodedQueryItems = [URLQueryItem(name: "prompt", value: encodedPrompt)]
        }

        guard let url = components.url else {
            return URL(string: "lifeboard://chat")!
        }
        return url
    }

    static func focusURL() -> URL {
        URL(string: "lifeboard://focus")!
    }

    static func chatPrompt(from url: URL) -> String? {
        guard url.host?.lowercased() == "chat" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let prompt = components?.queryItems?.first(where: { $0.name == "prompt" })?.value
        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt?.isEmpty == false ? trimmedPrompt : nil
    }
}

enum ShortcutRuntimeError: LocalizedError {
    case unavailable
    case bootstrapFailed(String)
    case handoffFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "Couldn’t run this shortcut. Open LifeBoard and try again.")
        case .bootstrapFailed(let message):
            return message
        case .handoffFailed(let message):
            return message
        }
    }
}

struct InboxTaskCaptureService {
    let projectRepository: ProjectRepositoryProtocol
    let createTaskDefinitionUseCase: CreateTaskDefinitionUseCase

    /// Creates an Inbox task from a raw title. Natural-language dates ("call mom tomorrow 3pm")
    /// are extracted via `TaskCaptureParser` unless the caller supplies an explicit due date.
    func createTask(
        title: String,
        details: String?,
        explicitDueDate: Date? = nil
    ) async throws -> TaskDefinition {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            throw NSError(
                domain: "InboxTaskCaptureService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "Add a task title.")]
            )
        }

        let parsed = TaskCaptureParser.parse(trimmedTitle)
        let resolvedTitle = parsed.cleanTitle.isEmpty ? trimmedTitle : parsed.cleanTitle
        let resolvedDueDate = explicitDueDate ?? parsed.dueDate
        let resolvedIsAllDay = explicitDueDate == nil ? parsed.isAllDay : false

        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let inboxProject = try await ensureInboxProject()
        let request = CreateTaskDefinitionRequest(
            title: resolvedTitle,
            details: trimmedDetails?.isEmpty == false ? trimmedDetails : nil,
            projectID: inboxProject.id,
            projectName: inboxProject.name,
            lifeAreaID: inboxProject.lifeAreaID,
            dueDate: resolvedDueDate,
            isAllDay: resolvedIsAllDay,
            createdAt: Date()
        )
        return try await createTask(request: request)
    }

    private func ensureInboxProject() async throws -> Project {
        let useCase = EnsureInboxProjectUseCase(projectRepository: projectRepository)
        return try await withCheckedThrowingContinuation { continuation in
            useCase.execute { result in
                continuation.resume(with: result)
            }
        }
    }

    private func createTask(request: CreateTaskDefinitionRequest) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            createTaskDefinitionUseCase.execute(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }
}

private struct HeadlessLifeBoardShortcutCoordinator {
    let projectRepository: ProjectRepositoryProtocol
    let createTaskDefinitionUseCase: CreateTaskDefinitionUseCase
    let persistentContainer: NSPersistentContainer
}

fileprivate struct HeadlessLifeOSRepositories {
    let phaseII: CoreDataLifeBoardPhaseIIRepository
    let track: CoreDataTrackFoundationRepository
    let wellness: CoreDataWellnessRepository
    let nutrition: CoreDataNutritionRepository
    let moments: CoreDataLifeMomentRepository
}

enum ShortcutDependencyResolver {
    static func inboxTaskCaptureService() async throws -> InboxTaskCaptureService {
        let runtime = try await headlessRuntime()
        return InboxTaskCaptureService(
            projectRepository: runtime.projectRepository,
            createTaskDefinitionUseCase: runtime.createTaskDefinitionUseCase
        )
    }

    fileprivate static func lifeOSRepositories() async throws -> HeadlessLifeOSRepositories {
        let runtime = try await headlessRuntime()
        return .init(
            phaseII: CoreDataLifeBoardPhaseIIRepository(container: runtime.persistentContainer),
            track: CoreDataTrackFoundationRepository(container: runtime.persistentContainer),
            wellness: CoreDataWellnessRepository(container: runtime.persistentContainer),
            nutrition: CoreDataNutritionRepository(container: runtime.persistentContainer),
            moments: CoreDataLifeMomentRepository(container: runtime.persistentContainer)
        )
    }

    private static func headlessRuntime() async throws -> HeadlessLifeBoardShortcutCoordinator {
        let bootstrapService = PersistentStoreBootstrapService()
        let bootstrapResult = await bootstrapService.bootstrapV3PersistentContainer()

        guard case .ready(let container) = bootstrapResult.state else {
            if case .failed(let message) = bootstrapResult.state {
                throw ShortcutRuntimeError.bootstrapFailed(message)
            }
            throw ShortcutRuntimeError.unavailable
        }

        PersistentRuntimeInitializer().initialize(container: container)
        if V2FeatureFlags.healthIntegrationsV1Enabled {
            let migrationState = try await HealthPrivacyMigrationCoordinator(container: container).migrate()
            guard migrationState == .validated else {
                throw ShortcutRuntimeError.bootstrapFailed(
                    String(localized: "Couldn’t open Health data yet. Try again soon.")
                )
            }
        }

        let syncMode = bootstrapResult.syncMode
        let repositories = LifeBoardPersistenceStack(container: container)
            .makeRepositoryBundle(syncModeProvider: { syncMode })

        return HeadlessLifeBoardShortcutCoordinator(
            projectRepository: repositories.project,
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(
                repository: repositories.taskDefinition,
                taskTagLinkRepository: repositories.taskTagLink,
                taskDependencyRepository: repositories.taskDependency
            ),
            persistentContainer: container
        )
    }
}

private func applyShortcutMutation(
    preview: TransactionPreview,
    apply: @escaping @Sendable () async throws -> String,
    undo: @escaping @Sendable () async throws -> Void
) async throws -> ActionReceipt {
    let coordinator = MutationCoordinator()
    let prepared = await coordinator.prepare(.init(preview: preview, apply: apply, undo: undo))
    return try await coordinator.apply(previewID: prepared.id)
}

@available(iOS 16.0, macOS 13.0, *)
struct QuickJournalCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Journal Entry"
    static let description = IntentDescription("Adds a text entry to today’s journal.")
    static let openAppWhenRun = false

    @Parameter(title: "Entry", requestValueDialog: IntentDialog("What do you want to write?"))
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw $text.needsValueError(IntentDialog("What do you want to write?")) }
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let repository = repositories.phaseII
        let dayDate = Calendar.current.startOfDay(for: Date())
        let previous = try await repository.fetchJournalDay(containing: dayDate)
        var day = previous ?? JournalDayValue(day: dayDate)
        let blockID = UUID()
        day.blocks.append(.init(id: blockID, dayID: day.id, kind: .text, text: content, ordinal: day.blocks.count))
        day.updatedAt = Date()
        let saved = day
        _ = try await applyShortcutMutation(
            preview: .init(destination: .track, summary: "Add journal entry", changes: ["Journal · Today", content], origin: .appIntent),
            apply: {
                try await repository.saveJournalDay(saved)
                try await JournalIndexingService(repository: repository).upsert(saved)
                return "Added to today’s Journal."
            },
            undo: {
                if let previous {
                    try await repository.saveJournalDay(previous)
                    try await JournalIndexingService(repository: repository).upsert(previous)
                } else {
                    try await repository.deleteJournalDay(id: saved.id)
                    try await JournalIndexingService(repository: repository).remove(dayID: saved.id)
                }
            }
        )
        return .result(dialog: "Added to today’s Journal.")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct QuickNoteCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Note"
    static let description = IntentDescription("Saves a text note to LifeBoard.")
    static let openAppWhenRun = false

    @Parameter(title: "Note", requestValueDialog: IntentDialog("What’s the note?"))
    var text: String

    @Parameter(title: "Title")
    var noteTitle: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Save quick note \(\.$text)") {
            \.$noteTitle
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw $text.needsValueError(IntentDialog("What’s the note?"))
        }
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let repository = repositories.phaseII
        var spaces = try await repository.fetchKnowledgeSpaces()
        if spaces.isEmpty {
            let personal = KnowledgeSpaceValue(title: "Personal", icon: "person.crop.circle")
            try await repository.saveKnowledgeSpace(personal)
            spaces = [personal]
        }
        guard let space = spaces.first else { throw ShortcutRuntimeError.unavailable }
        let title = noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteID = UUID()
        let note = KnowledgeNoteValue(
            id: noteID,
            spaceID: space.id,
            title: title?.isEmpty == false ? title! : String(content.prefix(48)),
            blocks: [.init(noteID: noteID, text: content, createdAt: Date(), updatedAt: Date())],
            contentVersion: 1
        )
        _ = try await applyShortcutMutation(
            preview: .init(
                destination: .track,
                summary: "Create a note",
                changes: [note.displayTitle, content],
                origin: .appIntent
            ),
            apply: {
                try await repository.saveKnowledgeNote(note)
                try await KnowledgeIndexingService(repository: repository).upsert(note)
                return "Created \(note.displayTitle)."
            },
            undo: {
                try await repository.deleteKnowledgeNote(id: note.id)
                try await KnowledgeIndexingService(repository: repository).remove(noteID: note.id)
            }
        )
        return .result(
            value: note.displayTitle,
            dialog: IntentDialog(stringLiteral: "Saved \(note.displayTitle) to Notes.")
        )
    }
}

@available(iOS 18.0, macOS 15.0, *)
enum NoteTemplateIntentChoice: String, AppEnum {
    case blank, meeting, project, idea, checklist, research, daily

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note Template")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .blank: "Blank", .meeting: "Meeting", .project: "Project Brief",
        .idea: "Idea", .checklist: "Checklist", .research: "Research", .daily: "Daily Notes"
    ]
}

@available(iOS 18.0, macOS 15.0, *)
struct NoteAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "LifeBoard Note")
    static let defaultQuery = NoteAppEntityQuery()

    let id: UUID
    let title: String
    let isLocked: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: isLocked ? "Locked note" : title),
            subtitle: isLocked ? "Unlock in LifeBoard" : "LifeBoard Notes",
            image: .init(systemName: isLocked ? "lock.fill" : "note.text")
        )
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct NoteAppEntityQuery: EntityStringQuery {
    init() {}

    func entities(for identifiers: [UUID]) async throws -> [NoteAppEntity] {
        let repository = try await ShortcutDependencyResolver.lifeOSRepositories().phaseII
        let requested = Set(identifiers)
        return try await repository.fetchKnowledgeNotes(search: nil, spaceID: nil)
            .filter { requested.contains($0.id) }
            .map(Self.entity)
    }

    func suggestedEntities() async throws -> [NoteAppEntity] {
        let repository = try await ShortcutDependencyResolver.lifeOSRepositories().phaseII
        return try await repository.fetchKnowledgeNotes(query: .init(collection: .recent, limit: 20)).map(Self.entity)
    }

    func entities(matching string: String) async throws -> [NoteAppEntity] {
        let repository = try await ShortcutDependencyResolver.lifeOSRepositories().phaseII
        return try await repository.fetchKnowledgeNotes(query: .init(searchText: string, limit: 20))
            .filter { $0.resolvedLockPolicy == .unlocked }
            .map(Self.entity)
    }

    private static func entity(_ note: KnowledgeNoteValue) -> NoteAppEntity {
        .init(
            id: note.id,
            title: note.resolvedLockPolicy == .unlocked ? note.displayTitle : "Locked note",
            isLocked: note.resolvedLockPolicy != .unlocked
        )
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note from Template"
    static let description = IntentDescription("Creates a note in LifeBoard.")
    static let openAppWhenRun = false

    @Parameter(title: "Title") var noteTitle: String?
    @Parameter(title: "Body") var body: String?
    @Parameter(title: "Template", default: .blank) var template: NoteTemplateIntentChoice

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$template) note") {
            \.$noteTitle
            \.$body
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<NoteAppEntity> & ProvidesDialog {
        let title = noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let content = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty || !content.isEmpty || template != .blank else {
            throw $body.needsValueError(IntentDialog("What’s the note?"))
        }
        let repository = try await ShortcutDependencyResolver.lifeOSRepositories().phaseII
        var spaces = try await repository.fetchKnowledgeSpaces()
        if spaces.isEmpty {
            let personal = KnowledgeSpaceValue(title: "Personal", icon: "person.crop.circle")
            try await repository.saveKnowledgeSpace(personal)
            spaces = [personal]
        }
        guard let space = spaces.first else { throw ShortcutRuntimeError.unavailable }
        let selectedTemplate = KnowledgeNoteTemplate.library.first { $0.id == template.rawValue }
            ?? KnowledgeNoteTemplate.library[0]
        let noteID = UUID()
        var blocks = selectedTemplate.blocks.enumerated().map { index, block in
            KnowledgeBlockValue(noteID: noteID, kind: block.kind, text: block.text, ordinal: index)
        }
        if !content.isEmpty {
            if selectedTemplate.id == "blank" {
                blocks = [.init(noteID: noteID, text: content)]
            } else {
                blocks.insert(.init(noteID: noteID, text: content), at: 0)
                for index in blocks.indices { blocks[index].ordinal = index }
            }
        }
        let note = KnowledgeNoteValue(
            id: noteID,
            spaceID: space.id,
            title: title.isEmpty ? (selectedTemplate.id == "blank" ? String(content.prefix(48)) : selectedTemplate.title) : title,
            blocks: blocks,
            templateID: selectedTemplate.id,
            contentVersion: 1
        )
        try await repository.saveKnowledgeNote(note)
        try await KnowledgeIndexingService(repository: repository).upsert(note)
        let entity = NoteAppEntity(id: note.id, title: note.displayTitle, isLocked: false)
        return .result(value: entity, dialog: "Note saved.")
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct OpenNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"
    static let description = IntentDescription("Opens a selected note in LifeBoard.")
    static let openAppWhenRun = true

    @Parameter(title: "Note") var note: NoteAppEntity

    func perform() async throws -> some IntentResult & OpensIntent & ProvidesDialog {
        let url = URL(string: "lifeboard://note/\(note.id.uuidString)")!
        return .result(
            opensIntent: OpenURLIntent(url),
            dialog: note.isLocked ? "Unlock this note in LifeBoard." : "Opening note."
        )
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct SearchNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Notes"
    static let description = IntentDescription("Searches your notes in LifeBoard.")
    static let openAppWhenRun = true

    @Parameter(title: "Search", requestValueDialog: IntentDialog("What should I search for?"))
    var terms: String

    func perform() async throws -> some IntentResult & OpensIntent & ProvidesDialog {
        let query = terms.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw $terms.needsValueError(IntentDialog("What should I search for?")) }
        var components = URLComponents()
        components.scheme = "lifeboard"
        components.host = "notes"
        components.queryItems = [URLQueryItem(name: "search", value: query)]
        guard let url = components.url else {
            throw ShortcutRuntimeError.handoffFailed(String(localized: "Couldn’t start search."))
        }
        return .result(opensIntent: OpenURLIntent(url), dialog: "Opening Notes search.")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Logs water in LifeBoard.")
    static let openAppWhenRun = false

    @Parameter(title: "Milliliters")
    var milliliters: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard milliliters > 0 else {
            throw ShortcutRuntimeError.handoffFailed(String(localized: "Enter more than 0 mL."))
        }
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let log = HydrationLog(amount: milliliters, unit: .milliliters, source: .manual)
        try await repositories.track.saveHydrationLog(log)
        SystemSurfaceRefresher.requestRefreshSoon()
        return .result(dialog: IntentDialog(stringLiteral: "Logged \(Int(milliliters.rounded())) milliliters of water."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct LogWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Weight"
    static let description = IntentDescription("Logs your weight in LifeBoard.")
    static let openAppWhenRun = false

    @Parameter(title: "Kilograms")
    var kilograms: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard kilograms > 0 else {
            throw ShortcutRuntimeError.handoffFailed(String(localized: "Enter more than 0 kg."))
        }
        let sample = try BodyMetricSample(
            kind: .bodyMass,
            value: kilograms,
            unit: .kilograms,
            source: .manual
        )
        if case .requiresConfirmation(let message) = WellnessOutlierPolicy().review(
            kind: .bodyMass,
            normalizedValue: sample.normalizedValue
        ) {
            throw ShortcutRuntimeError.handoffFailed(message)
        }
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        try await repositories.wellness.save(sample)
        SystemSurfaceRefresher.requestRefreshSoon()
        return .result(dialog: IntentDialog(stringLiteral: "Logged \(kilograms.formatted()) kilograms."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct LogBodyMetricIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Body Metric"
    static let description = IntentDescription("Logs a body measurement with a value and unit.")
    static let openAppWhenRun = false

    @Parameter(title: "Metric", description: "bodyMass, bodyFatPercentage, waistCircumference, or restingHeartRate")
    var metric: String
    @Parameter(title: "Value") var value: Double
    @Parameter(title: "Unit", description: "kilograms, pounds, percent, centimeters, inches, or beatsPerMinute")
    var unit: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let kind = BodyMetricKind(rawValue: metric),
              let displayUnit = WellnessDisplayUnit(rawValue: unit) else {
            throw ShortcutRuntimeError.handoffFailed(String(localized: "Choose a matching metric and unit."))
        }
        let sample = try BodyMetricSample(kind: kind, value: value, unit: displayUnit, source: .manual)
        if case .requiresConfirmation(let message) = WellnessOutlierPolicy().review(
            kind: kind,
            normalizedValue: sample.normalizedValue
        ) {
            throw ShortcutRuntimeError.handoffFailed(message)
        }
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let repository = repositories.wellness
        _ = try await applyShortcutMutation(
            preview: .init(destination: .track, summary: "Log \(kind.title)", changes: ["\(value) \(displayUnit.symbol)"], origin: .appIntent),
            apply: { try await repository.save(sample); return "Logged \(kind.title)." },
            undo: { try await repository.delete(kind: .bodyMetric, id: sample.id) }
        )
        return .result(dialog: IntentDialog(stringLiteral: "Logged \(kind.title)."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct StartFastingTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Fast"
    static let description = IntentDescription("Starts a fast, with an optional target in hours.")
    static let openAppWhenRun = false

    @Parameter(title: "Target hours") var targetHours: Double?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let targetHours, targetHours <= 0 { throw ShortcutRuntimeError.handoffFailed(String(localized: "Enter more than 0 hours.")) }
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let store = FastingTimerStore(repository: FastingRepositoryAdapter(repository: repositories.phaseII))
        let session = try await store.start(targetDuration: targetHours.map { $0 * 3_600 })
        return .result(dialog: IntentDialog(stringLiteral: "Fast started at \(session.startedAt.formatted(date: .omitted, time: .shortened))."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct EndFastingTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "End Fast"
    static let description = IntentDescription("Ends your current fast and saves it.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let store = FastingTimerStore(repository: FastingRepositoryAdapter(repository: repositories.phaseII))
        let session = try await store.finish()
        return .result(dialog: IntentDialog(stringLiteral: "Fast ended after \(LifeBoardDuration.text(seconds: session.elapsed()))."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct CreateCountdownIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Countdown"
    static let description = IntentDescription("Counts down to a date in LifeBoard.")
    static let openAppWhenRun = false

    @Parameter(title: "Title") var momentTitle: String
    @Parameter(title: "Date") var date: Date

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repositories = try await ShortcutDependencyResolver.lifeOSRepositories()
        let repository = repositories.moments
        let moment = try LifeMoment(title: momentTitle, kind: .countdown, eventDate: date)
        _ = try await applyShortcutMutation(
            preview: .init(destination: .insights, summary: "Create countdown", changes: [moment.title, date.formatted(date: .abbreviated, time: .omitted)], origin: .appIntent),
            apply: { try await repository.save(moment); return "Created \(moment.title)." },
            undo: { try await repository.delete(id: moment.id) }
        )
        return .result(dialog: IntentDialog(stringLiteral: "Created \(moment.title)."))
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct LifeBoardAppShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Create task in \(.applicationName)",
                "Capture task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: OpenEvaChatIntent(),
            phrases: [
                "Ask Eva in \(.applicationName)",
                "Ask \(.applicationName)",
                "Open Eva in \(.applicationName)"
            ],
            shortTitle: "Ask Eva",
            systemImageName: "bubble.left.and.bubble.right"
        )

        AppShortcut(
            intent: StartFocusSessionIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Start focus session in \(.applicationName)",
                "Begin focus in \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "scope"
        )

        AppShortcut(
            intent: QuickJournalCaptureIntent(),
            phrases: [
                "Capture a journal moment in \(.applicationName)",
                "Add a journal entry in \(.applicationName)"
            ],
            shortTitle: "Journal Entry",
            systemImageName: "book.closed"
        )
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: [
                "Create a note in \(.applicationName)",
                "Capture a note in \(.applicationName)"
            ],
            shortTitle: "Create Note",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(intent: LogWaterIntent(), phrases: ["Log water in \(.applicationName)"], shortTitle: "Log Water", systemImageName: "drop.fill")
        AppShortcut(intent: LogWeightIntent(), phrases: ["Log weight in \(.applicationName)"], shortTitle: "Log Weight", systemImageName: "scalemass.fill")
        AppShortcut(intent: LogBodyMetricIntent(), phrases: ["Log a body metric in \(.applicationName)"], shortTitle: "Log Metric", systemImageName: "chart.line.uptrend.xyaxis")
        AppShortcut(intent: StartFastingTimerIntent(), phrases: ["Start a fast in \(.applicationName)", "Start fasting timer in \(.applicationName)"], shortTitle: "Start a Fast", systemImageName: "hourglass")
        AppShortcut(intent: CreateCountdownIntent(), phrases: ["Create countdown in \(.applicationName)"], shortTitle: "Countdown", systemImageName: "calendar.badge.clock")
    }
}

extension LifeBoardAppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .orange
    }
}

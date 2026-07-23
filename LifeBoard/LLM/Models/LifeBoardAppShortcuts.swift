import AppIntents
import CoreData
import Foundation

enum LifeBoardShortcutDeepLink {
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

enum LifeBoardShortcutRuntimeError: LocalizedError {
    case unavailable
    case bootstrapFailed(String)
    case handoffFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "LifeBoard shortcuts are unavailable until the app finishes loading."
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
                userInfo: [NSLocalizedDescriptionKey: "Task title cannot be empty."]
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

private struct HeadlessLifeBoardShortcutRuntime {
    let projectRepository: ProjectRepositoryProtocol
    let createTaskDefinitionUseCase: CreateTaskDefinitionUseCase
    let persistentContainer: NSPersistentContainer
}

fileprivate struct HeadlessLifeOSRepositories {
    let phaseII: CoreDataLifeBoardPhaseIIRepository
    let wellness: CoreDataWellnessRepository
    let nutrition: CoreDataNutritionRepository
    let moments: CoreDataLifeMomentRepository
}

enum LifeBoardShortcutDependencyResolver {
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
            wellness: CoreDataWellnessRepository(container: runtime.persistentContainer),
            nutrition: CoreDataNutritionRepository(container: runtime.persistentContainer),
            moments: CoreDataLifeMomentRepository(container: runtime.persistentContainer)
        )
    }

    private static func headlessRuntime() async throws -> HeadlessLifeBoardShortcutRuntime {
        let bootstrapService = LifeBoardPersistentStoreBootstrapService()
        let bootstrapResult = await bootstrapService.bootstrapV3PersistentContainer()

        guard case .ready(let container) = bootstrapResult.state else {
            if case .failed(let message) = bootstrapResult.state {
                throw LifeBoardShortcutRuntimeError.bootstrapFailed(message)
            }
            throw LifeBoardShortcutRuntimeError.unavailable
        }

        LifeBoardPersistentRuntimeInitializer().initialize(container: container)

        let writeGate = SyncWriteGate(modeProvider: { bootstrapResult.syncMode })
        let projectRepository = WriteClosedProjectRepositoryAdapter(
            base: CoreDataProjectRepository(container: container),
            gate: writeGate
        )
        let taskDefinitionRepository = WriteClosedTaskDefinitionRepositoryAdapter(
            base: CoreDataTaskDefinitionRepository(container: container),
            gate: writeGate
        )
        let taskTagLinkRepository = WriteClosedTaskTagLinkRepositoryAdapter(
            base: CoreDataTaskTagLinkRepository(container: container),
            gate: writeGate
        )
        let taskDependencyRepository = WriteClosedTaskDependencyRepositoryAdapter(
            base: CoreDataTaskDependencyRepository(container: container),
            gate: writeGate
        )

        return HeadlessLifeBoardShortcutRuntime(
            projectRepository: projectRepository,
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(
                repository: taskDefinitionRepository,
                taskTagLinkRepository: taskTagLinkRepository,
                taskDependencyRepository: taskDependencyRepository
            ),
            persistentContainer: container
        )
    }
}

private func applyShortcutMutation(
    preview: LifeBoardTransactionPreview,
    apply: @escaping @Sendable () async throws -> String,
    undo: @escaping @Sendable () async throws -> Void
) async throws -> LifeBoardActionReceipt {
    let coordinator = LifeBoardMutationCoordinator()
    let prepared = await coordinator.prepare(.init(preview: preview, apply: apply, undo: undo))
    return try await coordinator.apply(previewID: prepared.id)
}

@available(iOS 16.0, macOS 13.0, *)
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Creates a new Inbox task without opening the app.")
    static let openAppWhenRun = false

    @Parameter(title: "Title", requestValueDialog: IntentDialog("What task do you want to add?"))
    var taskTitle: String

    @Parameter(title: "Details")
    var details: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add task \(\.$taskTitle)") {
            \.$details
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            throw $taskTitle.needsValueError(IntentDialog("What task do you want to add?"))
        }

        let service = try await LifeBoardShortcutDependencyResolver.inboxTaskCaptureService()
        let task = try await service.createTask(title: trimmedTitle, details: details)

        do {
            try ShortcutMutationSignalStore.shared.submitTaskCreated(taskID: task.id)
        } catch {
            throw LifeBoardShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : "LifeBoard created the task but could not refresh the app."
            )
        }

        let confirmation = "Added \(task.title) to Inbox."
        return .result(value: task.title, dialog: IntentDialog(stringLiteral: confirmation))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenEvaChatIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Assistant"
    static let description = IntentDescription("Opens assistant chat with your question prefilled.")
    static let openAppWhenRun = true

    @Parameter(title: "Question")
    var prompt: String?

    func perform() async throws -> some IntentResult {
        do {
            try PendingShortcutLaunchActionStore.shared.submit(
                PendingShortcutLaunchAction(kind: .askEva, prompt: prompt)
            )
            return .result()
        } catch {
            throw LifeBoardShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : "LifeBoard could not open assistant chat right now."
            )
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct StartFocusSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus Session"
    static let description = IntentDescription("Starts a 25-minute focus session using your current focus lane.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        do {
            try PendingShortcutLaunchActionStore.shared.submit(
                PendingShortcutLaunchAction(kind: .startFocus)
            )
            return .result()
        } catch {
            throw LifeBoardShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : "LifeBoard could not start focus right now."
            )
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct QuickJournalCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Journal Moment"
    static let description = IntentDescription("Adds a private text moment to today’s Journal.")
    static let openAppWhenRun = false

    @Parameter(title: "Moment", requestValueDialog: IntentDialog("What would you like to keep?"))
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw $text.needsValueError(IntentDialog("What would you like to keep?")) }
        let repositories = try await LifeBoardShortcutDependencyResolver.lifeOSRepositories()
        let repository = repositories.phaseII
        let dayDate = Calendar.current.startOfDay(for: Date())
        let previous = try await repository.fetchJournalDay(containing: dayDate)
        var day = previous ?? LifeBoardJournalDayValue(day: dayDate)
        let blockID = UUID()
        day.blocks.append(.init(id: blockID, dayID: day.id, kind: .text, text: content, ordinal: day.blocks.count))
        day.updatedAt = Date()
        let saved = day
        _ = try await applyShortcutMutation(
            preview: .init(destination: .track, summary: "Add a Journal moment", changes: ["Journal · Today", content], origin: .appIntent),
            apply: { try await repository.saveJournalDay(saved); return "Added to today’s Journal." },
            undo: {
                if let previous { try await repository.saveJournalDay(previous) }
                else { try await repository.deleteJournalDay(id: saved.id) }
            }
        )
        return .result(dialog: "Added to today’s Journal.")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct LogBodyMetricIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Body Metric"
    static let description = IntentDescription("Logs a body metric with an explicit value and unit.")
    static let openAppWhenRun = false

    @Parameter(title: "Metric", description: "bodyMass, bodyFatPercentage, waistCircumference, or restingHeartRate")
    var metric: String
    @Parameter(title: "Value") var value: Double
    @Parameter(title: "Unit", description: "kilograms, pounds, percent, centimeters, inches, or beatsPerMinute")
    var unit: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let kind = BodyMetricKind(rawValue: metric),
              let displayUnit = WellnessDisplayUnit(rawValue: unit) else {
            throw LifeBoardShortcutRuntimeError.handoffFailed("Choose a compatible metric and unit.")
        }
        let sample = try BodyMetricSample(kind: kind, value: value, unit: displayUnit, source: .manual)
        if case .requiresConfirmation(let message) = WellnessOutlierPolicy().review(
            kind: kind,
            normalizedValue: sample.normalizedValue
        ) {
            throw LifeBoardShortcutRuntimeError.handoffFailed(message)
        }
        let repositories = try await LifeBoardShortcutDependencyResolver.lifeOSRepositories()
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
    static let title: LocalizedStringResource = "Start Fasting Timer"
    static let description = IntentDescription("Starts a neutral timer using only the duration you choose.")
    static let openAppWhenRun = false

    @Parameter(title: "Target hours") var targetHours: Double?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let targetHours, targetHours <= 0 { throw LifeBoardShortcutRuntimeError.handoffFailed("Target hours must be greater than zero.") }
        let repositories = try await LifeBoardShortcutDependencyResolver.lifeOSRepositories()
        let store = FastingTimerStore(repository: LifeBoardFastingRepositoryAdapter(repository: repositories.phaseII))
        let session = try await store.start(targetDuration: targetHours.map { $0 * 3_600 })
        return .result(dialog: IntentDialog(stringLiteral: "Fasting timer started at \(session.startedAt.formatted(date: .omitted, time: .shortened))."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct EndFastingTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "End Fasting Timer"
    static let description = IntentDescription("Ends the active timer without judgment or coaching.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repositories = try await LifeBoardShortcutDependencyResolver.lifeOSRepositories()
        let store = FastingTimerStore(repository: LifeBoardFastingRepositoryAdapter(repository: repositories.phaseII))
        let session = try await store.finish()
        return .result(dialog: IntentDialog(stringLiteral: "Timer ended after \(Int(session.elapsed() / 60)) minutes."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct CreateCountdownIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Countdown"
    static let description = IntentDescription("Keeps a meaningful date in LifeBoard.")
    static let openAppWhenRun = false

    @Parameter(title: "Title") var momentTitle: String
    @Parameter(title: "Date") var date: Date

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repositories = try await LifeBoardShortcutDependencyResolver.lifeOSRepositories()
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

@available(iOS 16.0, macOS 13.0, *)
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
                "Ask assistant in \(.applicationName)",
                "Ask \(.applicationName)",
                "Open assistant in \(.applicationName)"
            ],
            shortTitle: "Ask Assistant",
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
            systemImageName: "timer"
        )

        AppShortcut(intent: QuickJournalCaptureIntent(), phrases: ["Capture a journal moment in \(.applicationName)"], shortTitle: "Journal Moment", systemImageName: "book.closed")
        AppShortcut(intent: LogBodyMetricIntent(), phrases: ["Log a body metric in \(.applicationName)"], shortTitle: "Log Metric", systemImageName: "chart.line.uptrend.xyaxis")
        AppShortcut(intent: StartFastingTimerIntent(), phrases: ["Start fasting timer in \(.applicationName)"], shortTitle: "Start Timer", systemImageName: "timer")
        AppShortcut(intent: EndFastingTimerIntent(), phrases: ["End fasting timer in \(.applicationName)"], shortTitle: "End Timer", systemImageName: "stop.circle")
        AppShortcut(intent: CreateCountdownIntent(), phrases: ["Create countdown in \(.applicationName)"], shortTitle: "Countdown", systemImageName: "calendar.badge.clock")
    }

    static var shortcutTileColor: ShortcutTileColor {
        .orange
    }
}

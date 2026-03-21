import AppIntents
import Foundation

enum TaskerShortcutDeepLink {
    static func chatURL(prompt: String?) -> URL {
        var components = URLComponents()
        components.scheme = "tasker"
        components.host = "chat"

        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedPrompt, trimmedPrompt.isEmpty == false {
            components.queryItems = [URLQueryItem(name: "prompt", value: trimmedPrompt)]
        }

        guard let url = components.url else {
            return URL(string: "tasker://chat")!
        }
        return url
    }

    static func focusURL() -> URL {
        URL(string: "tasker://focus")!
    }

    static func chatPrompt(from url: URL) -> String? {
        guard url.host?.lowercased() == "chat" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let prompt = components?.queryItems?.first(where: { $0.name == "prompt" })?.value
        let trimmedPrompt = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt?.isEmpty == false ? trimmedPrompt : nil
    }
}

enum TaskerShortcutRuntimeError: LocalizedError {
    case unavailable
    case bootstrapFailed(String)
    case handoffFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Tasker shortcuts are unavailable until the app finishes loading."
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

    func createTask(title: String, details: String?) async throws -> TaskDefinition {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            throw NSError(
                domain: "InboxTaskCaptureService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Task title cannot be empty."]
            )
        }

        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let inboxProject = try await ensureInboxProject()
        let request = CreateTaskDefinitionRequest(
            title: trimmedTitle,
            details: trimmedDetails?.isEmpty == false ? trimmedDetails : nil,
            projectID: inboxProject.id,
            projectName: inboxProject.name,
            lifeAreaID: inboxProject.lifeAreaID,
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

private struct HeadlessTaskerShortcutRuntime {
    let projectRepository: ProjectRepositoryProtocol
    let createTaskDefinitionUseCase: CreateTaskDefinitionUseCase
}

enum TaskerShortcutDependencyResolver {
    static func inboxTaskCaptureService() throws -> InboxTaskCaptureService {
        let runtime = try headlessRuntime()
        return InboxTaskCaptureService(
            projectRepository: runtime.projectRepository,
            createTaskDefinitionUseCase: runtime.createTaskDefinitionUseCase
        )
    }

    private static func headlessRuntime() throws -> HeadlessTaskerShortcutRuntime {
        let bootstrapService = TaskerPersistentStoreBootstrapService()
        let bootstrapResult = bootstrapService.bootstrapV3PersistentContainer()

        guard case .ready(let container) = bootstrapResult.state else {
            if case .failed(let message) = bootstrapResult.state {
                throw TaskerShortcutRuntimeError.bootstrapFailed(message)
            }
            throw TaskerShortcutRuntimeError.unavailable
        }

        TaskerPersistentRuntimeInitializer().initialize(container: container)

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

        return HeadlessTaskerShortcutRuntime(
            projectRepository: projectRepository,
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(
                repository: taskDefinitionRepository,
                taskTagLinkRepository: taskTagLinkRepository,
                taskDependencyRepository: taskDependencyRepository
            )
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Creates a new Inbox task without opening the app.")
    static var openAppWhenRun: Bool = false

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

        let service = try TaskerShortcutDependencyResolver.inboxTaskCaptureService()
        let task = try await service.createTask(title: trimmedTitle, details: details)

        do {
            try ShortcutMutationSignalStore.shared.submitTaskCreated(taskID: task.id)
        } catch {
            throw TaskerShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : "Tasker created the task but could not refresh the app."
            )
        }

        let confirmation = "Added \(task.title) to Inbox."
        return .result(value: task.title, dialog: IntentDialog(stringLiteral: confirmation))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenEvaChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Eva"
    static var description = IntentDescription("Opens Eva chat with your question prefilled.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question")
    var prompt: String?

    func perform() async throws -> some IntentResult {
        do {
            try PendingShortcutLaunchActionStore.shared.submit(
                PendingShortcutLaunchAction(kind: .askEva, prompt: prompt)
            )
            return .result()
        } catch {
            throw TaskerShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : "Tasker could not open Eva right now."
            )
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct StartFocusSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Starts a 25-minute focus session using your current focus lane.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        do {
            try PendingShortcutLaunchActionStore.shared.submit(
                PendingShortcutLaunchAction(kind: .startFocus)
            )
            return .result()
        } catch {
            throw TaskerShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : "Tasker could not start focus right now."
            )
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct TaskerAppShortcutsProvider: AppShortcutsProvider {
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
            systemImageName: "timer"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .orange
    }
}

import AppIntents
import Foundation

@available(iOS 16.0, macOS 13.0, *)
struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Adds a task to your LifeBoard Inbox.")
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

        // Queued raw, not parsed and committed.
        //
        // This used to run `TaskCaptureParser` through `InboxTaskCaptureService`,
        // which rewrites the title (stripping the date phrase) and assigns a due
        // date. Invoked hands-free there is no opportunity to review that, so a
        // spoken "add task tomorrow 3pm" silently acquired a date the user never
        // saw — and a parser defect meant it was sometimes the wrong one. The
        // capture now lands in the Inbox with the parser's proposal shown as
        // review chips, and only becomes a scheduled task once confirmed.
        let capture = PendingCapture(
            rawText: [trimmedTitle, details?.trimmingCharacters(in: .whitespacesAndNewlines)]
                .compactMap { $0?.isEmpty == false ? $0 : nil }
                .joined(separator: "\n"),
            source: "siri"
        )
        PendingCaptureInbox.append(capture)

        // The dialog states what actually happened. Claiming the task was
        // scheduled would be the same silent-commit problem wearing a nicer
        // sentence.
        let confirmation = String(localized: "Added “\(trimmedTitle)” to Inbox.")
        return .result(value: trimmedTitle, dialog: IntentDialog(stringLiteral: confirmation))
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenEvaChatIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Eva"
    static let description = IntentDescription("Opens a chat with Eva, with your question filled in.")
    static let openAppWhenRun = true

    @Parameter(title: "Question")
    var prompt: String?

    func perform() async throws -> some IntentResult {
        do {
            try PendingShortcutLaunchActionStore.shared.submit(
                PendingShortcutLaunchAction(kind: .askEva, prompt: prompt)
            )
            NotificationCenter.default.post(name: .lifeboardPendingShortcutHandoff, object: nil)
            return .result()
        } catch {
            throw ShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : String(localized: "Couldn’t open Eva.")
            )
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct FocusPresetEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Focus Preset")
    static let defaultQuery = FocusPresetEntityQuery()

    let id: String
    let name: String
    let summary: String
    let systemImage: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: summary),
            image: .init(systemName: systemImage)
        )
    }

    init(_ preset: FocusPreset) {
        id = preset.id
        name = preset.name
        summary = preset.summary
        systemImage = preset.systemImage
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct FocusPresetEntityQuery: EntityQuery {
    init() {}

    private func presets() -> [FocusPreset] {
        let stored = WorkspacePreferencesStore.shared.load().focusPresets
        return stored.isEmpty ? FocusPreset.defaults : stored
    }

    func entities(for identifiers: [String]) async throws -> [FocusPresetEntity] {
        presets().filter { identifiers.contains($0.id) }.map(FocusPresetEntity.init)
    }

    func suggestedEntities() async throws -> [FocusPresetEntity] {
        presets().map(FocusPresetEntity.init)
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct StartFocusSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus Session"
    static let description = IntentDescription("Starts a focus session from one of your presets.")
    static let openAppWhenRun = true

    @Parameter(title: "Preset") var preset: FocusPresetEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$preset) focus")
    }

    func perform() async throws -> some IntentResult {
        do {
            try PendingShortcutLaunchActionStore.shared.submit(
                PendingShortcutLaunchAction(kind: .startFocus, presetID: preset?.id)
            )
            NotificationCenter.default.post(name: .lifeboardPendingShortcutHandoff, object: nil)
            return .result()
        } catch {
            throw ShortcutRuntimeError.handoffFailed(
                error.localizedDescription.isEmpty == false
                    ? error.localizedDescription
                    : String(localized: "Couldn’t start focus.")
            )
        }
    }
}

/// Teaches Siri and Spotlight which LifeBoard actions this person actually takes.
///
/// The framework donates automatically when an intent is run *from* Shortcuts or
/// Siri; it cannot know about the same action performed inside the app. Without
/// these calls the suggestion surfaces only ever learn from people who already
/// found the shortcuts — so the feature could never reach anyone else. Zero
/// donations existed repo-wide before this.
///
/// Deliberately narrow: only the loop-relevant actions, not all 21 intents.
/// Donating everything trains the suggestion ranker on noise.
///
/// Every call is fire-and-forget and failure-tolerant. A donation is a hint; it
/// must never delay or fail the action the person actually asked for.
@available(iOS 16.0, macOS 13.0, *)
enum IntentDonations {
    static func taskAdded(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        let intent = AddTaskIntent()
        intent.taskTitle = trimmed
        donate(intent)
    }

    static func focusSessionStarted() {
        donate(StartFocusSessionIntent())
    }

    private static func donate(_ intent: some AppIntent) {
        Task.detached(priority: .background) {
            // Swallowed on purpose: a donation is a hint to Siri, and a failed
            // hint must never surface to someone who just added a task.
            _ = try? await IntentDonationManager.shared.donate(intent: intent)
        }
    }
}

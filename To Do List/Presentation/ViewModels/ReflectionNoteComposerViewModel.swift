import Foundation

@MainActor
public final class ReflectionNoteComposerViewModel: ObservableObject {
    @Published public var noteText: String
    @Published public var prompt: String
    @Published public var mood: Int
    @Published public var energy: Int
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var saveMessage: String?

    public let title: String
    public let kind: ReflectionNoteKind

    private let linkedTaskID: UUID?
    private let linkedProjectID: UUID?
    private let linkedHabitID: UUID?
    private let linkedWeeklyPlanID: UUID?
    private let saveNoteHandler: (ReflectionNote, @escaping (Result<ReflectionNote, Error>) -> Void) -> Void

    public init(
        title: String,
        kind: ReflectionNoteKind,
        linkedTaskID: UUID? = nil,
        linkedProjectID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedWeeklyPlanID: UUID? = nil,
        prompt: String? = nil,
        noteText: String = "",
        mood: Int = 3,
        energy: Int = 3,
        saveNoteHandler: @escaping (ReflectionNote, @escaping (Result<ReflectionNote, Error>) -> Void) -> Void
    ) {
        self.title = title
        self.kind = kind
        self.linkedTaskID = linkedTaskID
        self.linkedProjectID = linkedProjectID
        self.linkedHabitID = linkedHabitID
        self.linkedWeeklyPlanID = linkedWeeklyPlanID
        self.prompt = prompt ?? ""
        self.noteText = noteText
        self.mood = mood
        self.energy = energy
        self.saveNoteHandler = saveNoteHandler
    }

    public var canSave: Bool {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    public func clearError() {
        errorMessage = nil
    }

    public func save(completion: ((ReflectionNote) -> Void)? = nil) {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil
        saveMessage = nil

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = ReflectionNote(
            kind: kind,
            linkedTaskID: linkedTaskID,
            linkedProjectID: linkedProjectID,
            linkedHabitID: linkedHabitID,
            linkedWeeklyPlanID: linkedWeeklyPlanID,
            energy: energy,
            mood: mood,
            prompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
            noteText: trimmedNote
        )

        saveNoteHandler(note) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let savedNote):
                    self.saveMessage = WeeklyCopy.reflectionSaveSuccess
                    completion?(savedNote)
                }
            }
        }
    }
}

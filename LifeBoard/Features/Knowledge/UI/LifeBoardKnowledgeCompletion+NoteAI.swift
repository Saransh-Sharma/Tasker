import Foundation
import LifeBoardDomain

// MARK: - EVA proposal and attachment contracts

public enum NoteAIAction: String, Codable, CaseIterable, Sendable {
    case summarize
    case cleanUp
    case continueWriting
    case extractTasks
    case suggestTags
    case suggestLinks
}

public struct NoteAIProposal: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var baseContentVersion: Int
    public var action: NoteAIAction
    public var explanation: String
    public var preview: String
    public var mutations: [NoteMutation]

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        baseContentVersion: Int,
        action: NoteAIAction,
        explanation: String,
        preview: String,
        mutations: [NoteMutation]
    ) {
        self.id = id
        self.noteID = noteID
        self.baseContentVersion = baseContentVersion
        self.action = action
        self.explanation = explanation
        self.preview = preview
        self.mutations = mutations
    }

    public func isStale(for note: KnowledgeNoteValue) -> Bool {
        note.id != noteID || (note.contentVersion ?? 1) != baseContentVersion
    }
}

public protocol NoteAIProposalService: Sendable {
    func propose(
        action: NoteAIAction,
        note: KnowledgeNoteValue,
        selectedText: String?
    ) async throws -> NoteAIProposal
}

public struct ModelsNoteAIProposalService: NoteAIProposalService {
    public enum ProposalError: LocalizedError {
        case unavailable

        public var errorDescription: String? {
            String(localized: "Couldn’t get a suggestion. Your note is unchanged.")
        }
    }

    public init() {}

    public func propose(
        action: NoteAIAction,
        note: KnowledgeNoteValue,
        selectedText: String?
    ) async throws -> NoteAIProposal {
        let source = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? selectedText!
            : note.plainText
        let output = try await NoteAITextProviderRegistry.shared.generate(action: action, source: source)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.isEmpty == false else { throw ProposalError.unavailable }
        var after = note
        switch action {
        case .summarize:
            after.blocks.insert(
                .init(noteID: note.id, kind: .callout, text: output, ordinal: 0),
                at: 0
            )
        case .cleanUp:
            var block = note.blocks.first ?? .init(noteID: note.id)
            block.kind = .paragraph
            block.text = output
            block.richTextData = nil
            after.blocks = [block]
        case .continueWriting:
            after.blocks.append(.init(noteID: note.id, kind: .paragraph, text: output, ordinal: note.blocks.count))
        case .extractTasks, .suggestTags, .suggestLinks:
            break
        }
        for index in after.blocks.indices { after.blocks[index].ordinal = index }
        after.updatedAt = Date()
        after.contentVersion = max(1, note.contentVersion ?? 1) + 1
        let mutations: [NoteMutation] = after == note ? [] : [.replaceNote(before: note, after: after)]
        return .init(
            noteID: note.id,
            baseContentVersion: note.contentVersion ?? 1,
            action: action,
            explanation: selectedText == nil ? String(localized: "Based on this note only.") : String(localized: "Based on your selection only."),
            preview: output,
            mutations: mutations
        )
    }
}

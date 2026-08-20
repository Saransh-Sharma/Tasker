public protocol NoteAITextProviding: Sendable {
    func generate(action: NoteAIAction, source: String) async throws -> String
}

public actor NoteAITextProviderRegistry {
    public static let shared = NoteAITextProviderRegistry()

    private var provider: (any NoteAITextProviding)?

    public func register(_ provider: any NoteAITextProviding) {
        self.provider = provider
    }

    public func generate(action: NoteAIAction, source: String) async throws -> String {
        guard let provider else { throw ModelsNoteAIProposalService.ProposalError.unavailable }
        return try await provider.generate(action: action, source: source)
    }
}

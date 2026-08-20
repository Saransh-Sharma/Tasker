import Foundation

extension ReflectionNoteRepositoryProtocol {
    func fetchNotesAsync(query: ReflectionNoteQuery) async throws -> [ReflectionNote] {
        try await withCheckedThrowingContinuation { continuation in
            fetchNotes(query: query) { continuation.resume(with: $0) }
        }
    }

    func saveNoteAsync(_ note: ReflectionNote) async throws -> ReflectionNote {
        try await withCheckedThrowingContinuation { continuation in
            saveNote(note) { continuation.resume(with: $0) }
        }
    }
}

import Foundation
import LifeBoardDomain

/// Experiments live in the reflection-note store. This is the whole API the
/// Insights root and the weekly review need: list, start (creating the
/// habit), undo (deleting the habit and the note), and record a verdict.
@MainActor
final class InsightExperimentStore {
    struct Dependencies {
        var notes: (any ReflectionNoteRepositoryProtocol)?
        /// Creates the habit for a template and returns its id.
        var createHabit: (HabitTemplate) async throws -> UUID = { _ in throw CocoaError(.featureUnsupported) }
        /// Removes a habit created by an experiment.
        var deleteHabit: (UUID) async throws -> Void = { _ in }
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func experiments() async -> [InsightExperiment] {
        guard let notes = dependencies.notes else { return [] }
        let fetched: [ReflectionNote] = (try? await withCheckedThrowingContinuation { continuation in
            notes.fetchNotes(query: ReflectionNoteQuery(kinds: [InsightExperiment.noteKind])) { continuation.resume(with: $0) }
        }) ?? []
        return fetched.compactMap(InsightExperiment.experiment(from:)).sorted { $0.startedAt > $1.startedAt }
    }

    func open() async -> [InsightExperiment] {
        await experiments().filter { $0.verdict == nil }
    }

    /// Starts an experiment: the habit is created first, then the note that
    /// remembers it, so an Undo has something concrete to remove.
    func start(hypothesis: String, correlationID: String, template: HabitTemplate) async throws -> InsightExperiment {
        guard let notes = dependencies.notes else { throw CocoaError(.featureUnsupported) }
        let habitID = try await dependencies.createHabit(template)
        let experiment = InsightExperiment(
            hypothesis: hypothesis,
            sourceCorrelationID: correlationID,
            action: .habit(templateID: template.id, habitID: habitID)
        )
        let note = try experiment.note()
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ReflectionNote, Error>) in
            notes.saveNote(note) { continuation.resume(with: $0) }
        }
        return experiment
    }

    /// Undo: the habit goes, the note goes.
    func cancel(_ experiment: InsightExperiment) async throws {
        guard let notes = dependencies.notes else { return }
        if let habitID = experiment.habitID {
            try await dependencies.deleteHabit(habitID)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notes.deleteNote(id: experiment.id) { continuation.resume(with: $0) }
        }
    }

    func record(_ verdict: InsightExperiment.Verdict, for experiment: InsightExperiment) async throws {
        try await write(verdict: verdict, for: experiment)
    }

    /// Undo for "Did it help?": the experiment goes back to waiting.
    func clearVerdict(for experiment: InsightExperiment) async throws {
        try await write(verdict: nil, for: experiment)
    }

    private func write(verdict: InsightExperiment.Verdict?, for experiment: InsightExperiment) async throws {
        guard let notes = dependencies.notes else { throw CocoaError(.featureUnsupported) }
        var updated = experiment
        updated.verdict = verdict
        let note = try updated.note(existing: ReflectionNote(id: experiment.id, kind: InsightExperiment.noteKind, noteText: "", createdAt: experiment.startedAt))
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ReflectionNote, Error>) in
            notes.saveNote(note) { continuation.resume(with: $0) }
        }
    }
}

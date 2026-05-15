import Foundation

enum TaskDetailContainerMode: Equatable {
    case sheet
    case inspector
}

typealias TaskDetailUpdateHandler = (UUID, UpdateTaskDefinitionRequest, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
typealias TaskDetailCompletionHandler = (UUID, Bool, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
typealias TaskDetailDeleteHandler = (UUID, TaskDeleteScope, @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) -> Void
typealias TaskDetailRescheduleHandler = (UUID, Date?, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
typealias TaskDetailMetadataHandler = (UUID, @escaping @MainActor @Sendable (Result<TaskDetailMetadataPayload, Error>) -> Void) -> Void
typealias TaskDetailRelationshipMetadataHandler = (UUID, @escaping @MainActor @Sendable (Result<TaskDetailRelationshipMetadataPayload, Error>) -> Void) -> Void
typealias TaskDetailChildrenHandler = (UUID, @escaping @MainActor @Sendable (Result<[TaskDefinition], Error>) -> Void) -> Void
typealias TaskDetailCreateTaskHandler = (CreateTaskDefinitionRequest, @escaping @MainActor @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
typealias TaskDetailCreateTagHandler = (String, @escaping @MainActor @Sendable (Result<TagDefinition, Error>) -> Void) -> Void
typealias TaskDetailCreateProjectHandler = (String, @escaping @MainActor @Sendable (Result<Project, Error>) -> Void) -> Void
typealias TaskDetailSaveReflectionNoteHandler = (ReflectionNote, @escaping @MainActor @Sendable (Result<ReflectionNote, Error>) -> Void) -> Void
typealias TaskDetailFitHintHandler = (TaskDefinition, @escaping @MainActor @Sendable (LifeBoardTaskFitHintResult) -> Void) -> Void

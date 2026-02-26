//
//  HomeAIActionCoordinator.swift
//  Tasker
//
//  Coordinates Home-specific AI propose/confirm/apply/undo actions.
//

import Foundation

final class HomeAIActionCoordinator {
    typealias ContextServiceFactory = () -> LLMContextProjectionService?

    private let pipeline: AssistantActionPipelineUseCase
    private let contextServiceFactory: ContextServiceFactory

    /// Initializes a new instance.
    init(
        pipeline: AssistantActionPipelineUseCase,
        contextServiceFactory: @escaping ContextServiceFactory = { LLMContextRepositoryProvider.makeService() }
    ) {
        self.pipeline = pipeline
        self.contextServiceFactory = contextServiceFactory
    }

    /// Proposes an AI command envelope that marks the provided task as complete.
    func proposeCompletion(
        task: TaskDefinition,
        threadID: String,
        rationale: @escaping (String?) -> String,
        completion: @escaping (Result<(run: AssistantActionRunDefinition, contextJSON: String?), Error>) -> Void
    ) {
        let proposeWithContext: (String?) -> Void = { [weak self] contextJSON in
            guard let self else { return }

            let envelope = AssistantCommandEnvelope(
                schemaVersion: 2,
                commands: [.completeTask(taskID: task.id)],
                rationaleText: rationale(contextJSON)
            )

            self.pipeline.propose(threadID: threadID, envelope: envelope) { result in
                switch result {
                case .success(let run):
                    completion(.success((run, contextJSON)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        if let contextService = contextServiceFactory() {
            contextService.buildTodayJSON { contextJSON in
                proposeWithContext(contextJSON)
            }
        } else {
            proposeWithContext(nil)
        }
    }

    /// Confirms and applies a previously proposed run.
    func confirmAndApply(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        pipeline.confirm(runID: runID) { [weak self] confirmResult in
            guard let self else { return }
            switch confirmResult {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                self.pipeline.applyConfirmedRun(id: runID, completion: completion)
            }
        }
    }

    /// Rejects a pending run.
    func reject(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        pipeline.reject(runID: runID, completion: completion)
    }

    /// Undoes an applied run.
    func undo(runID: UUID, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        pipeline.undoAppliedRun(id: runID, completion: completion)
    }
}

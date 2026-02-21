import Foundation

enum LLMAssistantPipelineProvider {
    private static var pipelineStorage: AssistantActionPipelineUseCase?

    static var pipeline: AssistantActionPipelineUseCase? {
        pipelineStorage
    }

    /// Executes configure.
    static func configure(pipeline: AssistantActionPipelineUseCase?) {
        self.pipelineStorage = pipeline
    }
}

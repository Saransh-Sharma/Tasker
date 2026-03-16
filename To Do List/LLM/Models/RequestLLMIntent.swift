import AppIntents
import MLXLMCommon
import SwiftData
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct RequestLLMIntent: AppIntent {
    static var title: LocalizedStringResource = "new chat"
    static var description: LocalizedStringResource = "start a new chat"
    
    @Parameter(title: "Continuous Chat", default: true)
    var continuous: Bool
    
    @Parameter(title: "message", requestValueDialog: IntentDialog("chat"))
    var prompt: String

    static var parameterSummary: some ParameterSummary {
        Summary("new chat with \(\.$prompt)") {
            // shortcuts additional parameters
            \.$continuous
        }
    }
    
    var maxCharacters: Int? {
        if continuous {
            return 300
        }
        
        return nil
    }
    
    var systemPrompt: String {
        if continuous {
            return "\n you never reply with more than FOUR sentences even if asked to."
        }
        
        return ""
    }
    
    /// Executes perform.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let llm = LLMRuntimeCoordinator.shared.evaluator
        let appManager = AppManager()
        let thread = Thread()
        
        if prompt.isEmpty {
            throw $prompt.needsValueError(IntentDialog(stringLiteral: "chat"))
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var immediateResponse: String?
        switch SlashCommandCatalog.parse(trimmedPrompt) {
        case .invocation(var invocation):
            switch invocation.id {
            case .clear:
                immediateResponse = "The /clear command is only available in the in-app chat."
            case .project:
                let query = invocation.projectQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard query.isEmpty == false else {
                    immediateResponse = "/project needs a project name."
                    break
                }
                invocation.projectName = query
                if let service = SlashCommandExecutionService.makeDefault() {
                    do {
                        let result = try await service.execute(invocation: invocation)
                        immediateResponse = formatShortcutCommandResult(result)
                    } catch {
                        immediateResponse = (error as? LocalizedError)?.errorDescription ?? "Unable to run command right now."
                    }
                } else {
                    immediateResponse = "Task context is unavailable right now."
                }
            default:
                if let service = SlashCommandExecutionService.makeDefault() {
                    do {
                        let result = try await service.execute(invocation: invocation)
                        immediateResponse = formatShortcutCommandResult(result)
                    } catch {
                        immediateResponse = (error as? LocalizedError)?.errorDescription ?? "Unable to run command right now."
                    }
                } else {
                    immediateResponse = "Task context is unavailable right now."
                }
            }
        case .missingRequiredArgument(let commandID, _):
            immediateResponse = "\(commandID.canonicalCommand) needs a project name."
        case .unknown(let command):
            immediateResponse = "Unknown command \(command). Try /today, /tomorrow, /week, /month, /project, or /clear."
        case .notCommand:
            break
        }

        if var immediateResponse {
            let maxCharacters = maxCharacters ?? .max
            if immediateResponse.count > maxCharacters {
                immediateResponse = String(immediateResponse.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces) + "..."
            }
            if continuous {
                throw $prompt.needsValueError(IntentDialog(stringLiteral: immediateResponse))
            }
            return .result(value: immediateResponse, dialog: "\(immediateResponse)")
        }

        let route = AIChatModeRouter.route(for: .addTaskSuggestion, appManager: appManager)
        if let modelName = route.selectedModelName,
           let model = ModelConfiguration.getModelByName(modelName) {
            let ready = await LLMRuntimeCoordinator.shared.ensureReady(modelName: modelName)
            guard ready.ready else {
                let error = ready.failureMessage ?? "The active local model could not be prepared right now."
                return .result(value: error, dialog: "\(error)")
            }
            let runtimeModel = ModelConfiguration.getModelByName(ready.resolvedModelName) ?? model
            let resolvedBudget = LLMChatBudgets.active.resolved(for: runtimeModel)

            let contextResult = await LLMChatPlanningContextBuilder.build(
                timeoutMs: 800,
                service: LLMContextRepositoryProvider.makeService(
                    maxTasksPerSlice: LLMChatBudgets.active.maxProjectionTasksPerSlice,
                    compactTaskPayload: V2FeatureFlags.llmChatContextStrategy == .bounded
                ),
                query: prompt,
                budgets: LLMChatBudgets.active,
                model: runtimeModel,
                contextCharBudgetOverride: LLMTokenBudgetEstimator.estimatedCharacterBudget(
                    for: resolvedBudget.maxContextTokens
                )
            )
            let composedSystemPrompt = LLMSystemPromptComposer.compose(
                basePrompt: appManager.systemPrompt,
                model: runtimeModel,
                additionalInstruction: systemPrompt,
                personalMemory: LLMPersonalMemoryDefaultsStore.promptBlock(for: runtimeModel),
                taskContext: contextResult.payload
            )
            
            let message = Message(role: .user, content: prompt, thread: thread)
            thread.messages.append(message)
            var output = await llm.generate(
                modelName: ready.resolvedModelName,
                thread: thread,
                systemPrompt: composedSystemPrompt,
                profile: .chat
            )
            
            let maxCharacters = maxCharacters ?? .max
            
            if output.count > maxCharacters {
                output = String(output.prefix(maxCharacters)).trimmingCharacters(in: .whitespaces) + "..."
            }
            
            let responseMessage = Message(role: .assistant, content: output, thread: thread)
            thread.messages.append(responseMessage)

            if continuous {
                throw $prompt.needsValueError(IntentDialog(stringLiteral: output))
            }
            
            return .result(value: output, dialog: "\(output)")
        }
        else {
            let error = "no model is currently selected. open the app and select a model first."
            return .result(value: error, dialog: "\(error)")
        }
    }

    private func formatShortcutCommandResult(_ result: SlashCommandExecutionResult) -> String {
        var lines: [String] = [result.commandLabel, result.summary]
        for section in result.sections {
            lines.append("\(section.title) (\(section.totalCount))")
            for task in section.tasks {
                var line = "• \(task.title)"
                if let dueLabel = task.dueLabel, dueLabel.isEmpty == false {
                    line += " • \(dueLabel)"
                }
                line += " • \(task.projectName)"
                lines.append(line)
            }
            if section.totalCount > section.tasks.count {
                lines.append("• +\(section.totalCount - section.tasks.count) more")
            }
        }
        return lines.joined(separator: "\n")
    }

    static var openAppWhenRun: Bool = false
}

struct NewChatShortcut: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RequestLLMIntent(),
            phrases: [
                "Start a new \(.applicationName) chat",
                "Start a \(.applicationName) chat",
                "Chat with \(.applicationName)",
                "Ask \(.applicationName) a question"
            ],
            shortTitle: "new chat",
            systemImageName: "bubble"
        )
    }
}

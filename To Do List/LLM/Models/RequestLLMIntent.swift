import AppIntents
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
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let llm = LLMEvaluator()
        let appManager = AppManager()
        let thread = Thread()
        
        if prompt.isEmpty {
            throw $prompt.needsValueError(IntentDialog(stringLiteral: "chat"))
        }

        if let modelName = appManager.currentModelName {
            _ = try? await llm.load(modelName: modelName)
            
            let message = Message(role: .user, content: prompt, thread: thread)
            thread.messages.append(message)
            var output = await llm.generate(modelName: modelName, thread: thread, systemPrompt: appManager.systemPrompt + systemPrompt)
            
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

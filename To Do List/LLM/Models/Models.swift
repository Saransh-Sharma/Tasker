//
//  Models.swift
//
//

import Foundation
import MLXLMCommon

public extension ModelConfiguration {
    enum ModelType {
        case regular, reasoning
    }

    var modelType: ModelType {
        switch self {
        case .deepseek_r1_distill_qwen_1_5b_4bit: .reasoning
        case .deepseek_r1_distill_qwen_1_5b_8bit: .reasoning
        case .qwen_3_4b_4bit: .reasoning
        case .qwen_3_8b_4bit: .reasoning
        default: .regular
        }
    }
}

public extension ModelConfiguration {
    static let llama_3_2_1b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit"
    )

    static let llama_3_2_3b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit"
    )

    static let deepseek_r1_distill_qwen_1_5b_4bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"
    )

    static let deepseek_r1_distill_qwen_1_5b_8bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit"
    )

    static let qwen_3_4b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-4B-4bit"
    )

    static let qwen_3_8b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-8B-4bit"
    )

    static var availableModels: [ModelConfiguration] = [
        llama_3_2_1b_4bit,
        llama_3_2_3b_4bit,
        deepseek_r1_distill_qwen_1_5b_4bit,
        deepseek_r1_distill_qwen_1_5b_8bit,
        qwen_3_4b_4bit,
        qwen_3_8b_4bit,
    ]

    static var defaultModel: ModelConfiguration {
        llama_3_2_1b_4bit
    }

    static func getModelByName(_ name: String) -> ModelConfiguration? {
        if let model = availableModels.first(where: { $0.name == name }) {
            return model
        } else {
            return nil
        }
    }

    internal func getPromptHistory(thread: Thread, systemPrompt: String) -> [[String: String]] {
        var history: [[String: String]] = []

        // system prompt
        history.append([
            "role": "system",
            "content": systemPrompt,
        ])

        // messages
        for message in thread.sortedMessages {
            let role = message.role.rawValue
            history.append([
                "role": role,
                "content": formatForTokenizer(message.content), // remove reasoning part
            ])
        }

        return history
    }

    // TODO: Remove this function when Jinja gets updated
    func formatForTokenizer(_ message: String) -> String {
        if modelType == .reasoning {
            let pattern = "<think>.*?(</think>|$)"
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
                let range = NSRange(location: 0, length: message.utf16.count)
                let formattedMessage = regex.stringByReplacingMatches(in: message, options: [], range: range, withTemplate: "")
                return " " + formattedMessage
            } catch {
                return " " + message
            }
        }
        return message
    }

    /// Returns the model's approximate size, in GB.
    var modelSize: Decimal? {
        switch self {
        case .llama_3_2_1b_4bit: return 0.7
        case .llama_3_2_3b_4bit: return 1.8
        case .deepseek_r1_distill_qwen_1_5b_4bit: return 1.0
        case .deepseek_r1_distill_qwen_1_5b_8bit: return 1.9
        case .qwen_3_4b_4bit: return 2.3
        case .qwen_3_8b_4bit: return 4.7
        default: return nil
        }
    }
}

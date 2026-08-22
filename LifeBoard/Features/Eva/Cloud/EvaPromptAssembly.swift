import Foundation
import MLXLMCommon

/// Budget-aware prompt assembly.
///
/// These are additive overloads of the two places that decide how much of a turn
/// survives — the system-prompt composer and the history clipper. Both originals
/// read `ModelConfiguration.tokenBudget`, which is the mechanism that leaked the
/// offline ceiling onto the cloud path. They keep working unchanged; anything
/// that knows which provider it is talking to calls the `budget:` form instead.
///
/// They live here rather than beside the originals because `Models.swift` sits
/// at its size ratchet.
extension LLMSystemPromptComposer {
    static func compose(
        basePrompt: String,
        budget: EvaContextBudget,
        additionalInstruction: String? = nil,
        personalMemory: String? = nil,
        executiveContext: String? = nil,
        slashContext: String? = nil,
        taskContext: String? = nil
    ) -> String {
        var sections: [(content: String, trimPriority: Int)] = []

        func append(_ text: String?, tokens: Int, priority: Int) {
            let trimmed = LLMTokenBudgetEstimator.trimPrefix(
                (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                toTokenBudget: tokens
            )
            guard trimmed.isEmpty == false else { return }
            sections.append((trimmed, priority))
        }

        // Trim priority mirrors the original: lower is sacrificed first, and the
        // persona and the task context are the last two standing.
        append(basePrompt, tokens: budget.systemPromptTokens, priority: 4)
        let reservedTail = budget.personalMemoryTokens
            + budget.executiveContextTokens
            + budget.slashContextTokens
            + budget.taskContextTokens
        let alreadyUsed = sections.reduce(0) { $0 + LLMTokenBudgetEstimator.estimatedTokenCount(for: $1.content) }
        append(
            additionalInstruction,
            tokens: max(0, budget.inputTokens - alreadyUsed - reservedTail),
            priority: 0
        )
        append(personalMemory, tokens: budget.personalMemoryTokens, priority: 1)
        append(executiveContext, tokens: budget.executiveContextTokens, priority: 2)
        append(slashContext, tokens: budget.slashContextTokens, priority: 3)
        append(taskContext, tokens: budget.taskContextTokens, priority: 5)

        trimOverflow(&sections, maxTokens: budget.inputTokens)
        return sections.map(\.content).joined(separator: "\n\n")
    }

    private static func trimOverflow(
        _ sections: inout [(content: String, trimPriority: Int)],
        maxTokens: Int
    ) {
        guard maxTokens > 0 else {
            sections.removeAll()
            return
        }
        func total() -> Int {
            sections.reduce(0) { $0 + LLMTokenBudgetEstimator.estimatedTokenCount(for: $1.content) }
                + max(0, sections.count - 1)
        }
        for index in sections.indices.sorted(by: { sections[$0].trimPriority < sections[$1].trimPriority }) {
            let overflow = total() - maxTokens
            guard overflow > 0 else { break }
            let current = LLMTokenBudgetEstimator.estimatedTokenCount(for: sections[index].content)
            sections[index].content = LLMTokenBudgetEstimator
                .trimPrefix(sections[index].content, toTokenBudget: max(0, current - overflow))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        sections.removeAll { $0.content.isEmpty }
    }
}

extension ModelConfiguration {
    /// History clipped against a resolved budget.
    ///
    /// Offline delegates to the existing per-model path so its behavior is
    /// literally unchanged. Cloud clips by tokens instead of by a message count,
    /// because "8 messages" is a meaningless unit against a 16 K window — it
    /// throws away a long thread that would have fit comfortably.
    func getChatMessages(
        thread: Thread,
        systemPrompt: String,
        budget: EvaContextBudget
    ) -> [Chat.Message] {
        guard budget.isCloud else {
            return getChatMessages(thread: thread, systemPrompt: systemPrompt)
        }
        var messages: [Chat.Message] = [.system(systemPrompt)]
        let history = EvaCloudHistoryClipper.clip(
            thread.sortedMessages,
            maxMessages: budget.historyMessageLimit,
            maxTokens: max(0, budget.inputTokens - LLMTokenBudgetEstimator.estimatedTokenCount(for: systemPrompt))
        )
        messages.append(contentsOf: history)
        return messages
    }
}

enum EvaCloudHistoryClipper {
    /// Keeps the newest turns that fit, oldest-first in the result.
    ///
    /// Unlike the offline path this does not drop assistant turns that fail the
    /// local quality gate: that gate detects small-model failure modes (repetition
    /// loops, generic intros, leaked reasoning) which a frontier model does not
    /// produce, and applying it to cloud history silently erases real answers
    /// from the thread the model is shown.
    static func clip(
        _ messages: [Message],
        maxMessages: Int,
        maxTokens: Int
    ) -> [Chat.Message] {
        guard maxMessages > 0, maxTokens > 0 else { return [] }
        var kept: [Chat.Message] = []
        var usedTokens = 0
        for message in messages.reversed() {
            guard kept.count < maxMessages else { break }
            // Server-side policy replaces system messages. Do not spend the
            // history budget on content the request encoder will drop.
            guard message.role != .system else { continue }
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard content.isEmpty == false else { continue }
            let tokens = LLMTokenBudgetEstimator.estimatedTokenCount(for: content)
            guard usedTokens + tokens <= maxTokens else { break }
            usedTokens += tokens
            switch message.role {
            case .assistant: kept.append(.assistant(content))
            case .user: kept.append(.user(content))
            case .system: kept.append(.system(content))
            }
        }
        return kept.reversed()
    }
}

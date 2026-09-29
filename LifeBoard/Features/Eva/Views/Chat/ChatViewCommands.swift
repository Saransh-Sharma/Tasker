import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    @MainActor
    func executeSlashCommand(_ invocation: SlashCommandInvocation) async {
        guard !Task.isCancelled else { return }
        guard let thread = ensureCurrentThread() else { return }

        let commandLabel = invocation.commandLabel
        projectLookupTask?.cancel()
        prompt = ""
        slashDraft = nil
        isProjectFieldFocused = false
        appManager.playHaptic()
        sendMessage(Message(role: .user, content: commandLabel, thread: thread))

        guard let service = SlashCommandExecutionService.makeDefault() else {
            sendMessage(Message(role: .assistant, content: String(localized: "Couldn’t load your tasks. Try again."), thread: thread))
            return
        }

        var resolvedInvocation = invocation
        if invocation.id.requiresArgument {
            let query = invocation.resolvedArgument
                ?? invocation.argumentQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            if let resolvedName = await service.resolveArgumentName(for: invocation.id, matching: query) {
                guard !Task.isCancelled else { return }
                resolvedInvocation.resolvedArgument = resolvedName
            }
        }

        do {
            let result = try await service.execute(invocation: resolvedInvocation)
            guard !Task.isCancelled else { return }
            let cardPayload = AssistantCardPayload(
                cardType: .commandResult,
                threadID: thread.id.uuidString,
                status: .applied,
                message: result.summary,
                commandResult: result
            )
            let cardMessage = AssistantCardCodec.encode(cardPayload)

            sendMessage(Message(role: .assistant, content: cardMessage, thread: thread))
            recordRecentCommand(resolvedInvocation.id)
            contextCoordinator.upsert(commandResult: result, threadID: thread.id)

            logWarning(
                event: "chat_slash_command_sent",
                message: "Executed slash command",
                fields: [
                    "command_id": resolvedInvocation.id.rawValue,
                    "result_count": String(result.totalTaskCount)
                ]
            )
        } catch {
            guard !Task.isCancelled else { return }
            let failureMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Couldn’t run command.")
            let recoveryQuery: String?
            if let slashError = error as? SlashCommandExecutionError {
                switch slashError {
                case .entityNotFound(_, let query), .ambiguousArgument(_, let query, _):
                    recoveryQuery = query
                case .missingArgument:
                    recoveryQuery = resolvedInvocation.argumentQuery
                case .repositoriesUnavailable:
                    recoveryQuery = nil
                }
            } else {
                recoveryQuery = nil
            }

            sendMessage(Message(role: .assistant, content: failureMessage, thread: thread))
            if resolvedInvocation.id.requiresArgument, let recoveryQuery {
                slashDraft = SlashCommandInvocation(
                    id: resolvedInvocation.id,
                    argumentQuery: recoveryQuery,
                    resolvedArgument: nil
                )
                commandFeedback = failureMessage
                slashPickerQuery = resolvedInvocation.id == .area ? "area" : "project"
                showSlashPicker = true
                isProjectFieldFocused = true
            }
            logWarning(
                event: "chat_slash_command_validation_error",
                message: "Slash command execution failed",
                fields: [
                    "command_id": resolvedInvocation.id.rawValue,
                    "error": failureMessage
                ]
            )
        }
    }

    @MainActor
    func startSlashCommandTask(_ invocation: SlashCommandInvocation) {
        slashCommandTask?.cancel()
        slashCommandTask = _Concurrency.Task { @MainActor in
            defer {
                slashCommandTask = nil
            }
            await executeSlashCommand(invocation)
        }
    }

}

// MARK: - Standard chat generation

import Combine
import MarkdownUI
import LifeBoardDomain
import MLXLMCommon
import SwiftData
import SwiftUI
import os

extension ChatView {
    func runLocalCapture(message: String, threadID: UUID, runID: UUID) async {
        await MainActor.run {
            prompt = ""
            appManager.playHaptic()
            updatePendingResponsePhase(.buildingContext, for: runID)
            _ = sendMessage(role: .user, content: message, threadID: threadID)
        }

        let result: EvaCaptureLaneResult
        switch await EvaCaptureCommandParser.parse(message) {
        case .review(let review):
            result = .review(message: review)
        case .commands(let commands):
            guard let lane = EvaCaptureLaneFactory.lane else {
                result = .review(message: String(localized: "Couldn’t save yet. Try again."))
                break
            }
            do {
                result = try await lane.apply(threadID: threadID.uuidString, commands: commands)
            } catch {
                result = .review(message: String(localized: "Couldn’t save that. \(error.localizedDescription)"))
            }
        }
        guard Task.isCancelled == false, generationRunID == runID else { return }
        await MainActor.run {
            let payload: AssistantCardPayload
            switch result {
            case .review(let message):
                payload = AssistantCardPayload(
                    cardType: .status,
                    threadID: threadID.uuidString,
                    status: .pending,
                    message: message
                )
            case .applied(let run, let references, let message):
                payload = AssistantCardPayload(
                    cardType: .undo,
                    runID: run.id,
                    threadID: threadID.uuidString,
                    status: .undoAvailable,
                    diffLines: references.map { .init(text: "Captured \($0.title)", isDestructive: false) },
                    expiresAt: (run.appliedAt ?? Date()).addingTimeInterval(30 * 60),
                    message: message,
                    captureReferences: references
                )
            }
            _ = sendMessage(
                role: .assistant,
                content: AssistantCardCodec.encode(payload),
                threadID: threadID,
                sourceModelName: "LifeBoard Safe Capture"
            )
            clearEvaSubmittedDraft(runID: runID, reason: "capture_card_persisted")
            if generationRunID == runID {
                generationTask = nil
                generationRunID = nil
                if generatingThreadID == threadID { generatingThreadID = nil }
                pendingResponsePhase = .idle
                llm.isThinking = false
            }
        }
    }

    func runLocalNavigation(message: String, threadID: UUID, runID: UUID) async {
        await MainActor.run {
            prompt = ""
            appManager.playHaptic()
            updatePendingResponsePhase(.buildingContext, for: runID)
            _ = sendMessage(role: .user, content: message, threadID: threadID)
        }
        let navigation = await EvaLocalNavigationResolver.resolve(message)
        guard Task.isCancelled == false, generationRunID == runID else { return }
        await MainActor.run {
            let payload = AssistantCardPayload(
                cardType: .navigation,
                threadID: threadID.uuidString,
                status: .applied,
                message: navigation.message,
                navigation: navigation
            )
            _ = sendMessage(
                role: .assistant,
                content: AssistantCardCodec.encode(payload),
                threadID: threadID,
                sourceModelName: "LifeBoard Local Navigation"
            )
            clearEvaSubmittedDraft(runID: runID, reason: "navigation_card_persisted")
            if generationRunID == runID {
                generationTask = nil
                generationRunID = nil
                if generatingThreadID == threadID { generatingThreadID = nil }
                pendingResponsePhase = .idle
                llm.isThinking = false
            }
        }
    }
}

// MARK: - EVA plan generation

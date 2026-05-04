import XCTest
import MLXLMCommon
@testable import LifeBoard

@MainActor
final class ChatTranscriptSnapshotTests: XCTestCase {
    func testSnapshotPrecomputesRenderModelsAndUndoTimerFlag() {
        let thread = LifeBoard.Thread()
        thread.messages = [
            Message(role: .user, content: "Plan my inbox", thread: thread),
            Message(role: .assistant, content: "<think>Sort urgent work</think>\n- First\n- Second", thread: thread),
            Message(
                role: .assistant,
                content: AssistantCardCodec.encode(
                    AssistantCardPayload(
                        cardType: .undo,
                        runID: UUID(),
                        threadID: thread.id.uuidString,
                        status: .undoAvailable,
                        expiresAt: Date().addingTimeInterval(600),
                        message: "Undo ready"
                    )
                ),
                thread: thread
            )
        ]

        let snapshot = ChatTranscriptSnapshot(thread: thread)

        XCTAssertEqual(snapshot.title, "Plan my inbox")
        XCTAssertEqual(snapshot.recentUserMessageFragments, ["plan my inbox"])
        XCTAssertTrue(snapshot.containsUndoCard)
        XCTAssertEqual(snapshot.messages.count, 3)
        XCTAssertNil(snapshot.messages[1].thinkingText)
        XCTAssertEqual(snapshot.messages[1].answerText, "- First\n- Second")
        XCTAssertNotNil(snapshot.messages[2].cardPayload)
    }

    func testLiveOutputStateBuildsAssistantRenderModel() {
        let responseID = UUID()
        let liveOutput = ChatLiveOutputState(
            responseID: responseID,
            threadID: UUID(),
            text: "<think>Reason</think>\nAnswer",
            sourceModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
            runtimePhase: .answering,
            isRunning: true,
            pendingPhase: .generating,
            pendingStatusText: "Preparing a focused response..."
        )

        XCTAssertTrue(liveOutput.shouldRender)
        XCTAssertEqual(liveOutput.renderModel.id, responseID)
        XCTAssertEqual(liveOutput.renderModel.role, .assistant)
        XCTAssertNil(liveOutput.renderModel.thinkingText)
        XCTAssertEqual(liveOutput.renderModel.answerText, "Answer")
    }

    func testLiveOutputStateKeepsStableRenderIdentityAcrossTextChanges() {
        let responseID = UUID()
        let first = ChatLiveOutputState(
            responseID: responseID,
            threadID: UUID(),
            text: "A",
            sourceModelName: nil,
            runtimePhase: .answering,
            isRunning: true,
            pendingPhase: .generating,
            pendingStatusText: nil
        )
        let second = ChatLiveOutputState(
            responseID: responseID,
            threadID: first.threadID,
            text: "A longer answer",
            sourceModelName: nil,
            runtimePhase: .answering,
            isRunning: true,
            pendingPhase: .generating,
            pendingStatusText: nil
        )

        XCTAssertEqual(first.renderModel.id, responseID)
        XCTAssertEqual(second.renderModel.id, responseID)
    }

    func testLiveOutputStateRendersDuringPendingPhaseEvenWithoutText() {
        let liveOutput = ChatLiveOutputState(
            responseID: UUID(),
            threadID: UUID(),
            text: "",
            sourceModelName: nil,
            runtimePhase: .idle,
            isRunning: false,
            pendingPhase: .buildingContext,
            pendingStatusText: "Looking at your tasks and goals..."
        )

        XCTAssertTrue(liveOutput.shouldRender)
        XCTAssertEqual(liveOutput.pendingPhase, .buildingContext)
        XCTAssertEqual(liveOutput.pendingStatusText, "Looking at your tasks and goals...")
        XCTAssertNil(liveOutput.renderModel.answerText)
    }

    func testLiveOutputStateDoesNotRenderWhenIdleAndEmpty() {
        let liveOutput = ChatLiveOutputState(
            responseID: nil,
            threadID: UUID(),
            text: "",
            sourceModelName: nil,
            runtimePhase: .idle,
            isRunning: false,
            pendingPhase: .idle,
            pendingStatusText: nil
        )

        XCTAssertFalse(liveOutput.shouldRender)
    }

    func testPendingStatusTextUsesActivationSpecificCopy() {
        XCTAssertEqual(
            ChatPendingResponseStatusText.status(
                for: .buildingContext,
                isActivationPresentation: true
            ),
            "Looking at your tasks and goals..."
        )
        XCTAssertEqual(
            ChatPendingResponseStatusText.status(
                for: .preparingModel,
                isActivationPresentation: false
            ),
            "Getting the model ready..."
        )
        XCTAssertNil(
            ChatPendingResponseStatusText.status(
                for: .idle,
                isActivationPresentation: true
            )
        )
    }

    func testSnapshotUsesPersistedSourceModelNameForAssistantSanitization() {
        let thread = LifeBoard.Thread()
        thread.messages = [
            Message(
                role: .assistant,
                content: "<｜Assistant｜>Focus on urgent work.<｜end▁of▁sentence｜>",
                thread: thread,
                sourceModelName: ModelConfiguration.qwen_3_0_6b_4bit.name
            )
        ]

        let snapshot = ChatTranscriptSnapshot(thread: thread)

        XCTAssertEqual(snapshot.messages.first?.displayContent, "Focus on urgent work.")
    }

    func testSnapshotSplitsPlainTextThinkingForReasoningDistilledModel() {
        let thread = LifeBoard.Thread()
        thread.messages = [
            Message(
                role: .assistant,
                content: """
                Thinking Process:
                1. Analyze the day.
                2. Pick the most important task.
                """,
                thread: thread,
                sourceModelName: ModelConfiguration.qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit.name
            )
        ]

        let snapshot = ChatTranscriptSnapshot(thread: thread)

        XCTAssertNil(snapshot.messages.first?.thinkingText)
        XCTAssertNil(snapshot.messages.first?.answerText)
    }

    func testRenderModelHashChangesWhenSourceModelChanges() {
        let first = ChatMessageRenderModel(
            role: .assistant,
            originalContent: "<think>Reason</think>\nAnswer",
            displayContent: "<think>Reason</think>\nAnswer",
            sourceModelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        )
        let second = ChatMessageRenderModel(
            role: .assistant,
            originalContent: "<think>Reason</think>\nAnswer",
            displayContent: "<think>Reason</think>\nAnswer",
            sourceModelName: ModelConfiguration.qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit.name
        )

        XCTAssertNotEqual(first.markdownSourceHash, second.markdownSourceHash)
    }
}

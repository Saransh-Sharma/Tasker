import XCTest
import MLXLMCommon
@testable import To_Do_List

@MainActor
final class ChatTranscriptSnapshotTests: XCTestCase {
    func testSnapshotPrecomputesRenderModelsAndUndoTimerFlag() {
        let thread = To_Do_List.Thread()
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
        let liveOutput = ChatLiveOutputState(
            threadID: UUID(),
            text: "<think>Reason</think>\nAnswer",
            sourceModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
            runtimePhase: .answering,
            isRunning: true,
            isPreparingResponse: false
        )

        XCTAssertTrue(liveOutput.shouldRender)
        XCTAssertEqual(liveOutput.renderModel.role, .assistant)
        XCTAssertNil(liveOutput.renderModel.thinkingText)
        XCTAssertEqual(liveOutput.renderModel.answerText, "Answer")
    }

    func testSnapshotUsesPersistedSourceModelNameForAssistantSanitization() {
        let thread = To_Do_List.Thread()
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
        let thread = To_Do_List.Thread()
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

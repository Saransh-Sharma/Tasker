import XCTest
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
        XCTAssertEqual(snapshot.messages[1].thinkingText, "Sort urgent work")
        XCTAssertEqual(snapshot.messages[1].answerText, "- First\n- Second")
        XCTAssertNotNil(snapshot.messages[2].cardPayload)
    }

    func testLiveOutputStateBuildsAssistantRenderModel() {
        let liveOutput = ChatLiveOutputState(
            threadID: UUID(),
            text: "<think>Reason</think>\nAnswer",
            runtimePhase: .answering,
            isRunning: true,
            isPreparingResponse: false
        )

        XCTAssertTrue(liveOutput.shouldRender)
        XCTAssertEqual(liveOutput.renderModel.role, .assistant)
        XCTAssertEqual(liveOutput.renderModel.thinkingText, "Reason")
        XCTAssertEqual(liveOutput.renderModel.answerText, "Answer")
    }
}

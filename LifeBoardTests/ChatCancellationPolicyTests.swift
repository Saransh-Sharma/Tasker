import XCTest
@testable import LifeBoard

final class ChatCancellationPolicyTests: XCTestCase {
    func testThreadChangePolicyPreservesFirstGeneratedThreadAttach() {
        let firstThreadID = UUID()

        let decision = ChatGenerationCancellationPolicy.decision(
            oldThreadID: nil,
            newThreadID: firstThreadID,
            generatingThreadID: firstThreadID,
            hasActiveGeneration: true
        )

        XCTAssertEqual(decision, .preserveFirstGeneratedThreadAttach)
        XCTAssertFalse(ChatGenerationCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: nil,
            newThreadID: firstThreadID,
            generatingThreadID: firstThreadID,
            hasActiveGeneration: true
        ))
    }

    func testThreadChangePolicyCancelsRealSwitchDuringGeneration() {
        let originalThreadID = UUID()
        let switchedThreadID = UUID()

        XCTAssertTrue(ChatGenerationCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: originalThreadID,
            newThreadID: switchedThreadID,
            generatingThreadID: originalThreadID,
            hasActiveGeneration: true
        ))
    }

    func testThreadChangePolicyCancelsClearThreadDuringGeneration() {
        let originalThreadID = UUID()

        XCTAssertTrue(ChatGenerationCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: originalThreadID,
            newThreadID: nil,
            generatingThreadID: originalThreadID,
            hasActiveGeneration: true
        ))
    }

    func testThreadChangePolicyIgnoresThreadSwitchWhenNoGenerationIsActive() {
        XCTAssertFalse(ChatGenerationCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: UUID(),
            newThreadID: UUID(),
            generatingThreadID: nil,
            hasActiveGeneration: false
        ))
    }

    func testDisappearCancelsGenerationSlashAndEvaluatorAndRestoresDraft() {
        let runID = UUID()
        let threadID = UUID()
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: .chatViewDisappear,
            snapshot: snapshot(
                runID: runID,
                generatingThreadID: threadID,
                currentThreadID: UUID(),
                hasGenerationTask: true,
                hasSlashCommandTask: true,
                evaluatorIsRunning: true,
                evaluatorRuntimePhaseRequiresCancellation: true
            )
        )

        XCTAssertEqual(decision.reason, .chatViewDisappear)
        XCTAssertTrue(decision.shouldLog)
        XCTAssertTrue(decision.shouldCancelEvaluator)
        XCTAssertTrue(decision.shouldRestoreSubmittedDraft)
        XCTAssertEqual(decision.cancelledRunID, runID)
        XCTAssertEqual(decision.logThreadID, threadID)
        XCTAssertTrue(decision.hadGenerationTask)
        XCTAssertTrue(decision.hadSlashCommandTask)
    }

    func testStopButtonRestoresSubmittedDraft() {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: .stopButton,
            snapshot: snapshot(hasGenerationTask: true)
        )

        XCTAssertTrue(decision.shouldRestoreSubmittedDraft)
    }

    func testThreadChangedDoesNotRestoreSubmittedDraft() {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: .threadChanged,
            snapshot: snapshot(hasGenerationTask: true)
        )

        XCTAssertFalse(decision.shouldRestoreSubmittedDraft)
    }

    func testSlashCommandTaskCancellationLogsWithoutCancellingEvaluator() {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: .supersededByNewGeneration,
            snapshot: snapshot(hasSlashCommandTask: true)
        )

        XCTAssertTrue(decision.shouldLog)
        XCTAssertFalse(decision.shouldCancelEvaluator)
        XCTAssertFalse(decision.shouldRestoreSubmittedDraft)
        XCTAssertTrue(decision.hadSlashCommandTask)
    }

    func testEvaluatorRuntimePhaseCancellationLogsAndCancelsEvaluator() {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: .clearThread,
            snapshot: snapshot(evaluatorRuntimePhaseRequiresCancellation: true)
        )

        XCTAssertTrue(decision.shouldLog)
        XCTAssertTrue(decision.shouldCancelEvaluator)
    }

    func testNoActiveWorkDecisionDoesNotLogOrCancelEvaluator() {
        let decision = ChatGenerationCancellationPolicy.generationDecision(
            reason: .startNewChat,
            snapshot: snapshot()
        )

        XCTAssertFalse(decision.shouldLog)
        XCTAssertFalse(decision.shouldCancelEvaluator)
        XCTAssertFalse(decision.shouldRestoreSubmittedDraft)
    }

    private func snapshot(
        runID: UUID? = nil,
        generatingThreadID: UUID? = nil,
        currentThreadID: UUID? = nil,
        hasGenerationTask: Bool = false,
        hasSlashCommandTask: Bool = false,
        evaluatorIsRunning: Bool = false,
        evaluatorRuntimePhaseRequiresCancellation: Bool = false
    ) -> ChatGenerationCancellationSnapshot {
        ChatGenerationCancellationSnapshot(
            generationRunID: runID,
            generatingThreadID: generatingThreadID,
            currentThreadID: currentThreadID,
            hasGenerationTask: hasGenerationTask,
            hasSlashCommandTask: hasSlashCommandTask,
            evaluatorIsRunning: evaluatorIsRunning,
            evaluatorRuntimePhaseRequiresCancellation: evaluatorRuntimePhaseRequiresCancellation
        )
    }
}

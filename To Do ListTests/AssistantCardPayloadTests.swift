import XCTest
@testable import To_Do_List

final class AssistantCardPayloadTests: XCTestCase {
    func testCardCodecRoundTripPreservesCriticalFields() {
        let payload = AssistantCardPayload(
            cardType: .proposal,
            runID: UUID(),
            threadID: UUID().uuidString,
            status: .pending,
            rationale: "Triage overdue tasks",
            diffLines: [AssistantDiffLine(text: "Reschedule 'Tax docs'", isDestructive: false)],
            destructiveCount: 1,
            affectedTaskCount: 4,
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            message: "Ready to apply"
        )

        let encoded = AssistantCardCodec.encode(payload)
        let decoded = AssistantCardCodec.decode(from: encoded)

        XCTAssertTrue(AssistantCardCodec.isCard(encoded))
        XCTAssertEqual(decoded, payload)
    }

    func testStatusMatrixIncludesRollbackStates() {
        let statuses: Set<AssistantCardStatus> = [
            .pending,
            .applied,
            .rejected,
            .rollbackFailed,
            .rollbackComplete
        ]

        XCTAssertTrue(statuses.contains(.rollbackFailed))
        XCTAssertTrue(statuses.contains(.rollbackComplete))
    }

    func testCardCodecRoundTripPreservesCommandResultPayload() {
        var task = TaskDefinition(
            title: "Prepare release notes",
            dueDate: Date(timeIntervalSince1970: 1_700_000_100),
            isComplete: false
        )
        task.projectName = "Inbox"

        let payload = AssistantCardPayload(
            cardType: .commandResult,
            threadID: UUID().uuidString,
            status: .applied,
            message: "1 task needs attention.",
            commandResult: SlashCommandExecutionResult(
                commandID: .today,
                commandLabel: "Today",
                summary: "1 task needs attention.",
                sections: [
                    SlashCommandTaskSection(
                        id: "today",
                        title: "Due Today",
                        tasks: [
                            SlashCommandTaskItem(
                                taskID: task.id,
                                title: task.title,
                                projectName: "Inbox",
                                dueDateISO: task.dueDate?.ISO8601Format(),
                                dueLabel: "Today",
                                taskSnapshot: task
                            )
                        ],
                        totalCount: 1
                    )
                ],
                totalTaskCount: 1,
                generatedAtISO: Date(timeIntervalSince1970: 1_700_000_000).ISO8601Format()
            )
        )

        let encoded = AssistantCardCodec.encode(payload)
        let decoded = AssistantCardCodec.decode(from: encoded)

        XCTAssertTrue(AssistantCardCodec.isCard(encoded))
        XCTAssertEqual(decoded, payload)
    }
}

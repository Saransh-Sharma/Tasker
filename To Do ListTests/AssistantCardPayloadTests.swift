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
}

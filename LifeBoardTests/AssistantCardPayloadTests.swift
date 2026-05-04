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
            .rollbackComplete,
            .undone
        ]

        XCTAssertTrue(statuses.contains(.rollbackFailed))
        XCTAssertTrue(statuses.contains(.rollbackComplete))
        XCTAssertTrue(statuses.contains(.undone))
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

    func testCardCodecRoundTripPreservesDayOverviewPayload() {
        let task = TaskDefinition(
            id: UUID(),
            projectID: ProjectConstants.inboxProjectID,
            projectName: "Inbox",
            title: "Ship EVA fix",
            priority: .high,
            dueDate: Date(timeIntervalSince1970: 1_700_000_100),
            scheduledStartAt: nil,
            scheduledEndAt: nil,
            isComplete: false,
            estimatedDuration: 1_800,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let payload = AssistantCardPayload(
            cardType: .dayOverview,
            threadID: UUID().uuidString,
            status: .applied,
            rationale: "### Today’s brief\n- 1 open task is queued for today.",
            dayOverview: EvaDayOverviewPayload(
                prompt: "How is my day looking today?",
                summaryMarkdown: "### Today’s brief\n- 1 open task is queued for today.",
                contextReceipt: EvaContextReceipt(sources: []),
                isPartialContext: false,
                sections: [
                    EvaDayOverviewSection(
                        kind: .todayTasks,
                        title: "Today’s tasks",
                        subtitle: "1 open for today",
                        taskCards: [
                            EvaDayTaskCard(
                                taskID: task.id,
                                taskSnapshot: task,
                                title: task.title,
                                projectName: task.projectName ?? "Inbox",
                                dueLabel: "10:15 AM",
                                priorityLabel: "High",
                                durationLabel: "30 min",
                                scheduledStartAt: nil,
                                scheduledEndAt: nil,
                                dueDate: task.dueDate,
                                isOverdue: false,
                                statusChips: [EvaDayStatusChip(text: "Today", tone: "accent")],
                                actions: [.done, .tomorrow, .open]
                            )
                        ],
                        habitCards: [
                            EvaDayHabitCard(
                                habitID: UUID(),
                                title: "Morning review",
                                kind: .positive,
                                trackingMode: .dailyCheckIn,
                                lifeAreaName: "Health",
                                projectName: nil,
                                iconSymbolName: "flame.fill",
                                accentHex: "#4E9A2F",
                                cadence: .daily(),
                                cadenceLabel: "Every day",
                                dueAt: Date(timeIntervalSince1970: 1_700_000_200),
                                dueLabel: "10:16 AM",
                                currentStreak: 4,
                                bestStreak: 7,
                                riskState: .stable,
                                last14Days: [
                                    HabitDayMark(
                                        date: Date(timeIntervalSince1970: 1_700_000_000),
                                        state: .success
                                    )
                                ],
                                statusChips: [EvaDayStatusChip(text: "Due today", tone: "accent")],
                                actions: [.done, .skip, .open]
                            )
                        ],
                        message: nil
                    )
                ],
                generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )

        let encoded = AssistantCardCodec.encode(payload)
        let decoded = AssistantCardCodec.decode(from: encoded)

        XCTAssertTrue(AssistantCardCodec.isCard(encoded))
        XCTAssertEqual(decoded, payload)
    }
}

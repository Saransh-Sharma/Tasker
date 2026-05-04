import XCTest
@testable import To_Do_List

final class TaskAgendaPresentationModelBuilderTests: XCTestCase {
    func testBuildCreatesSharedAgendaPresentationForOpenTask() {
        let referenceNow = Date(timeIntervalSince1970: 1_743_043_200)
        let dueToday = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: referenceNow)
        let task = TaskDefinition(
            title: "Prepare launch notes",
            details: "Review the talking points and send the final deck.",
            priority: .high,
            type: .evening,
            dueDate: dueToday,
            estimatedDuration: 30 * 60
        )

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: true,
            isInOverdueSection: false,
            tagNameByID: [:],
            now: referenceNow
        )

        XCTAssertEqual(presentation.title, "Prepare launch notes")
        XCTAssertEqual(presentation.leadingSystemImage, "moon.stars.fill")
        XCTAssertEqual(presentation.primaryActionTitle, "Done")
        XCTAssertEqual(presentation.secondaryActionTitle, "Move")
        XCTAssertEqual(presentation.primaryBadge.text, "Today")
        XCTAssertEqual(presentation.primaryBadge.tone, AgendaRowStateTone.accent)
        XCTAssertTrue(presentation.metadataLine?.contains("Evening") == true)
        XCTAssertEqual(
            presentation.secondaryLine,
            "Review the talking points and send the final deck."
        )
    }

    func testBuildCollapsesCompletedTaskToResolvedPresentation() {
        let task = TaskDefinition(
            title: "Archive receipts",
            priority: .low,
            isComplete: true,
            dateCompleted: Date()
        )

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: false,
            isInOverdueSection: false,
            tagNameByID: [:],
            now: Date(timeIntervalSince1970: 1_743_043_200)
        )

        XCTAssertEqual(presentation.primaryBadge.text, "Done")
        XCTAssertEqual(presentation.primaryBadge.tone, AgendaRowStateTone.success)
        XCTAssertEqual(presentation.primaryActionTitle, "Reopen")
        XCTAssertNil(presentation.secondaryActionTitle)
    }

    func testBuildKeepsOverdueMetadataCompactInsidePressureSections() {
        let referenceNow = Date(timeIntervalSince1970: 1_743_043_200)
        let tagID = UUID()
        let task = TaskDefinition(
            projectName: "Growth",
            title: "Repair onboarding copy",
            priority: .high,
            type: .morning,
            dueDate: Calendar.current.date(byAdding: .day, value: -3, to: referenceNow),
            tagIDs: [tagID],
            repeatPattern: .daily
        )

        let presentation = TaskAgendaPresentationModelBuilder.build(
            task: task,
            showTypeBadge: true,
            isInOverdueSection: true,
            tagNameByID: [tagID: "UX"],
            now: referenceNow
        )

        XCTAssertEqual(presentation.primaryBadge.text, "Overdue")
        XCTAssertEqual(presentation.primaryBadge.tone, AgendaRowStateTone.danger)
        XCTAssertTrue(presentation.metadataLine?.contains("Growth") == true)
        XCTAssertTrue(presentation.metadataLine?.contains("Daily") == true)
        XCTAssertTrue(presentation.metadataLine?.contains("UX") == true)
    }
}

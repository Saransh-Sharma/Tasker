import XCTest
@testable import LifeBoard

final class XPCalculationEngineWeeklyCategoryTests: XCTestCase {
    func testWeeklyCategoriesHaveExpectedBaseXPAndAreNonHabit() {
        XCTAssertEqual(XPCalculationService.baseXP(for: .reflectionCapture), 4)
        XCTAssertEqual(XPCalculationService.baseXP(for: .weeklyPlan), 8)
        XCTAssertEqual(XPCalculationService.baseXP(for: .weeklyReview), 10)
        XCTAssertEqual(XPCalculationService.baseXP(for: .weeklyCarryCleanup), 4)

        XCTAssertFalse(XPCalculationService.isHabitCategory(.reflectionCapture))
        XCTAssertFalse(XPCalculationService.isHabitCategory(.weeklyPlan))
        XCTAssertFalse(XPCalculationService.isHabitCategory(.weeklyReview))
        XCTAssertFalse(XPCalculationService.isHabitCategory(.weeklyCarryCleanup))
    }

    func testWeeklyIdempotencyKeysScopeByWeekAndIdentifier() {
        let taskID = UUID()

        XCTAssertEqual(
            XPCalculationService.idempotencyKey(
                category: .weeklyPlan,
                fromDay: "2026-04-06"
            ),
            "weekly_plan:2026-04-06"
        )
        XCTAssertEqual(
            XPCalculationService.idempotencyKey(
                category: .weeklyReview,
                fromDay: "2026-04-06"
            ),
            "weekly_review:2026-04-06"
        )
        XCTAssertEqual(
            XPCalculationService.idempotencyKey(
                category: .weeklyCarryCleanup,
                fromDay: "2026-04-06"
            ),
            "weekly_carry_cleanup:2026-04-06"
        )
        XCTAssertEqual(
            XPCalculationService.idempotencyKey(
                category: .reflectionCapture,
                taskID: taskID,
                periodKey: "2026-04-06"
            ),
            "reflection_capture:\(taskID.uuidString):2026-04-06"
        )
    }
}

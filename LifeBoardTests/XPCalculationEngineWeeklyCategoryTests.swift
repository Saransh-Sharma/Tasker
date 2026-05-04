import XCTest
@testable import LifeBoard

final class XPCalculationEngineWeeklyCategoryTests: XCTestCase {
    func testWeeklyCategoriesHaveExpectedBaseXPAndAreNonHabit() {
        XCTAssertEqual(XPCalculationEngine.baseXP(for: .reflectionCapture), 4)
        XCTAssertEqual(XPCalculationEngine.baseXP(for: .weeklyPlan), 8)
        XCTAssertEqual(XPCalculationEngine.baseXP(for: .weeklyReview), 10)
        XCTAssertEqual(XPCalculationEngine.baseXP(for: .weeklyCarryCleanup), 4)

        XCTAssertFalse(XPCalculationEngine.isHabitCategory(.reflectionCapture))
        XCTAssertFalse(XPCalculationEngine.isHabitCategory(.weeklyPlan))
        XCTAssertFalse(XPCalculationEngine.isHabitCategory(.weeklyReview))
        XCTAssertFalse(XPCalculationEngine.isHabitCategory(.weeklyCarryCleanup))
    }

    func testWeeklyIdempotencyKeysScopeByWeekAndIdentifier() {
        let taskID = UUID()

        XCTAssertEqual(
            XPCalculationEngine.idempotencyKey(
                category: .weeklyPlan,
                fromDay: "2026-04-06"
            ),
            "weekly_plan:2026-04-06"
        )
        XCTAssertEqual(
            XPCalculationEngine.idempotencyKey(
                category: .weeklyReview,
                fromDay: "2026-04-06"
            ),
            "weekly_review:2026-04-06"
        )
        XCTAssertEqual(
            XPCalculationEngine.idempotencyKey(
                category: .weeklyCarryCleanup,
                fromDay: "2026-04-06"
            ),
            "weekly_carry_cleanup:2026-04-06"
        )
        XCTAssertEqual(
            XPCalculationEngine.idempotencyKey(
                category: .reflectionCapture,
                taskID: taskID,
                periodKey: "2026-04-06"
            ),
            "reflection_capture:\(taskID.uuidString):2026-04-06"
        )
    }
}

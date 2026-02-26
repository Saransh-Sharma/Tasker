import XCTest
@testable import To_Do_List

final class OverdueAgeFormatterTests: XCTestCase {

    func testLateLabelReturnsNilForNonOverdueDate() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let dueToday = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 8, minute: 0))!

        XCTAssertNil(OverdueAgeFormatter.lateLabel(dueDate: dueToday, now: now))
    }

    func testLateLabelFormatsDayBoundaries() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let oneDayLate = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let sixDaysLate = Calendar.current.date(byAdding: .day, value: -6, to: now)!

        XCTAssertEqual(OverdueAgeFormatter.lateLabel(dueDate: oneDayLate, now: now), "1d late")
        XCTAssertEqual(OverdueAgeFormatter.lateLabel(dueDate: sixDaysLate, now: now), "6d late")
    }

    func testLateLabelFormatsWeekCompressionUsingFloorDivision() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let sevenDaysLate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysLate = Calendar.current.date(byAdding: .day, value: -14, to: now)!
        let thirteenDaysLate = Calendar.current.date(byAdding: .day, value: -13, to: now)!

        XCTAssertEqual(OverdueAgeFormatter.lateLabel(dueDate: sevenDaysLate, now: now), "1w late")
        XCTAssertEqual(OverdueAgeFormatter.lateLabel(dueDate: thirteenDaysLate, now: now), "1w late")
        XCTAssertEqual(OverdueAgeFormatter.lateLabel(dueDate: fourteenDaysLate, now: now), "2w late")
    }
}

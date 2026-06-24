import XCTest
@testable import LifeBoard

final class TaskCaptureParserTests: XCTestCase {

    /// Deterministic calendar/clock: UTC, Gregorian, fixed "now" on a known Wednesday at 10:00.
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    /// 2026-06-17 10:00:00 UTC.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 10, minute: 0))!
    }

    private func parse(_ raw: String, at reference: Date? = nil) -> ParsedCapture {
        TaskCaptureParser.parse(raw, now: reference ?? now, calendar: calendar)
    }

    private func components(_ date: Date?) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date ?? .distantPast)
    }

    func testTomorrowWithTimeStripsTitleAndResolvesDate() {
        let result = parse("call mom tomorrow 3pm")
        XCTAssertEqual(result.cleanTitle, "call mom")
        XCTAssertFalse(result.isAllDay)
        let c = components(result.dueDate)
        XCTAssertEqual(c.day, 18)
        XCTAssertEqual(c.hour, 15)
        XCTAssertEqual(c.minute, 0)
        XCTAssertNotNil(result.matchedText)
    }

    func testWeekdayIsAllDayAndInFuture() {
        let result = parse("submit report friday")
        XCTAssertEqual(result.cleanTitle, "submit report")
        XCTAssertTrue(result.isAllDay)
        let c = components(result.dueDate)
        XCTAssertEqual(c.weekday, 6) // Friday
        XCTAssertGreaterThan(result.dueDate!, now)
        XCTAssertEqual(c.hour, 0) // start of day
    }

    func testTimeOnlyFutureStaysToday() {
        let result = parse("standup 3pm") // 15:00 is after 10:00 now
        XCTAssertEqual(result.cleanTitle, "standup")
        let c = components(result.dueDate)
        XCTAssertEqual(c.day, 17)
        XCTAssertEqual(c.hour, 15)
        XCTAssertFalse(result.isAllDay)
    }

    func testTimeOnlyPastRollsToTomorrow() {
        let result = parse("standup at 9am") // 09:00 already past 10:00 now
        XCTAssertEqual(result.cleanTitle, "standup")
        let c = components(result.dueDate)
        XCTAssertEqual(c.day, 18)
        XCTAssertEqual(c.hour, 9)
        XCTAssertFalse(result.isAllDay)
    }

    func testTonightResolvesToEvening() {
        let result = parse("pay rent tonight")
        XCTAssertEqual(result.cleanTitle, "pay rent")
        let c = components(result.dueDate)
        XCTAssertEqual(c.day, 17)
        XCTAssertEqual(c.hour, 19)
        XCTAssertFalse(result.isAllDay)
    }

    func testInNDaysIsAllDay() {
        let result = parse("renew passport in 2 days")
        XCTAssertEqual(result.cleanTitle, "renew passport")
        XCTAssertTrue(result.isAllDay)
        XCTAssertEqual(components(result.dueDate).day, 19)
    }

    func testInNMinutesIsPreciseInstant() {
        let result = parse("stretch in 30 minutes")
        XCTAssertEqual(result.cleanTitle, "stretch")
        XCTAssertFalse(result.isAllDay)
        XCTAssertEqual(result.dueDate, calendar.date(byAdding: .minute, value: 30, to: now))
    }

    func testNextWeekIsSevenDaysOut() {
        let result = parse("plan offsite next week")
        XCTAssertEqual(result.cleanTitle, "plan offsite")
        XCTAssertTrue(result.isAllDay)
        XCTAssertEqual(components(result.dueDate).day, 24)
    }

    func testNoDatePhraseLeavesTitleAndNilDate() {
        let result = parse("buy milk")
        XCTAssertEqual(result.cleanTitle, "buy milk")
        XCTAssertNil(result.dueDate)
        XCTAssertFalse(result.isAllDay)
        XCTAssertNil(result.matchedText)
    }

    func testEmojiOnlyDoesNotCrashAndHasNoDate() {
        let result = parse("🎉🎉")
        XCTAssertEqual(result.cleanTitle, "🎉🎉")
        XCTAssertNil(result.dueDate)
    }

    func testEmptyStringIsSafe() {
        let result = parse("   ")
        XCTAssertEqual(result.cleanTitle, "")
        XCTAssertNil(result.dueDate)
    }

    func testWholeTitleIsDatePhraseKeepsOriginalTitle() {
        // Stripping "tomorrow" would empty the title, so we keep the raw text and skip the date.
        let result = parse("tomorrow")
        XCTAssertEqual(result.cleanTitle, "tomorrow")
        XCTAssertNil(result.dueDate)
    }

    func testTwentyFourHourTime() {
        let result = parse("deploy build at 15:30")
        XCTAssertEqual(result.cleanTitle, "deploy build")
        let c = components(result.dueDate)
        XCTAssertEqual(c.hour, 15)
        XCTAssertEqual(c.minute, 30)
        XCTAssertEqual(c.day, 17)
    }
}

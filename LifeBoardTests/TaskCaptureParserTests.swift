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

    /// The bug these time-only tests were catching, stated as its user-visible
    /// consequence: a capture queued from a widget on one day and drained on
    /// another must resolve against the capture's own reference time.
    ///
    /// NSDataDetector has no reference-date parameter, so it claimed bare times
    /// and resolved them against the real clock, silently overriding the
    /// injected `now`. Because captures are committed without review, that put a
    /// wrong due date on the task and the user never saw it happen.
    func testBareTimeResolvesAgainstTheSuppliedReferenceNotTheRealClock() {
        let queuedYesterday = calendar.date(
            from: DateComponents(year: 2026, month: 6, day: 16, hour: 8, minute: 0)
        )!
        let result = parse("standup 3pm", at: queuedYesterday)
        let c = components(result.dueDate)

        XCTAssertEqual(c.year, 2026)
        XCTAssertEqual(c.month, 6)
        XCTAssertEqual(c.day, 16, "Must resolve on the reference day, not today")
        XCTAssertEqual(c.hour, 15)
        XCTAssertEqual(c.minute, 0)
    }

    /// Dates that genuinely carry a day component must still reach the detector.
    func testAbsoluteDatesAreStillDetected() {
        let result = parse("file taxes March 5")
        XCTAssertEqual(result.cleanTitle, "file taxes")
        XCTAssertNotNil(result.dueDate)
        XCTAssertEqual(components(result.dueDate).month, 3)
        XCTAssertEqual(components(result.dueDate).day, 5)
    }

    func testTwentyFourHourTime() {
        let result = parse("deploy build at 15:30")
        XCTAssertEqual(result.cleanTitle, "deploy build")
        let c = components(result.dueDate)
        XCTAssertEqual(c.hour, 15)
        XCTAssertEqual(c.minute, 30)
        XCTAssertEqual(c.day, 17)
    }

    // MARK: - Explicit tokens

    func testTagsProjectAndContextAreExtractedAndStripped() {
        let result = parse("buy milk #groceries #errands +Home @store")
        XCTAssertEqual(result.cleanTitle, "buy milk")
        XCTAssertEqual(result.tags, ["groceries", "errands"])
        XCTAssertEqual(result.projectName, "Home")
        XCTAssertEqual(result.context, "store")
    }

    /// The regression this ordering exists to prevent: a context pattern that
    /// accepted digits would claim "@3pm" before the time matcher saw it.
    func testAtTimeIsNotMistakenForAContext() {
        let result = parse("call mom @3pm")
        XCTAssertNil(result.context)
        XCTAssertEqual(result.cleanTitle, "call mom")
        XCTAssertEqual(components(result.dueDate).hour, 15)
    }

    func testTagsAreDeduplicatedCaseInsensitivelyKeepingFirstSpelling() {
        let result = parse("draft notes #Work #work #WORK")
        XCTAssertEqual(result.tags, ["Work"])
    }

    /// Metadata must survive a capture that carries no date at all. The parser
    /// previously discarded everything and returned the raw title in this case.
    func testMetadataIsExtractedWhenThereIsNoDate() {
        let result = parse("buy milk #groceries")
        XCTAssertNil(result.dueDate)
        XCTAssertEqual(result.cleanTitle, "buy milk")
        XCTAssertEqual(result.tags, ["groceries"])
    }

    func testTokenOnlyInputKeepsOriginalTitle() {
        let result = parse("#groceries")
        XCTAssertEqual(result.cleanTitle, "#groceries")
        XCTAssertTrue(result.tags.isEmpty)
    }

    // MARK: - Duration

    func testDurationRequiresForKeywordAndIsSeparateFromDueDate() {
        let result = parse("write spec for 45 min tomorrow")
        XCTAssertEqual(result.cleanTitle, "write spec")
        XCTAssertEqual(result.duration, 45 * 60)
        XCTAssertEqual(components(result.dueDate).day, 18)
    }

    func testInNMinutesIsADueDateNotADuration() {
        let result = parse("stretch in 45 minutes")
        XCTAssertNil(result.duration)
        XCTAssertNotNil(result.dueDate)
    }

    func testCompoundHourMinuteDuration() {
        XCTAssertEqual(parse("deep work for 1h30").duration, 90 * 60)
        XCTAssertEqual(parse("gym for 2 hours").duration, 2 * 3600)
    }

    /// A bare quantity is part of the title, not an estimate.
    func testBareQuantityIsNotTreatedAsDuration() {
        let result = parse("watch 45 min yoga video")
        XCTAssertNil(result.duration)
        XCTAssertEqual(result.cleanTitle, "watch 45 min yoga video")
    }

    // MARK: - Recurrence

    func testEveryWeekdayNameIsRecurringRatherThanASingleDueDate() {
        let result = parse("standup every monday")
        XCTAssertEqual(result.repeatPattern, .weekly(.monday))
        // The whole point: it must not also become a one-off Monday due date.
        XCTAssertNil(result.dueDate)
        XCTAssertEqual(result.cleanTitle, "standup")
    }

    func testDailyAndWeekdaysAndBiweekly() {
        XCTAssertEqual(parse("vitamins daily").repeatPattern, .daily)
        XCTAssertEqual(parse("standup weekdays").repeatPattern, .weekdays)
        XCTAssertEqual(parse("payroll every 2 weeks").repeatPattern, .biweekly(.allDays))
    }

    /// An interval with no representable pattern is left alone rather than
    /// rounded to something the user did not ask for.
    func testUnrepresentableIntervalIsNotClaimed() {
        let result = parse("review every 3 weeks")
        XCTAssertNil(result.repeatPattern)
    }

    // MARK: - Priority

    func testPriorityFromBangWordAndFromCode() {
        XCTAssertEqual(parse("ship release !high").priority, .high)
        XCTAssertEqual(parse("ship release !urgent").priority, .max)
        XCTAssertEqual(parse("tidy desk p1").priority, .low)
    }

    func testPriorityIsAbsentRatherThanNoneWhenUnspecified() {
        XCTAssertNil(parse("tidy desk").priority)
    }

    func testWordEndingInPFollowedByDigitIsNotAPriority() {
        XCTAssertNil(parse("sleep p").priority)
        XCTAssertEqual(parse("shop p2").priority, .high)
    }

    // MARK: - Combined

    func testEverythingAtOnce() {
        let result = parse("draft proposal for 90 min tomorrow 2pm +Work #writing @desk !high")
        XCTAssertEqual(result.cleanTitle, "draft proposal")
        XCTAssertEqual(result.duration, 90 * 60)
        XCTAssertEqual(result.projectName, "Work")
        XCTAssertEqual(result.tags, ["writing"])
        XCTAssertEqual(result.context, "desk")
        XCTAssertEqual(result.priority, .high)
        let c = components(result.dueDate)
        XCTAssertEqual(c.day, 18)
        XCTAssertEqual(c.hour, 14)
        XCTAssertTrue(result.hasProposals)
    }

    func testPlainTitleHasNoProposals() {
        XCTAssertFalse(parse("buy milk").hasProposals)
    }
}

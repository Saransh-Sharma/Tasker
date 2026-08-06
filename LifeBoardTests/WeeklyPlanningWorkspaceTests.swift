import XCTest
@testable import LifeBoard

/// Coverage for the weekly planning workspace's pure policy layer.
///
/// Everything the surface decides — how full a day is, what the ribbon says out
/// loud, where a backlog lands, and whether a meeting claims time — lives in
/// free functions precisely so it can be pinned here rather than inferred from
/// a screenshot.
final class WeeklyPlanningWorkspaceTests: XCTestCase {

    private let zone = TimeZone(identifier: "UTC")!

    private func day(_ d: Int) -> PlanningDay {
        PlanningDay(year: 2026, month: 8, day: d, timeZoneIdentifier: zone.identifier)
    }

    private func week() -> [PlanningDay] { (2...8).map(day) }

    // MARK: Load

    func testADayWithNoWorkingHoursHasNoLoadFractionAtAll() {
        XCTAssertNil(
            WeeklyWorkspaceLoad.fraction(plannedMinutes: 90, usableMinutes: 0),
            "A day with no working hours is not full and not empty — it cannot be spoken about as a fraction"
        )
        XCTAssertFalse(
            WeeklyWorkspaceLoad.isOverCapacity(plannedMinutes: 90, usableMinutes: 0),
            "A Sunday with work on it is not 'over capacity' against a budget that does not exist"
        )
    }

    func testTheDrawnBarIsCappedButTheTextIsNot() {
        let drawn = WeeklyWorkspaceLoad.drawnFraction(plannedMinutes: 4_000, usableMinutes: 400)
        XCTAssertEqual(drawn, WeeklyWorkspaceLoad.maximumDrawnFraction, accuracy: 0.0001)
        let summary = WeeklyWorkspaceLoad.summary(plannedMinutes: 4_000, usableMinutes: 400, placedCount: 30)
        XCTAssertTrue(summary.contains("more than the day holds"), summary)
    }

    /// Colour is not information. Every state the bar can be in must also exist
    /// as words, or the ribbon is unreadable in greyscale and to VoiceOver.
    func testEveryLoadStateHasWords() {
        let empty = WeeklyWorkspaceLoad.summary(plannedMinutes: 0, usableMinutes: 480, placedCount: 0)
        let partial = WeeklyWorkspaceLoad.summary(plannedMinutes: 120, usableMinutes: 480, placedCount: 3)
        let over = WeeklyWorkspaceLoad.summary(plannedMinutes: 600, usableMinutes: 480, placedCount: 9)
        let noHours = WeeklyWorkspaceLoad.summary(plannedMinutes: 0, usableMinutes: 0, placedCount: 0)
        for value in [empty, partial, over, noHours] {
            XCTAssertFalse(value.isEmpty)
        }
        XCTAssertTrue(partial.contains("still free"), partial)
        XCTAssertTrue(over.contains("more than the day holds"), over)
        XCTAssertEqual(noHours, "No working hours")
        XCTAssertNil(WeeklyWorkspaceLoad.overloadHint(plannedMinutes: 120, usableMinutes: 480))
        XCTAssertNotNil(WeeklyWorkspaceLoad.overloadHint(plannedMinutes: 600, usableMinutes: 480))
    }

    func testDurationPhraseReadsLikeSpeechRatherThanAClock() {
        XCTAssertEqual(WeeklyWorkspaceLoad.durationPhrase(0), "no time")
        XCTAssertEqual(WeeklyWorkspaceLoad.durationPhrase(45), "45m")
        XCTAssertEqual(WeeklyWorkspaceLoad.durationPhrase(120), "2h")
        XCTAssertEqual(WeeklyWorkspaceLoad.durationPhrase(155), "2h 35m")
    }

    // MARK: Horizon

    /// The concrete window follows today, not the week start. On a Friday the
    /// planable days are Friday–Sunday; Monday to Wednesday are over.
    func testTheConcreteWindowFollowsTodayNotTheWeekStart() {
        let friday = day(7)
        let concrete = WeeklyPlanningHorizon.concreteDays(in: week(), today: friday)
        XCTAssertEqual(concrete, [day(7), day(8)], "Only two days of the week remain after Friday")
        XCTAssertTrue(WeeklyPlanningHorizon.softDays(in: week(), today: friday).isEmpty)
    }

    func testEarlyInTheWeekOnlyThreeDaysAreConcreteAndTheRestStaySoft() {
        let sunday = day(2)
        XCTAssertEqual(
            WeeklyPlanningHorizon.concreteDays(in: week(), today: sunday),
            [day(2), day(3), day(4)]
        )
        XCTAssertEqual(
            WeeklyPlanningHorizon.softDays(in: week(), today: sunday),
            [day(5), day(6), day(7), day(8)],
            "The far half of the week collapses rather than inviting you to fill it"
        )
    }

    func testPastDaysAreStillListedButCannotReceiveWork() {
        let wednesday = day(5)
        XCTAssertEqual(
            WeeklyPlanningHorizon.pastDays(in: week(), today: wednesday),
            [day(2), day(3), day(4)],
            "Monday's work is a fact you need to see on Wednesday"
        )
        XCTAssertFalse(WeeklyPlanningHorizon.canReceivePlacement(day(4), today: wednesday))
        XCTAssertTrue(WeeklyPlanningHorizon.canReceivePlacement(wednesday, today: wednesday))
        XCTAssertTrue(WeeklyPlanningHorizon.canReceivePlacement(day(8), today: wednesday))
    }

    // MARK: Spread

    private func candidates(_ count: Int, minutes: Int?) -> [WeeklySpreadCandidate] {
        (0..<count).map { _ in WeeklySpreadCandidate(taskID: UUID(), estimatedMinutes: minutes) }
    }

    func testSpreadFillsTheEarliestDayThatHasRoom() {
        let days = [
            WeeklySpreadDay(day: day(5), remainingMinutes: 60, placedCount: 0),
            WeeklySpreadDay(day: day(6), remainingMinutes: 240, placedCount: 0)
        ]
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(4, minutes: 60), days: days)
        XCTAssertEqual(plan.placements.count, 4)
        XCTAssertEqual(plan.placements.filter { $0.day == day(5) }.count, 1, "Wednesday only had one hour")
        XCTAssertEqual(plan.placements.filter { $0.day == day(6) }.count, 3)
        XCTAssertTrue(plan.unplacedTaskIDs.isEmpty)
    }

    /// The property that separates this from "empty the backlog": a full week
    /// stops accepting work and says so, instead of cramming forty items into
    /// Thursday and lying about capacity on a surface whose subject is capacity.
    func testSpreadStopsAtCapacityRatherThanOverfilling() {
        let days = [WeeklySpreadDay(day: day(5), remainingMinutes: 90, placedCount: 0)]
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(10, minutes: 30), days: days)
        XCTAssertEqual(plan.placements.count, 3, "90 minutes holds exactly three 30-minute tasks")
        XCTAssertEqual(plan.unplacedTaskIDs.count, 7)
        XCTAssertTrue(plan.summary.contains("the week filled up"), plan.summary)
    }

    func testUnestimatedTasksAreCostedRatherThanTreatedAsFree() {
        let days = [WeeklySpreadDay(day: day(5), remainingMinutes: 60, placedCount: 0)]
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(6, minutes: nil), days: days)
        XCTAssertEqual(
            plan.placements.count,
            60 / WeeklyWorkspaceLoad.assumedTaskMinutes,
            "A day that accepts twenty unestimated tasks and still reads empty is the failure the bar exists to prevent"
        )
    }

    /// With no working-hours profile every day reports unknown capacity. Without
    /// a fallback the greedy pass would dump the entire backlog onto day one.
    func testUnknownCapacityFallsBackToACountCapInsteadOfInfinity() {
        let days = [
            WeeklySpreadDay(day: day(5), remainingMinutes: nil, placedCount: 0),
            WeeklySpreadDay(day: day(6), remainingMinutes: nil, placedCount: 0)
        ]
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(12, minutes: nil), days: days)
        XCTAssertEqual(plan.placements.filter { $0.day == day(5) }.count, WeeklyBacklogSpread.fallbackTasksPerDay)
        XCTAssertEqual(plan.placements.filter { $0.day == day(6) }.count, WeeklyBacklogSpread.fallbackTasksPerDay)
        XCTAssertEqual(plan.unplacedTaskIDs.count, 12 - 2 * WeeklyBacklogSpread.fallbackTasksPerDay)
    }

    func testSpreadRespectsWorkAlreadyOnADay() {
        let days = [WeeklySpreadDay(day: day(5), remainingMinutes: 30, placedCount: 4)]
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(3, minutes: 30), days: days)
        XCTAssertEqual(plan.placements.count, 1)
        XCTAssertEqual(plan.unplacedTaskIDs.count, 2)
    }

    func testATaskTooBigForAnyDayIsReportedRatherThanForced() {
        let days = [WeeklySpreadDay(day: day(5), remainingMinutes: 60, placedCount: 0)]
        let plan = WeeklyBacklogSpread.plan(
            candidates: [WeeklySpreadCandidate(taskID: UUID(), estimatedMinutes: 600)],
            days: days
        )
        XCTAssertTrue(plan.placements.isEmpty)
        XCTAssertEqual(plan.unplacedTaskIDs.count, 1)
    }

    func testSpreadWithNoPlaceableDaysPlacesNothing() {
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(5, minutes: 30), days: [])
        XCTAssertTrue(plan.placements.isEmpty)
        XCTAssertEqual(plan.unplacedTaskIDs.count, 5)
    }

    func testSpreadOfAnEmptyBacklogIsANoOp() {
        let days = [WeeklySpreadDay(day: day(5), remainingMinutes: 240, placedCount: 0)]
        let plan = WeeklyBacklogSpread.plan(candidates: [], days: days)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertTrue(plan.unplacedTaskIDs.isEmpty)
    }

    /// The 100+ case from the plan, exercised rather than merely asserted about.
    func testALargeBacklogSpreadsWithoutOverfillingAnyDay() {
        let days = week().map { WeeklySpreadDay(day: $0, remainingMinutes: 300, placedCount: 0) }
        let plan = WeeklyBacklogSpread.plan(candidates: candidates(120, minutes: 30), days: days)
        XCTAssertEqual(plan.placements.count, 7 * 10, "Each day holds ten 30-minute tasks in 300 minutes")
        XCTAssertEqual(plan.unplacedTaskIDs.count, 50)
        for value in week() {
            XCTAssertLessThanOrEqual(plan.placements.filter { $0.day == value }.count, 10)
        }
    }

    // MARK: Meetings

    func testDeclinedAndCancelledMeetingsAreNotDecisionsAtAll() {
        XCTAssertNil(
            WeeklyMeetingPolicy.defaultIntent(participation: .declined, state: .confirmed, isBusy: true),
            "Asking a user to re-confirm something they already declined is forty taps of noise"
        )
        XCTAssertNil(WeeklyMeetingPolicy.defaultIntent(participation: .accepted, state: .cancelled, isBusy: true))
        XCTAssertNil(WeeklyMeetingPolicy.defaultIntent(participation: .accepted, state: .confirmed, isBusy: false))
    }

    func testAcceptedBusyMeetingsDefaultToAttending() {
        XCTAssertEqual(
            WeeklyMeetingPolicy.defaultIntent(participation: .accepted, state: .confirmed, isBusy: true),
            .attending
        )
    }

    /// Reserving the time is the conservative error: a tentative meeting you do
    /// attend costs you nothing if it was budgeted, and wrecks the day if not.
    func testTentativeAndUnansweredBusyMeetingsStayUndecidedAndStillHoldTime() {
        for participation in [CalendarParticipation.tentative, .pending] {
            let intent = WeeklyMeetingPolicy.defaultIntent(
                participation: participation, state: .confirmed, isBusy: true
            )
            XCTAssertEqual(intent, .undecided)
            XCTAssertTrue(WeeklyMeetingPolicy.consumesCapacity(.undecided))
        }
    }

    /// An event with no attendee list is a personal block, not an invitation.
    func testAnEventWithNoAttendeesIsRealTimeAndNotAPendingReply() {
        XCTAssertEqual(
            WeeklyMeetingPolicy.defaultIntent(participation: .unknown, state: .confirmed, isBusy: true),
            .attending
        )
        XCTAssertFalse(WeeklyMeetingPolicy.offersCalendarHandoff(participation: .unknown))
    }

    func testSkippingReleasesTheTimeAndAttendingHoldsIt() {
        XCTAssertFalse(WeeklyMeetingPolicy.consumesCapacity(.skipping))
        XCTAssertTrue(WeeklyMeetingPolicy.consumesCapacity(.attending))
        let claimed = WeeklyMeetingPolicy.claimedMinutes([
            (minutes: 60, intent: .attending),
            (minutes: 30, intent: .undecided),
            (minutes: 90, intent: .skipping),
            (minutes: 45, intent: nil)
        ])
        XCTAssertEqual(claimed, 90, "Only the attending and undecided meetings claim time")
    }

    func testAnOverrideOnAMeetingThatIsNoLongerADecisionIsIgnored() {
        XCTAssertNil(
            WeeklyMeetingPolicy.resolvedIntent(
                participation: .accepted, state: .cancelled, isBusy: true, override: .attending
            ),
            "A stale override must not resurrect a cancelled meeting into the week's capacity"
        )
        XCTAssertEqual(
            WeeklyMeetingPolicy.resolvedIntent(
                participation: .accepted, state: .confirmed, isBusy: true, override: .skipping
            ),
            .skipping
        )
    }

    func testCalendarHandoffIsOfferedOnlyWhereARealReplyIsOutstanding() {
        XCTAssertTrue(WeeklyMeetingPolicy.offersCalendarHandoff(participation: .pending))
        XCTAssertTrue(WeeklyMeetingPolicy.offersCalendarHandoff(participation: .tentative))
        XCTAssertFalse(WeeklyMeetingPolicy.offersCalendarHandoff(participation: .accepted))
        XCTAssertFalse(WeeklyMeetingPolicy.offersCalendarHandoff(participation: .declined))
    }

    // MARK: Occurrence identity

    /// `EKEvent.eventIdentifier` is shared by every occurrence of a recurring
    /// series, so a decision keyed on it alone skips every Monday standup at
    /// once. This is the guard for that.
    func testTwoOccurrencesOfOneSeriesGetDifferentKeys() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 10))!
        let nextMonday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10))!
        let first = CalendarOccurrenceIdentity.key(
            seriesID: "standup", occurrenceStart: monday, calendar: calendar, timeZone: zone
        )
        let second = CalendarOccurrenceIdentity.key(
            seriesID: "standup", occurrenceStart: nextMonday, calendar: calendar, timeZone: zone
        )
        XCTAssertNotEqual(first, second)
    }

    func testTwoOccurrencesOnTheSameDayHaveDifferentKeys() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let morning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 9))!
        let moved = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 16))!
        XCTAssertNotEqual(
            CalendarOccurrenceIdentity.key(seriesID: "s", occurrenceStart: morning, calendar: calendar, timeZone: zone),
            CalendarOccurrenceIdentity.key(seriesID: "s", occurrenceStart: moved, calendar: calendar, timeZone: zone),
            "The occurrence timestamp prevents a decision leaking to a second same-day instance"
        )
    }

    // MARK: Commitment decoding

    /// The three fields added for meeting decisions are optional so commitments
    /// encoded before they existed keep restoring.
    func testACommitmentEncodedBeforeTheDecisionFieldsStillDecodes() throws {
        let legacy = """
        {"id":"a","calendarID":"c","title":"Standup","startAt":0,"endAt":600,"isAllDay":false}
        """
        let decoded = try JSONDecoder().decode(CalendarCommitment.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.title, "Standup")
        XCTAssertNil(decoded.participation)
        XCTAssertNil(decoded.eventState)
        XCTAssertNil(decoded.seriesID)
        XCTAssertTrue(decoded.isBusy, "No availability recorded means the time is claimed")
        XCTAssertEqual(decoded.occurrenceKey(), CalendarOccurrenceIdentity.key(seriesID: "a", occurrenceStart: decoded.startAt))
    }

    func testAFreeCommitmentDoesNotClaimTime() {
        let free = CalendarCommitment(
            id: "a", calendarID: "c", title: "Focus", startAt: Date(), endAt: Date().addingTimeInterval(3_600),
            availability: "1"
        )
        XCTAssertFalse(free.isBusy)
        XCTAssertEqual(free.durationMinutes, 60)
    }

    // MARK: Decision store

    private func makeStore() -> (WeeklyMeetingDecisionStore, UserDefaults, String) {
        let name = "weekly-meeting-decisions-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return (WeeklyMeetingDecisionStore(defaults: defaults, calendar: calendar), defaults, name)
    }

    func testDecisionsRoundTripPerWeekAndPerOccurrence() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let thisWeek = Date(timeIntervalSince1970: 1_785_000_000)
        let nextWeek = thisWeek.addingTimeInterval(7 * 86_400)
        store.setIntent(.skipping, weekStart: thisWeek, occurrenceKey: "standup#2026-8-3")
        XCTAssertEqual(store.intent(weekStart: thisWeek, occurrenceKey: "standup#2026-8-3"), .skipping)
        XCTAssertNil(
            store.intent(weekStart: nextWeek, occurrenceKey: "standup#2026-8-3"),
            "Skipping this week's standup must not skip next week's"
        )
    }

    func testClearingADecisionLetsTheDerivedDefaultTakeOverAgain() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let weekStart = Date(timeIntervalSince1970: 1_785_000_000)
        store.setIntent(.skipping, weekStart: weekStart, occurrenceKey: "k")
        store.setIntent(nil, weekStart: weekStart, occurrenceKey: "k")
        XCTAssertNil(store.intent(weekStart: weekStart, occurrenceKey: "k"))
    }

    func testMeetingReceiptRestoresTheExactPreviousDecision() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let weekStart = Date(timeIntervalSince1970: 1_785_000_000)
        store.setIntent(.attending, weekStart: weekStart, occurrenceKey: "k")
        let receipt = store.setIntent(
            .skipping,
            weekStart: weekStart,
            occurrenceKey: "k",
            titleSnapshot: "Design review"
        )
        XCTAssertEqual(receipt.previousIntent, .attending)
        XCTAssertEqual(receipt.newIntent, .skipping)
        store.restore(receipt)
        XCTAssertEqual(store.intent(weekStart: weekStart, occurrenceKey: "k"), .attending)
    }

    func testAvailabilityNeverReportsNegativeRemainingMinutes() {
        let availability = WeeklyWorkspaceAvailability(
            day: day(4),
            skippedCommitmentIDs: ["meeting"],
            usableMinutes: 300,
            plannedMinutes: 420,
            freeWindows: []
        )
        XCTAssertEqual(availability.remainingMinutes, 0)
        XCTAssertEqual(availability.skippedCommitmentIDs, ["meeting"])
    }

    func testClosingSummaryNamesEveryPersistedKindOfRelease() {
        XCTAssertEqual(
            WeeklyWorkspaceCopy.closingSummary(
                placed: 8,
                tasksReleased: 3,
                meetingsReleased: 2,
                freeMinutes: 360
            ),
            "8 tasks placed · 2 meetings released · 3 tasks moved to Someday · about 6h still open"
        )
    }

    func testDecisionsSurviveANewStoreOverTheSameDefaults() {
        let name = "weekly-meeting-decisions-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let weekStart = Date(timeIntervalSince1970: 1_785_000_000)
        WeeklyMeetingDecisionStore(defaults: defaults, calendar: calendar)
            .setIntent(.skipping, weekStart: weekStart, occurrenceKey: "k")
        let reopened = WeeklyMeetingDecisionStore(defaults: defaults, calendar: calendar)
        XCTAssertEqual(reopened.intent(weekStart: weekStart, occurrenceKey: "k"), .skipping)
    }

    func testPruningDropsWeeksBeyondTheRetentionWindow() {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let now = Date(timeIntervalSince1970: 1_785_000_000)
        let ancient = now.addingTimeInterval(-40 * 7 * 86_400)
        store.setIntent(.skipping, weekStart: ancient, occurrenceKey: "old")
        store.setIntent(.skipping, weekStart: now, occurrenceKey: "current")
        store.prune(now: now)
        XCTAssertNil(store.intent(weekStart: ancient, occurrenceKey: "old"))
        XCTAssertEqual(store.intent(weekStart: now, occurrenceKey: "current"), .skipping)
    }

    func testWeekKeysSortChronologicallyAsStrings() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let earlier = WeeklyMeetingDecisionStore.weekKey(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!, calendar: calendar
        )
        let later = WeeklyMeetingDecisionStore.weekKey(
            calendar.date(from: DateComponents(year: 2026, month: 11, day: 5))!, calendar: calendar
        )
        XCTAssertLessThan(earlier, later, "Pruning is a string filter and depends on this ordering")
    }

    // MARK: Briefing

    func testTheBriefingNamesTheCountWithoutScolding() {
        let briefing = WeeklyOverdueBriefing(count: 9, oldestDate: nil)
        XCTAssertEqual(briefing.headline, "9 tasks have been waiting")
        for word in ["missed", "failed", "behind", "should"] {
            XCTAssertFalse(briefing.headline.lowercased().contains(word), "Copy must not judge: \(word)")
        }
    }

    func testTheBriefingDescribesRecentAndDistantBacklogsDifferently() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let ancient = calendar.date(from: DateComponents(year: 2026, month: 6, day: 24))!
        XCTAssertEqual(
            WeeklyOverdueBriefing(count: 1, oldestDate: yesterday).detail(now: now, calendar: calendar),
            "The oldest is from yesterday."
        )
        let old = WeeklyOverdueBriefing(count: 40, oldestDate: ancient).detail(now: now, calendar: calendar)
        XCTAssertEqual(old, "The oldest is from 24 June.")
    }

    func testAnEmptyBriefingHasNoDetail() {
        XCTAssertTrue(WeeklyOverdueBriefing(count: 0, oldestDate: nil).isEmpty)
        XCTAssertNil(WeeklyOverdueBriefing(count: 0, oldestDate: Date()).detail())
    }

    // MARK: Intra-day order

    func testReorderMovesATaskDirectlyBeforeItsTarget() {
        let ids = (0..<4).map { _ in UUID() }
        XCTAssertEqual(
            WeeklyDayOrdering.reordered(ids, moving: ids[3], before: ids[1]),
            [ids[0], ids[3], ids[1], ids[2]]
        )
    }

    func testReorderWithNoTargetSendsTheTaskToTheEndOfTheDay() {
        let ids = (0..<3).map { _ in UUID() }
        XCTAssertEqual(
            WeeklyDayOrdering.reordered(ids, moving: ids[0], before: nil),
            [ids[1], ids[2], ids[0]]
        )
    }

    /// A fumbled drag should do nothing rather than shuffle the list.
    func testAFumbledReorderIsANoOp() {
        let ids = (0..<3).map { _ in UUID() }
        XCTAssertEqual(WeeklyDayOrdering.reordered(ids, moving: ids[1], before: ids[1]), ids)
        XCTAssertEqual(WeeklyDayOrdering.reordered(ids, moving: UUID(), before: ids[0]), ids)
        XCTAssertEqual(WeeklyDayOrdering.reordered(ids, moving: ids[0], before: UUID()), ids)
    }

    func testRanksAreDenseAndZeroBased() {
        let ids = (0..<4).map { _ in UUID() }
        let ranks = WeeklyDayOrdering.ranks(for: ids)
        XCTAssertEqual(ids.map { ranks[$0] }, [0, 1, 2, 3])
    }

    /// Work placed before ordering existed carries no rank. It must sort after
    /// arranged work rather than all collapsing to position zero, where it would
    /// jump above everything the user deliberately put in order.
    func testUnrankedTasksSortAfterRankedOnesRatherThanAtTheTop() {
        let items: [(String, Int?)] = [("zebra", nil), ("apple", 2), ("beta", nil), ("cherry", 0)]
        let sorted = WeeklyDayOrdering.sorted(items, rank: { $0.1 }, tiebreak: { $0.0 })
        XCTAssertEqual(sorted.map(\.0), ["cherry", "apple", "beta", "zebra"])
    }

    func testSortingIsStableForItemsThatTieCompletely() {
        let items: [(String, Int?)] = [("same", nil), ("same", nil), ("same", nil)]
        XCTAssertEqual(
            WeeklyDayOrdering.sorted(items, rank: { $0.1 }, tiebreak: { $0.0 }).count,
            3
        )
    }

    // MARK: Time boxing

    private func window(_ startHour: Int, _ endHour: Int) -> FreeWindow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return FreeWindow(
            startAt: calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: startHour))!,
            endAt: calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: endHour))!
        )
    }

    /// Best-fit rather than first-fit: packing the morning leaves an unusable
    /// scatter of gaps, and the long uninterrupted stretches are the only
    /// windows deep work can go in.
    func testTimeBoxingPrefersTheTightestWindowThatFits() {
        let start = WeeklyTimeBox.bestFitStart(
            windows: [window(9, 13), window(14, 15), window(16, 20)],
            minutes: 45
        )
        XCTAssertEqual(start, window(14, 15).startAt, "The one-hour gap fits 45 minutes most snugly")
    }

    func testTimeBoxingRefusesWhenNothingIsLongEnough() {
        XCTAssertNil(WeeklyTimeBox.bestFitStart(windows: [window(9, 10)], minutes: 180))
        XCTAssertNil(WeeklyTimeBox.bestFitStart(windows: [], minutes: 30))
    }

    /// Boxing into a gap that has already gone by would put work in the past.
    func testTimeBoxingOnTodayNeverStartsBeforeNow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 11))!
        let start = WeeklyTimeBox.bestFitStart(windows: [window(9, 13)], minutes: 60, after: now)
        XCTAssertEqual(start, now)
    }

    func testAWindowIsRejectedWhenOnlyItsPastPortionWouldFit() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 12, minute: 45))!
        XCTAssertNil(
            WeeklyTimeBox.bestFitStart(windows: [window(9, 13)], minutes: 60, after: now),
            "Only fifteen minutes of the window remain"
        )
    }

    // MARK: Composer

    private var referenceNow: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 9))!
    }

    private func parsed(
        title: String,
        due: Date? = nil,
        duration: TimeInterval? = nil
    ) -> ParsedCapture {
        ParsedCapture(
            cleanTitle: title,
            dueDate: due,
            isAllDay: due != nil,
            matchedText: nil,
            duration: duration
        )
    }

    /// The parser means "deadline" in a capture sheet. In a planning surface
    /// whose field says "Add to Thursday", a typed day means *where to put it* —
    /// writing a due date here would invent commitments the user never made.
    func testATypedDaySetsThePlacementDayAndNotADueDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        let line = WeeklyComposerPlacement.resolve(
            parsed(title: "Book the venue", due: friday),
            rawText: "Book the venue Friday",
            today: day(4),
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertEqual(line?.title, "Book the venue")
        XCTAssertEqual(line?.day, day(7))
    }

    func testALineWithNoDatePhraseStaysOnTheComposersDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let line = WeeklyComposerPlacement.resolve(
            parsed(title: "Book the venue"),
            rawText: "Book the venue",
            today: day(4),
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertNil(line?.day, "nil means: use whichever day the composer is pointed at")
    }

    /// Placement into the past is refused everywhere else in this surface, and
    /// a mistyped date must not be the one path around that.
    func testAPastDatePhraseIsIgnoredRatherThanHonoured() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let lastMonday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27))!
        let line = WeeklyComposerPlacement.resolve(
            parsed(title: "Call the studio", due: lastMonday),
            rawText: "Call the studio last Monday",
            today: day(4),
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertNil(line?.day)
    }

    func testDurationPhrasesBecomeAnEstimate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let line = WeeklyComposerPlacement.resolve(
            parsed(title: "Review deck", duration: 45 * 60),
            rawText: "Review deck for 45 min",
            today: day(4),
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertEqual(line?.estimatedMinutes, 45)
    }

    /// "Friday" alone parses to an empty title. Creating a task called "Friday"
    /// is wrong and creating an untitled one is worse, so the raw text stands.
    func testALineThatIsOnlyADateKeepsItsRawText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let friday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        let line = WeeklyComposerPlacement.resolve(
            parsed(title: "", due: friday),
            rawText: "Friday",
            today: day(4),
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertEqual(line?.title, "Friday")
    }

    func testAnEmptyLineProducesNothing() {
        XCTAssertNil(
            WeeklyComposerPlacement.resolve(
                parsed(title: "   "),
                rawText: "   ",
                today: day(4)
            )
        )
    }

    /// End to end through the real parser, so the wiring is covered and not just
    /// the resolution rule.
    func testTheRealParserFeedsThePlacementRule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let today = PlanningDay(date: referenceNow, timeZone: zone, calendar: calendar)
        let line = WeeklyComposerPlacement.resolve(
            TaskCaptureParser.parse("Review deck for 45 min"),
            rawText: "Review deck for 45 min",
            today: today,
            calendar: calendar,
            timeZone: zone
        )
        XCTAssertEqual(line?.title, "Review deck")
        XCTAssertEqual(line?.estimatedMinutes, 45)
    }

    // MARK: Routing

    /// The route is what makes the Home card land on the backlog decision
    /// instead of on Plan's Day lens, and it has to survive state restoration.
    func testTheWorkspaceRouteRoundTripsThroughRestoration() throws {
        for entry in [WeeklyPlanningEntry.week, .overdue] {
            let route = AppRoute.weeklyPlanningWorkspace(entry)
            let data = try JSONEncoder().encode(route)
            XCTAssertEqual(try JSONDecoder().decode(AppRoute.self, from: data), route)
        }
    }

    func testTheWizardRouteStillDecodesAlongsideTheWorkspaceRoute() throws {
        let data = try JSONEncoder().encode(AppRoute.weeklyPlanner)
        XCTAssertEqual(try JSONDecoder().decode(AppRoute.self, from: data), .weeklyPlanner)
    }

    func testACandidateWithoutARouteStillDecodes() throws {
        let legacy = """
        {"id":"planning-overdue","widgetKind":"tasks","title":"9 tasks need a quick reset",
        "reason":{"message":"m","signal":"s"},"destination":"plan","sensitivity":"privateStandard",
        "priority":310,"relevantFrom":0,"isUserStartedActiveState":false}
        """
        let decoded = try JSONDecoder().decode(HomeContextCandidate.self, from: Data(legacy.utf8))
        XCTAssertNil(decoded.route)
        XCTAssertEqual(decoded.actionTitle, "Open Plan")
    }

    func testACardWithARouteNamesWhatItOpensRatherThanTheTab() {
        let candidate = HomeContextCandidate(
            id: "planning-overdue",
            widgetKind: .tasks,
            title: "9 tasks need a quick reset",
            reason: .init(message: "m", signal: "s"),
            destination: .plan,
            priority: 310,
            route: .weeklyPlanningWorkspace(.overdue)
        )
        XCTAssertEqual(candidate.actionTitle, "Plan the overdue work")
    }
}

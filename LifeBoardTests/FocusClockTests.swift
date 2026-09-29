import XCTest
import LifeBoardDomain
import LifeBoardTokens
@testable import LifeBoard

/// The Focus surface's clock and arc maths.
///
/// This logic used to be two `private` methods on `PlanActiveFocusCard`, so the
/// only way to exercise it was to render the card. Extracting it into `FocusClock`
/// while building the new surface made it directly testable — which matters
/// because the interesting cases are the unbounded modes, where the honest
/// answer is "there is no fraction" and the tempting one is to return 0 or 1.
/// `@MainActor` because `FocusClock` is: it formats through
/// `PlanSectionCopy.duration`, which is main-actor isolated. Annotating the test
/// case is the right side to fix — the alternative is making the copy layer
/// nonisolated to suit a test, which would weaken an invariant the app relies on.
@MainActor
final class FocusClockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func session(
        target: TimeInterval = 1_800,
        state: FocusSessionState = .running
    ) -> FocusSessionV2 {
        FocusSessionV2(targetDuration: target, state: state, startedAt: start)
    }

    private func companion(_ mode: FocusMode, phase: FocusPomodoroPhase? = nil) -> FocusSessionCompanion {
        FocusSessionCompanion(sessionID: UUID(), mode: mode, pomodoroPhase: phase)
    }

    // MARK: Progress

    func testCountdownProgressTracksElapsedFraction() {
        let progress = FocusClock.progress(
            session: session(target: 1_000),
            companion: companion(.countdown(duration: 1_000)),
            at: start.addingTimeInterval(250)
        )
        XCTAssertEqual(try XCTUnwrap(progress), 0.25, accuracy: 0.001)
    }

    /// Unbounded modes have no fraction, and saying so is the point. Returning 0
    /// would draw an empty ring that reads as "no progress"; returning 1 would
    /// read as finished. `nil` draws the track alone.
    func testUnboundedModesReportNoProgress() {
        for mode in [FocusMode.stopwatch, .openEnded] {
            XCTAssertNil(
                FocusClock.progress(
                    session: session(),
                    companion: companion(mode),
                    at: start.addingTimeInterval(600)
                ),
                "\(mode) must not fabricate a fraction"
            )
        }
        // No companion at all is the same situation.
        XCTAssertNil(FocusClock.progress(session: session(), companion: nil, at: start))
    }

    func testCountdownWithNoTargetReportsNoProgress() {
        // Guards a division by zero that would otherwise produce NaN and put the
        // dial's trim into an undefined state.
        XCTAssertNil(
            FocusClock.progress(
                session: session(target: 0),
                companion: companion(.countdown(duration: 0)),
                at: start.addingTimeInterval(60)
            )
        )
    }

    func testProgressIsClampedToTheRing() {
        let overrun = FocusClock.progress(
            session: session(target: 100),
            companion: companion(.countdown(duration: 100)),
            at: start.addingTimeInterval(10_000)
        )
        XCTAssertEqual(try XCTUnwrap(overrun), 1, accuracy: 0.001, "A late session cannot exceed the ring")
    }

    // MARK: Display

    func testCountdownCountsDownRatherThanUp() {
        let display = FocusClock.display(
            session: session(target: 1_000),
            companion: companion(.countdown(duration: 1_000)),
            at: start.addingTimeInterval(400)
        )
        XCTAssertEqual(display.value, 600, accuracy: 0.001)
        XCTAssertTrue(display.showsClock)
        XCTAssertTrue(display.label.contains("left"))
    }

    func testExpiredCountdownAsksForADecisionInsteadOfShowingZero() {
        let display = FocusClock.display(
            session: session(target: 100),
            companion: companion(.countdown(duration: 100)),
            at: start.addingTimeInterval(5_000)
        )
        XCTAssertEqual(display.value, 0)
        XCTAssertEqual(display.label, "Time’s up")
    }

    func testStopwatchCountsUp() {
        let display = FocusClock.display(
            session: session(),
            companion: companion(.stopwatch),
            at: start.addingTimeInterval(90)
        )
        XCTAssertEqual(display.value, 90, accuracy: 0.001)
        XCTAssertTrue(display.label.contains("elapsed"))
    }

    /// Open-ended focus has no number worth showing, so the dial shows words.
    func testOpenEndedSuppressesTheClock() {
        let display = FocusClock.display(
            session: session(),
            companion: companion(.openEnded),
            at: start.addingTimeInterval(600)
        )
        XCTAssertFalse(display.showsClock)
        XCTAssertTrue(display.label.contains("Open-ended"))
    }

    /// Paused is announced in the dial's accessibility value, not only by the
    /// arc changing tint — DESIGN.md requires state to use text, shape and
    /// colour together.
    func testPausedIsAnnouncedInEveryMode() {
        let modes: [FocusMode] = [.countdown(duration: 1_000), .stopwatch, .openEnded]
        for mode in modes {
            let display = FocusClock.display(
                session: session(state: .paused),
                companion: companion(mode),
                at: start.addingTimeInterval(120)
            )
            XCTAssertTrue(display.label.hasSuffix(", paused"), "\(mode) should announce paused")
        }
    }

    func testRunningSessionsDoNotClaimToBePaused() {
        let display = FocusClock.display(
            session: session(),
            companion: companion(.stopwatch),
            at: start.addingTimeInterval(120)
        )
        XCTAssertFalse(display.label.contains("paused"))
    }
}

@MainActor
final class FocusSurfaceImprovementTests: XCTestCase {
    func testClockReadsMinutesAndSeconds() {
        XCTAssertEqual(FocusClock.clockText(25 * 60), "25:00")
        XCTAssertEqual(FocusClock.clockText(24 * 60 + 37.9), "24:37")
        XCTAssertEqual(FocusClock.clockText(3_909), "1:05:09")
        XCTAssertEqual(FocusClock.clockText(-4), "0:00")
    }

    func testHeadlinePrefersIntentionThenTaskTitle() {
        XCTAssertEqual(FocusSurfaceCommitmentSection.headline(companion: nil, taskTitle: "Write launch notes"), "Write launch notes")
        XCTAssertEqual(FocusSurfaceCommitmentSection.headline(companion: nil, taskTitle: nil), "Focusing")
        let companion = FocusSessionCompanion(sessionID: UUID(), mode: .countdown(duration: 60), intention: "Draft the intro")
        XCTAssertEqual(FocusSurfaceCommitmentSection.headline(companion: companion, taskTitle: "Write launch notes"), "Draft the intro")
    }

    func testPomodoroAdvancesOnlyWhenARunningPhaseHasEnded() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let session = FocusSessionV2(targetDuration: 1_500, state: .running, startedAt: start)
        var companion = FocusSessionCompanion(sessionID: session.id, mode: .pomodoro(focus: 1_500, breakDuration: 300, rounds: 4))
        companion.pomodoroPhase = FocusPomodoroPhase(phaseStartedAt: start, phaseEndsAt: start.addingTimeInterval(1_500))

        XCTAssertFalse(FocusPomodoroAutoAdvance.shouldAdvance(session: session, companion: companion, isSettled: false, now: start.addingTimeInterval(1_499)))
        XCTAssertTrue(FocusPomodoroAutoAdvance.shouldAdvance(session: session, companion: companion, isSettled: false, now: start.addingTimeInterval(1_500)))

        var paused = session
        paused.state = .paused
        XCTAssertFalse(FocusPomodoroAutoAdvance.shouldAdvance(session: paused, companion: companion, isSettled: false, now: start.addingTimeInterval(2_000)))
        XCTAssertFalse(FocusPomodoroAutoAdvance.shouldAdvance(session: session, companion: companion, isSettled: true, now: start.addingTimeInterval(2_000)))
    }
}

/// The in-place reflection's beats stay inside the signature-moment budget
/// and collapse to a crossfade under Calm or Reduce Motion.
final class FocusReflectionTimelineTests: XCTestCase {
    func testCalmAndReduceMotionCollapseToACrossfade() {
        XCTAssertEqual(FocusReflectionTimeline.resolve(comfort: .calm, reduceMotion: false).total, 0)
        XCTAssertEqual(FocusReflectionTimeline.resolve(comfort: .playful, reduceMotion: true).total, 0)
    }

    func testBalancedAndPlayfulStageTheBeatsInOrderInsideTheBudget() {
        for comfort in [ComfortProfile.balanced, .playful] {
            let timeline = FocusReflectionTimeline.resolve(comfort: comfort, reduceMotion: false)
            XCTAssertLessThan(timeline.tickDelay, timeline.numberDelay)
            XCTAssertLessThan(timeline.numberDelay, timeline.promptDelay)
            XCTAssertLessThan(timeline.total, FocusReflectionTimeline.budget, "\(comfort) must not outlast a signature moment")
            XCTAssertGreaterThan(timeline.tickDuration, 0)
        }
        // Playful is springier, never slower.
        XCTAssertEqual(
            FocusReflectionTimeline.resolve(comfort: .playful, reduceMotion: false).total,
            FocusReflectionTimeline.resolve(comfort: .balanced, reduceMotion: false).total
        )
    }
}

/// Every number on the history screen, from fixed dates.
final class FocusHistoryProjectionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2030, month: 3, day: day, hour: hour))!
    }

    private func ended(_ id: UUID = UUID(), task: UUID?, day: Int, minutes: Double, paused: TimeInterval = 0, outcome: FocusCompletionOutcome = .completed) -> FocusSessionV2 {
        let start = date(day)
        return FocusSessionV2(
            id: id, taskID: task, timeBlockID: nil, targetDuration: minutes * 60, state: .ended,
            startedAt: start, pausedAt: nil, endedAt: start.addingTimeInterval(minutes * 60 + paused),
            accumulatedPauseDuration: paused, interruptionCount: 0, outcome: outcome,
            energyAfter: 4, reflection: nil, appliedCommandIDs: []
        )
    }

    func testMinutesTotalsAndTopTasksCountOnlyEndedSessionsInTheMonth() {
        let taskA = UUID(), taskB = UUID()
        var running = ended(task: taskA, day: 5, minutes: 30)
        running = FocusSessionV2(id: running.id, taskID: taskA, timeBlockID: nil, targetDuration: 1800, state: .running, startedAt: date(5), pausedAt: nil, endedAt: nil, accumulatedPauseDuration: 0, interruptionCount: 0, outcome: nil, energyAfter: nil, reflection: nil, appliedCommandIDs: [])
        let sessions = [
            ended(task: taskA, day: 3, minutes: 25),
            ended(task: taskA, day: 3, minutes: 20, paused: 600),   // the pause is not focus
            ended(task: taskB, day: 12, minutes: 50),
            ended(task: nil, day: 20, minutes: 15),
            running,
            ended(task: taskB, day: 31, minutes: 10), // March 31 is still March
        ]
        let lastMonth = ended(task: taskB, day: 1, minutes: 99).startedAt.addingTimeInterval(-3600 * 24 * 40)
        let outOfMonth = FocusSessionV2(id: UUID(), taskID: taskB, timeBlockID: nil, targetDuration: 99, state: .ended, startedAt: lastMonth, pausedAt: nil, endedAt: lastMonth.addingTimeInterval(99 * 60), accumulatedPauseDuration: 0, interruptionCount: 0, outcome: .completed, energyAfter: nil, reflection: nil, appliedCommandIDs: [])
        let projection = FocusHistoryProjection.make(
            month: date(15), sessions: sessions + [outOfMonth],
            titles: { $0 == taskA ? "Write the brief" : $0 == taskB ? "Review numbers" : nil },
            calendar: calendar
        )
        XCTAssertEqual(projection.days.count, 31)
        XCTAssertEqual(projection.sessionCount, 5)
        XCTAssertEqual(projection.totalMinutes, 25 + 20 + 50 + 15 + 10)
        XCTAssertEqual(projection.longestMinutes, 50)
        XCTAssertEqual(projection.days[2].minutes, 45)
        XCTAssertEqual(projection.days[2].sessionCount, 2)
        XCTAssertEqual(projection.days[4].minutes, 0, "A running session is not history")
        XCTAssertEqual(projection.topTasks.map(\.title), ["Review numbers", "Write the brief", "Untitled focus"])
        XCTAssertEqual(projection.topTasks.first?.minutes, 60)
        XCTAssertEqual(projection.sessions.first?.startedAt, date(31), "Newest first")
    }

    func testTintsAreQuartilesOfTheMonthsFocusedDaysWithTextEquivalents() {
        let task = UUID()
        let sessions = [10, 20, 30, 40].enumerated().map { index, minutes in ended(task: task, day: index + 1, minutes: Double(minutes)) }
        let projection = FocusHistoryProjection.make(month: date(1), sessions: sessions, titles: { _ in "T" }, calendar: calendar)
        XCTAssertEqual(projection.days.prefix(4).map(\.tint), [1, 2, 3, 4])
        XCTAssertEqual(projection.days[4].tint, 0)
        XCTAssertEqual(projection.days[4].summary, "No focus")
        XCTAssertEqual(projection.days[3].summary, "40 min in 1 session")
        XCTAssertEqual(FocusHistoryProjection.durationText(minutes: 80), "1 hr, 20 min")
        XCTAssertEqual(FocusHistoryProjection.durationText(minutes: 120), "2 hr")
        XCTAssertEqual(FocusHistoryProjection.durationText(minutes: 0), "0 min")
    }
}

/// Presets round-trip through preferences, resolve by id with a safe fallback,
/// and map onto the focus modes the store actually starts.
final class FocusPresetTests: XCTestCase {
    func testDefaultsSurviveEncodingAndAnEmptyListRestoresThem() throws {
        var preferences = WorkspacePreferences()
        XCTAssertEqual(preferences.focusPresets, FocusPreset.defaults)
        preferences.focusPresets = [FocusPreset(id: "mine", name: "Mine", kind: .countdown, minutes: 40)]
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(WorkspacePreferences.self, from: data)
        XCTAssertEqual(decoded.focusPresets.map(\.id), ["mine"])
        // A payload written before presets existed decodes to the defaults.
        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "focusPresets")
        let legacy = try JSONDecoder().decode(WorkspacePreferences.self, from: try JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.focusPresets, FocusPreset.defaults)
        XCTAssertEqual(WorkspacePreferences(focusPresets: []).focusPresets, FocusPreset.defaults)
    }

    func testResolveFallsBackToTheFirstPresetAndModesMatchKinds() {
        let preferences = WorkspacePreferences()
        XCTAssertEqual(FocusPreset.resolve(id: "quick", in: preferences).id, "quick")
        XCTAssertEqual(FocusPreset.resolve(id: "nope", in: preferences).id, "deep-work")
        XCTAssertEqual(FocusPreset.resolve(id: nil, in: preferences).id, "deep-work")
        if case .pomodoro(let focus, let rest, let rounds) = FocusPreset.defaults[0].focusMode {
            XCTAssertEqual(focus, 50 * 60); XCTAssertEqual(rest, 10 * 60); XCTAssertEqual(rounds, 2)
        } else { XCTFail("Deep work is a Pomodoro") }
        if case .countdown(let duration) = FocusPreset.defaults[2].focusMode {
            XCTAssertEqual(duration, 15 * 60)
        } else { XCTFail("Quick is a countdown") }
        XCTAssertEqual(FocusPreset(id: "s", name: "S", kind: .stopwatch).summary, "Stopwatch")
        XCTAssertEqual(FocusPreset.defaults[1].summary, "25 / 5 × 4")
    }
}

/// The Dynamic Island's title is an immutable activity attribute, so the
/// command service names the session before it requests the activity.
final class FocusPresentationTitleTests: XCTestCase {
    private func session() -> FocusSessionV2 {
        FocusSessionV2(taskID: UUID(), targetDuration: 1_500)
    }

    func testIntentionThenTaskTitleThenGenericLabel() async {
        let s = session()
        let companion = FocusSessionCompanion(sessionID: s.id, mode: .countdown(duration: 1500), intention: "  Draft the intro  ")
        let intention = await FocusSessionCommands.presentationTitle(for: s, companion: companion, resolver: { _ in "Write launch notes" })
        XCTAssertEqual(intention, "Draft the intro")
        let blank = FocusSessionCompanion(sessionID: s.id, mode: .countdown(duration: 1500), intention: "   ")
        let task = await FocusSessionCommands.presentationTitle(for: s, companion: blank, resolver: { _ in "Write launch notes" })
        XCTAssertEqual(task, "Write launch notes")
        let generic = await FocusSessionCommands.presentationTitle(for: s, companion: nil, resolver: { _ in "  " })
        XCTAssertEqual(generic, "Focus session")
        let none = await FocusSessionCommands.presentationTitle(for: s, companion: nil, resolver: nil)
        XCTAssertEqual(none, "Focus session")
    }
}


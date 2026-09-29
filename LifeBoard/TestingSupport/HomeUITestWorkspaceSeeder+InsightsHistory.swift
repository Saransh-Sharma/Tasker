import CoreData
import Foundation
import UIKit
import LifeBoardDomain

/// Three weeks of lived history, so Insights Trends and Review, the Journal's
/// Calendar, Gallery and "On this day", and Focus history can be opened and
/// read on the simulator. No other seed writes more than today.
///
/// The values vary on purpose. `DailyCorrelationEngine` needs at least ten
/// paired days and a real rank relationship before it says anything, so focus
/// minutes and journal energy rise and fall together here, and things done
/// wobble independently of both.
///
/// Health series are not written. The health ledger is attached only behind
/// the health integration flag and a validated privacy migration, and a seed
/// that wrote around that gate would verify a path the app never takes; the
/// Trends lens is read here from focus, journal energy, habits and things done.
extension HomeUITestWorkspaceSeeder {
    static let insightsHistoryArgument = "-LIFEBOARD_TEST_SEED_INSIGHTS_HISTORY"
    static let insightsHistoryDayCount = 21
    private static var hasSeededUITestInsightsHistory = false

    func seedUITestInsightsHistoryIfNeeded(presentationDependencyContainer: CompositionRoot?, completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains(Self.insightsHistoryArgument),
              Self.hasSeededUITestInsightsHistory == false,
              let presentationDependencyContainer,
              let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let container = appDelegate.persistentContainer
        else {
            completion()
            return
        }
        Self.hasSeededUITestInsightsHistory = true

        Task { @MainActor in
            let now = HomeReferenceClock.now
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            let days: [Date] = (1...Self.insightsHistoryDayCount).reversed().compactMap {
                calendar.date(byAdding: .day, value: -$0, to: today)
            }

            await Self.seedJournal(days: days, today: today, calendar: calendar, container: container)
            await Self.seedThingsDone(days: days, repository: presentationDependencyContainer.gamificationRepository)
            await Self.seedFocusSessions(days: days, calendar: calendar, container: container)
            await Self.seedReflectionNotes(days: days, today: today, calendar: calendar, repository: presentationDependencyContainer.reflectionNoteRepository)
            await Self.seedHabitHistory(days: days, dependencies: presentationDependencyContainer)

            logWarning(
                event: "ui_test_insights_history_seeded",
                message: "Seeded insights history; health series are not written by this seed",
                fields: ["days": String(Self.insightsHistoryDayCount)]
            )
            completion()
        }
    }

    // MARK: Series shape

    /// A slow wave, so neighbouring days resemble each other and the usual
    /// range has a band to draw.
    static func wave(_ index: Int, period: Double = 7) -> Double {
        (sin(Double(index) / period * 2 * .pi) + 1) / 2
    }

    static func energy(forDay index: Int) -> Int {
        // 1…5, following the focus wave with a one-step wobble.
        let base = 1 + Int((wave(index) * 3.6).rounded())
        return min(5, max(1, base + (index % 5 == 0 ? -1 : 0)))
    }

    static func focusMinutes(forDay index: Int) -> Int {
        20 + Int((wave(index) * 70).rounded())
    }

    static func thingsDone(forDay index: Int) -> Int {
        2 + (index * 7 % 5)
    }

    // MARK: Writers

    private static func seedJournal(days: [Date], today: Date, calendar: Calendar, container: NSPersistentContainer) async {
        let repository = CoreDataLifeBoardPhaseIIRepository(container: container)
        let moods: [JournalMood] = [.calm, .happy, .tired, .grateful, .anxious, .excited, .calm]
        let titles = ["A slow start", "Long walk at lunch", "", "Finished the draft", "", "Rainy, quiet", ""]
        let reasonSets: [[String]] = [["work"], ["sleep"], [], ["people", "work"], ["health"], [], ["sleep"]]
        // Earlier dates for "On this day": a month and a year back.
        let echoes = [
            calendar.date(byAdding: .month, value: -1, to: today),
            calendar.date(byAdding: .year, value: -1, to: today)
        ].compactMap { $0 }
        for (index, day) in (days + echoes).enumerated() {
            let dayID = UUID()
            let isEcho = index >= days.count
            let noon = day.addingTimeInterval(12 * 3_600)
            var blocks: [JournalBlockValue] = [
                JournalBlockValue(
                    dayID: dayID,
                    kind: .mood,
                    text: JournalMoodReasons.encode(reasonSets[index % reasonSets.count]),
                    mood: moods[index % moods.count],
                    energy: energy(forDay: index),
                    createdAt: day.addingTimeInterval(8 * 3_600),
                    updatedAt: day.addingTimeInterval(8 * 3_600),
                    ordinal: 0
                ),
                JournalBlockValue(
                    dayID: dayID,
                    kind: .text,
                    text: isEcho ? "The same season, a while ago." : "Wrote a few lines about the day.",
                    createdAt: noon,
                    updatedAt: noon,
                    ordinal: 1
                )
            ]
            if isEcho == false, index % 3 == 0 {
                blocks.append(JournalBlockValue(
                    dayID: dayID,
                    kind: .dayClose,
                    text: "Closed the day.",
                    energy: energy(forDay: index),
                    createdAt: day.addingTimeInterval(21 * 3_600),
                    updatedAt: day.addingTimeInterval(21 * 3_600),
                    ordinal: 2
                ))
            }
            let title = titles[index % titles.count]
            let value = JournalDayValue(
                id: dayID,
                day: day,
                summary: title.isEmpty ? nil : title,
                createdAt: day,
                updatedAt: noon,
                blocks: blocks
            )
            do {
                try await repository.saveJournalDay(value)
            } catch {
                logError(event: "ui_test_insights_history_journal_failed", message: "Journal day not seeded", fields: ["error": error.localizedDescription])
            }
        }
    }

    private static func seedThingsDone(days: [Date], repository: GamificationRepositoryProtocol?) async {
        guard let repository else { return }
        for (index, day) in days.enumerated() {
            let aggregate = DailyXPAggregateDefinition(
                dateKey: XPCalculationService.periodKey(for: day),
                totalXP: thingsDone(forDay: index) * 10,
                eventCount: thingsDone(forDay: index),
                updatedAt: day
            )
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                repository.saveDailyAggregate(aggregate) { _ in continuation.resume() }
            }
        }
    }

    /// Start then end, one day at a time: the repository returns the active
    /// session instead of starting a second, so each must end before the next.
    /// Ending with a past `occurredAt` is accepted; the state machine only
    /// clamps it to the start.
    private static func seedFocusSessions(days: [Date], calendar: Calendar, container: NSPersistentContainer) async {
        let repository = CoreDataPlanningRepository(container: container)
        for (index, day) in days.enumerated() where index % 4 != 3 {
            let start = day.addingTimeInterval(10 * 3_600)
            let minutes = focusMinutes(forDay: index)
            do {
                let session = try await repository.start(taskID: nil, timeBlockID: nil, targetDuration: TimeInterval(minutes * 60), at: start)
                _ = try await repository.handle(FocusSessionCommand(
                    sessionID: session.id,
                    kind: .end(.completed),
                    occurredAt: start.addingTimeInterval(TimeInterval(minutes * 60))
                ))
            } catch {
                logError(event: "ui_test_insights_history_focus_failed", message: "Focus session not seeded", fields: ["error": error.localizedDescription])
            }
        }
    }

    private static func seedReflectionNotes(days: [Date], today: Date, calendar: Calendar, repository: ReflectionNoteRepositoryProtocol?) async {
        guard let repository else { return }
        var notes: [ReflectionNote] = days.enumerated().compactMap { index, day in
            guard index % 3 != 1 else { return nil }
            return ReflectionNote(
                kind: .dayClose,
                energy: energy(forDay: index),
                noteText: index % 2 == 0 ? "Quiet evening." : "",
                createdAt: day.addingTimeInterval(21 * 3_600)
            )
        }
        if let lastWeek = calendar.date(byAdding: .day, value: -7, to: today) {
            notes.append(ReflectionNote(kind: .weeklyReview, noteText: "A steadier week than the last.", createdAt: lastWeek))
        }
        // Due, so the Review lens asks "Did it help?".
        if let started = calendar.date(byAdding: .day, value: -8, to: today) {
            let experiment = InsightExperiment(
                hypothesis: "On days with more focus, your energy tended to be higher",
                sourceCorrelationID: "focusMinutes|journalEnergy|sameDay",
                action: .habit(templateID: "walk", habitID: nil),
                startedAt: started,
                calendar: calendar
            )
            if let note = try? experiment.note() { notes.append(note) }
        }
        for note in notes {
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                repository.saveNote(note) { _ in continuation.resume() }
            }
        }
    }

    /// One daily habit, completed on most days. Past occurrences may not
    /// resolve for dates before the habit's schedule begins; those are logged
    /// and skipped, and the series simply starts later.
    private static func seedHabitHistory(days: [Date], dependencies: CompositionRoot) async {
        let coordinator = dependencies.coordinator
        do {
            let lifeArea = try await coordinator.manageLifeAreas.createAsync(name: "Rhythm", color: "#4E9A2F", icon: "leaf.fill")
            let habit = try await coordinator.createHabit.executeAsync(request: CreateHabitRequest(
                title: "Walk after lunch",
                lifeAreaID: lifeArea.id,
                projectID: nil,
                kind: .positive,
                trackingMode: .dailyCheckIn,
                icon: HabitIconMetadata(symbolName: "figure.walk", categoryKey: "health"),
                colorHex: HabitColorFamily.green.canonicalHex,
                targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                cadence: .daily()
            ))
            for (index, day) in days.enumerated() where index % 3 != 2 {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    coordinator.resolveHabitOccurrence.execute(habitID: habit.id, action: .complete, on: day.addingTimeInterval(13 * 3_600)) { _ in
                        continuation.resume()
                    }
                }
            }
        } catch {
            logError(event: "ui_test_insights_history_habit_failed", message: "Habit history not seeded", fields: ["error": error.localizedDescription])
        }
    }
}

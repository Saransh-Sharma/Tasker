import Foundation
import LifeBoardDomain

/// Gathers one value per day for each `DailyMetric` from the stores that
/// already exist. Each source is a closure so the Insights root can wire
/// them without reaching for a container, and tests can feed fixtures.
struct InsightsDailySeriesSources: @unchecked Sendable {
    /// Health aggregates for a domain over a range: metric → daily samples.
    var health: (HealthInsightDomain, HealthHistoryRange, Date) async -> [HealthMetric: [HealthAggregateValue]] = { _, _, _ in [:] }
    /// Focus sessions since a date.
    var focusSessions: (Date) async -> [FocusSessionV2] = { _ in [] }
    /// Journal days in a range (for energy check-ins).
    var journalDays: (Date, Date) async -> [JournalDayValue] = { _, _ in [] }
    /// Things done per day (the gamification ledger's event count: task,
    /// habit and focus completions) between two dates.
    var thingsDone: (Date, Date) async -> [(date: Date, value: Double)] = { _, _ in [] }
    /// Habit history for every active habit, ending on a day.
    var habitHistory: (Date, Int) async -> [HabitHistoryWindow] = { _, _ in [] }
}

extension XPCalculationService {
    /// The day a `periodKey` ("yyyy-MM-dd") names, at local midnight.
    static func date(forPeriodKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

enum InsightsDailySeriesLoader {
    static func load(
        range: InsightsRange,
        sources: InsightsDailySeriesSources,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async -> [DailySeries] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(range.days - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let healthRange: HealthHistoryRange = switch range {
        case .week: .sevenDays
        case .month: .thirtyDays
        case .year: .oneYear
        }

        async let activity = sources.health(.activity, healthRange, now)
        async let energy = sources.health(.energy, healthRange, now)
        async let sleep = sources.health(.sleep, healthRange, now)
        async let sessions = sources.focusSessions(start)
        async let journal = sources.journalDays(start, end)
        async let thingsDone = sources.thingsDone(start, today)
        async let habits = sources.habitHistory(today, range.days)

        var series: [DailySeries] = []

        let activityValues = await activity
        if let steps = activityValues[.steps] {
            series.append(DailySeriesAssembler.series(.steps, dailyValues: perDay(steps, calendar: calendar)))
        }
        if let active = await energy[.activeEnergy] {
            series.append(DailySeriesAssembler.series(.activeEnergy, dailyValues: perDay(active, calendar: calendar)))
        }
        if let sleepValues = await sleep[.sleep] {
            // Sleep aggregates are stored in seconds; the chart speaks hours.
            let hours = perDay(sleepValues, calendar: calendar).mapValues { $0 > 48 ? $0 / 3600 : $0 }
            series.append(DailySeriesAssembler.series(.sleepHours, dailyValues: hours))
        }

        let focusByDay = DailySeriesAssembler.perDaySum(
            await sessions.compactMap { session -> (date: Date, value: Double)? in
                let minutes = session.focusedDuration(at: session.endedAt ?? now) / 60
                return minutes > 0 ? (session.startedAt, minutes) : nil
            },
            calendar: calendar
        )
        series.append(DailySeriesAssembler.series(.focusMinutes, dailyValues: DailySeriesAssembler.window(focusByDay, days: range.days, now: now, calendar: calendar)))

        let energySamples = await journal.flatMap { day in
            day.blocks.compactMap { block -> (date: Date, value: Double)? in
                guard let energy = block.energy else { return nil }
                return (block.createdAt, Double(energy))
            }
        }
        series.append(DailySeriesAssembler.series(.journalEnergy, dailyValues: DailySeriesAssembler.perDayAverage(energySamples, calendar: calendar)))

        series.append(DailySeriesAssembler.series(.thingsDone, dailyValues: DailySeriesAssembler.perDaySum(await thingsDone, calendar: calendar)))

        let habitDays = await habits.flatMap { window in
            window.marks.filter { $0.state == .success }.map(\.date)
        }
        series.append(DailySeriesAssembler.series(.habitsCompleted, dailyValues: DailySeriesAssembler.perDayCount(habitDays, calendar: calendar)))

        return series.filter { $0.isEmpty == false }
    }

    private static func perDay(_ values: [HealthAggregateValue], calendar: Calendar) -> [Date: Double] {
        DailySeriesAssembler.perDaySum(values.map { (date: $0.start, value: $0.value) }, calendar: calendar)
    }
}

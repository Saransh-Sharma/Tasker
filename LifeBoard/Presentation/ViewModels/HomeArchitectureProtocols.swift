import Foundation

@MainActor
protocol HomeReloading: AnyObject {
    var currentDataRevision: HomeDataRevision { get }

    func loadTodayTasks()
    func refreshCurrentScopeContent(source: String)
    func handleExternalMutation(reason: HomeTaskMutationEvent, repostEvent: Bool)
    func enqueueReload(
        source: String,
        reason: HomeTaskMutationEvent?,
        taskID: UUID?,
        invalidateCaches: Bool,
        includeAnalytics: Bool,
        repostEvent: Bool,
        overrideScopes: Set<HomeReloadScope>?
    )
}

@MainActor
protocol HomeTimelineProjecting: AnyObject {
    func buildTimelineSnapshot(
        calendarSnapshot: HomeCalendarSnapshot,
        sunriseAnchor: SunriseAnchor,
        now: Date,
        calendar: Calendar
    ) -> HomeTimelineSnapshot
    func timelineWeekStartsOn() -> Weekday
    func showCalendarEventsInTimelineFromHome()
    func hideCalendarEventFromTimeline(eventID: String, on day: Date)
    func isCalendarEventHiddenFromHomeTimeline(eventID: String, on day: Date) -> Bool
}

@MainActor
protocol HomeHabitActionHandling: AnyObject {
    func completeHabit(_ row: HomeHabitRow, source: String)
    func skipHabit(_ row: HomeHabitRow, source: String)
    func lapseHabit(_ row: HomeHabitRow, source: String)
    func performHabitLastCellAction(_ row: HomeHabitRow, source: String)
    func logHabitProgress(_ row: HomeHabitRow, on date: Date, source: String)
    func logHabitLapse(_ row: HomeHabitRow, on date: Date, source: String)
    func clearHabitMutationErrorMessage()
}

@MainActor
protocol HomeCalendarStateProviding: AnyObject {
    var homeCalendarSnapshot: HomeCalendarSnapshot { get }

    func requestCalendarPermission(openSystemSettings: @escaping () -> Void)
    func refreshCalendarContext(reason: String)
}

@MainActor
protocol HomeSearchCoordinating: HomeSearchEngine {}

protocol HomeWidgetSnapshotWriting: AnyObject {
    func scheduleRefresh(reason: String)
}

extension HomeViewModel: HomeReloading {}
extension HomeViewModel: HomeTimelineProjecting {}
extension HomeViewModel: HomeHabitActionHandling {}
extension HomeViewModel: HomeCalendarStateProviding {}
extension HomeSearchEngineAdapter: HomeSearchCoordinating {}
extension TaskListWidgetSnapshotService: HomeWidgetSnapshotWriting {}

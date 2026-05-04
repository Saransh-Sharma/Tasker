import Foundation

struct HomeTimelineProjectionInput {
    let dataRevision: HomeDataRevision
    let selectedDay: Date
    let currentMinuteStamp: Int
    let foredropAnchor: ForedropAnchor
    let calendarSnapshot: HomeCalendarSnapshot
    let workspacePreferences: LifeBoardWorkspacePreferences
    let hiddenCalendarEvents: [HomeTimelineHiddenCalendarEventKey]
    let pinnedFocusTaskIDs: [UUID]
    let needsReplanCandidates: [HomeReplanCandidate]
    let replanState: HomeReplanSessionState
}

struct HomeTimelineProjectionBuilder {
    func cacheKey(for input: HomeTimelineProjectionInput) -> HomeTimelineSnapshotCacheKey {
        HomeTimelineSnapshotCacheKey(
            dataRevision: input.dataRevision,
            selectedDay: input.selectedDay,
            currentMinuteStamp: input.currentMinuteStamp,
            foredropAnchor: input.foredropAnchor,
            calendarSignature: HomeTimelineCalendarSignature(input.calendarSnapshot),
            workspacePreferences: HomeTimelineWorkspacePreferencesSignature(input.workspacePreferences),
            hiddenCalendarEvents: input.hiddenCalendarEvents.sorted(),
            pinnedFocusTaskIDs: input.pinnedFocusTaskIDs,
            needsReplanCandidates: input.needsReplanCandidates.map(HomeTimelineReplanCandidateSignature.init),
            replanState: HomeTimelineReplanStateSignature(input.replanState)
        )
    }

    func build(
        input: HomeTimelineProjectionInput,
        cached: (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot)?,
        makeSnapshot: () -> HomeTimelineSnapshot
    ) -> (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot) {
        let key = cacheKey(for: input)
        if let cached, cached.key == key {
            return cached
        }
        return (key, makeSnapshot())
    }
}

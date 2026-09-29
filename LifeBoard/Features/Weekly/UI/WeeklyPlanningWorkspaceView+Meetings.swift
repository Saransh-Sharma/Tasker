import SwiftUI

extension WeeklyPlanningWorkspaceView {
    // MARK: Meetings

    func meetings(on day: PlanningDay) -> [WeeklyWorkspaceDayMeeting] {
        WeeklyWorkspaceSectionCopy.meetings(store: store, overrides: meetingOverrides, on: day)
    }

    func chooseMeetingIntent(_ next: WeeklyMeetingIntent, for meeting: WeeklyWorkspaceDayMeeting) {
        let participation = meeting.commitment.participation ?? .unknown
        let derived = WeeklyMeetingPolicy.defaultIntent(
            participation: participation,
            state: meeting.commitment.eventState ?? .unspecified,
            isBusy: meeting.commitment.isBusy
        )
        let storedIntent: WeeklyMeetingIntent? = next == derived ? nil : next
        let decisionReceipt = decisions.setIntent(
            storedIntent,
            weekStart: weekStart,
            occurrenceKey: meeting.occurrenceKey,
            titleSnapshot: meeting.commitment.title
        )
        if let storedIntent {
            meetingOverrides[meeting.occurrenceKey] = storedIntent
        } else {
            meetingOverrides.removeValue(forKey: meeting.occurrenceKey)
        }
        sessionSummary.recordMeetingDecision()
        motionEvent = .meetingDecided(meeting.occurrenceKey)
        show(
            next == .skipping
                ? String(localized: "Skipping this week")
                : String(localized: "Added to your week"),
            undoToken: .meeting(decisionReceipt)
        )
        Haptic.settle.play()
    }
}

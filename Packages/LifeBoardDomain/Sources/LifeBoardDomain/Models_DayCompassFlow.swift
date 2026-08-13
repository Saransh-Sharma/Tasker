import Foundation

// Named by `NotificationServiceProtocol.dayCompass(flow:dateStamp:)`, so it is a
// domain concept rather than a Home presentation detail. It was declared in
// Presentation/Home/DayCompass alongside that surface's private view state.
public enum DayCompassFlow: String, Codable, CaseIterable, Sendable {
    case replan
    case morningPlan
    case eveningReview
    case rescue
    case inbox
    case resumeTask
}

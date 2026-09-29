import Foundation

struct EvaCapacityRecord: Encodable, Sendable {
    struct FreeWindow: Encodable, Sendable {
        let start: Date
        let end: Date
        let minutes: Int
    }

    let day: Date
    let workingMinutes: Int
    let fixedCalendarMinutes: Int
    let bufferMinutes: Int
    let usableMinutes: Int
    let plannedMinutes: Int
    let overloadMinutes: Int
    let confidence: String
    let freeWindows: [FreeWindow]
}

struct EvaDayLoopRecord: Encodable, Sendable {
    struct LastClose: Encodable, Sendable {
        let day: Date
        let plannedMinutes: Int
        let focusedMinutes: Int
        let completedCount: Int
        let unfinishedCount: Int
        let focusRatio: Double
    }

    let eligibleDays: Int
    let closedDays: Int
    let openedDays: Int
    let currentRunLength: Int
    let reversals: Int
    let lastClose: LastClose?
}

struct EvaRetrospectiveRecord: Encodable, Sendable {
    struct Outcome: Encodable, Sendable {
        let title: String
        let whyItMatters: String?
        let successDefinition: String?
        let status: String
    }

    let weekStart: Date?
    let focusStatement: String?
    let outcomes: [Outcome]
    let wins: String?
    let blockers: String?
    let lessons: String?
    let perceivedWeekRating: Int?
}

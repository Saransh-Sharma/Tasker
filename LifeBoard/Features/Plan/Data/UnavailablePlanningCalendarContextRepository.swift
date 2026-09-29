import Foundation

public struct UnavailablePlanningCalendarContextRepository: PlanningCalendarContextRepository {
    public init() {}
    public func authorization() async -> PlanningCalendarAuthorization { .unavailable }
    public func requestAccess() async -> PlanningCalendarAuthorization { .unavailable }
    public func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext {
        PlanningCalendarContext(authorization: .unavailable)
    }
}

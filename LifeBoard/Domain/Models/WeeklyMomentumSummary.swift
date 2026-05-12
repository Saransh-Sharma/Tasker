import Foundation

public struct WeeklyMomentumDriver: Codable, Equatable, Hashable, Identifiable {
    public let id: String
    public var label: String
    public var value: Double
    public var detail: String

    public init(
        id: String,
        label: String,
        value: Double,
        detail: String
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.detail = detail
    }
}

public struct WeeklyMomentumSummary: Codable, Equatable, Hashable {
    public var weekStartDate: Date
    public var weekEndDate: Date
    public var score: Int
    public var narrative: String
    public var overloadDetected: Bool
    public var completionRate: Double
    public var habitContinuityScore: Double
    public var carryOverCount: Int
    public var drivers: [WeeklyMomentumDriver]

    public init(
        weekStartDate: Date,
        weekEndDate: Date,
        score: Int = 0,
        narrative: String = "",
        overloadDetected: Bool = false,
        completionRate: Double = 0,
        habitContinuityScore: Double = 0,
        carryOverCount: Int = 0,
        drivers: [WeeklyMomentumDriver] = []
    ) {
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.score = score
        self.narrative = narrative
        self.overloadDetected = overloadDetected
        self.completionRate = completionRate
        self.habitContinuityScore = habitContinuityScore
        self.carryOverCount = carryOverCount
        self.drivers = drivers
    }
}

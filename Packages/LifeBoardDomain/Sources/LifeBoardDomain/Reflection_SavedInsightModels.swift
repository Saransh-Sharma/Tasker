import Foundation

public enum SavedInsightSource: String, Codable, CaseIterable, Sendable {
    case proactiveReflection
    case weeklyReflection
    case assistant
    case user
}

public struct SavedInsight: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var source: SavedInsightSource
    public var sourceID: String
    public var title: String
    public var summary: String
    public var evidence: [WeeklyReflectionEvidenceRef]
    public var savedAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        source: SavedInsightSource,
        sourceID: String,
        title: String,
        summary: String,
        evidence: [WeeklyReflectionEvidenceRef] = [],
        savedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.source = source
        self.sourceID = sourceID
        self.title = title
        self.summary = summary
        self.evidence = evidence
        self.savedAt = savedAt
        self.updatedAt = updatedAt
    }
}

public protocol SavedInsightProviding: Sendable {
    func savedInsights() async throws -> [SavedInsight]
    func savedInsight(id: UUID) async throws -> SavedInsight?
}

public protocol SavedInsightPersisting: Sendable {
    func save(_ insight: SavedInsight) async throws
    func deleteSavedInsight(id: UUID) async throws
}

public protocol WeeklyReflectionReportProviding: Sendable {
    func weeklyReflectionReports() async throws -> [WeeklyReflectionReport]
    func weeklyReflectionReport(id: UUID) async throws -> WeeklyReflectionReport?
}

public protocol WeeklyReflectionReportPersisting: Sendable {
    func save(_ report: WeeklyReflectionReport) async throws
    func deleteWeeklyReflectionReport(id: UUID) async throws
}

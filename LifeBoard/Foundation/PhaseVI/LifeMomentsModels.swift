import Foundation

public enum LifeMomentKind: String, Codable, CaseIterable, Hashable, Sendable {
    case countdown
    case anniversary
    case milestone
    case recurringMeaningfulEvent
}

public enum LifeMomentRecurrenceRule: Codable, Hashable, Sendable {
    case none
    case weekly
    case monthly
    case yearly
    case everyDays(Int)

    fileprivate var sanitized: Self {
        switch self {
        case .everyDays(let days): .everyDays(max(1, days))
        default: self
        }
    }
}

public struct LifeMoment: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var kind: LifeMomentKind
    public var eventDate: Date
    public var recurrenceRule: LifeMomentRecurrenceRule
    public var capturedTimeZoneIdentifier: String
    public var note: String?
    public var sensitivity: DataSensitivity
    public var permitsHomeDisplay: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        kind: LifeMomentKind,
        eventDate: Date,
        recurrenceRule: LifeMomentRecurrenceRule = .none,
        capturedTimeZone: TimeZone = .autoupdatingCurrent,
        note: String? = nil,
        sensitivity: DataSensitivity = .privateStandard,
        permitsHomeDisplay: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        guard let title = title.lifeMomentTrimmed else { throw LifeMomentRepositoryError.invalidTitle }
        self.id = id
        self.title = title
        self.kind = kind
        self.eventDate = eventDate
        self.recurrenceRule = recurrenceRule.sanitized
        capturedTimeZoneIdentifier = capturedTimeZone.identifier
        self.note = note?.lifeMomentTrimmed
        self.sensitivity = sensitivity
        self.permitsHomeDisplay = permitsHomeDisplay
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }

    public var capturedTimeZone: TimeZone {
        TimeZone(identifier: capturedTimeZoneIdentifier) ?? .autoupdatingCurrent
    }

    /// Recurrence is expanded on demand; occurrence rows are never persisted.
    public func nextOccurrence(onOrAfter date: Date) -> Date? {
        if eventDate >= date { return eventDate }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = capturedTimeZone

        switch recurrenceRule {
        case .none:
            return nil
        case .weekly:
            let components = calendar.dateComponents([.weekday, .hour, .minute, .second], from: eventDate)
            return calendar.nextDate(after: date.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime)
        case .monthly:
            let components = calendar.dateComponents([.day, .hour, .minute, .second], from: eventDate)
            return calendar.nextDate(after: date.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime)
        case .yearly:
            let components = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: eventDate)
            return calendar.nextDate(after: date.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime)
        case .everyDays(let interval):
            let elapsedDays = max(0, calendar.dateComponents([.day], from: eventDate, to: date).day ?? 0)
            let completedIntervals = elapsedDays / max(1, interval)
            var candidate = calendar.date(
                byAdding: .day,
                value: completedIntervals * max(1, interval),
                to: eventDate
            ) ?? eventDate
            if candidate < date {
                candidate = calendar.date(byAdding: .day, value: max(1, interval), to: candidate) ?? candidate
            }
            return candidate
        }
    }

    public func calendarDaysUntilNextOccurrence(from date: Date) -> Int? {
        guard let occurrence = nextOccurrence(onOrAfter: date) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = capturedTimeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: occurrence)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}

public enum LifeMomentRepositoryError: LocalizedError, Equatable, Sendable {
    case invalidTitle
    case notFound

    public var errorDescription: String? {
        switch self {
        case .invalidTitle: "Add a short name for this moment."
        case .notFound: "That moment is no longer available."
        }
    }
}

public protocol LifeMomentRepository: Sendable {
    func moments(includeArchived: Bool) async throws -> [LifeMoment]
    func moment(id: UUID) async throws -> LifeMoment?
    func save(_ moment: LifeMoment) async throws
    func archive(id: UUID, at date: Date) async throws
    func delete(id: UUID) async throws
}

public actor InMemoryLifeMomentRepository: LifeMomentRepository {
    private var values: [UUID: LifeMoment]

    public init(values: [LifeMoment] = []) {
        self.values = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
    }

    public func moments(includeArchived: Bool = false) -> [LifeMoment] {
        values.values
            .filter { includeArchived || !$0.isArchived }
            .sorted {
                if $0.eventDate != $1.eventDate { return $0.eventDate < $1.eventDate }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    public func moment(id: UUID) -> LifeMoment? { values[id] }

    public func save(_ moment: LifeMoment) { values[moment.id] = moment }

    public func archive(id: UUID, at date: Date = Date()) throws {
        guard var value = values[id] else { throw LifeMomentRepositoryError.notFound }
        value.isArchived = true
        value.updatedAt = max(date, value.createdAt)
        values[id] = value
    }

    public func delete(id: UUID) throws {
        guard values.removeValue(forKey: id) != nil else { throw LifeMomentRepositoryError.notFound }
    }
}

public struct LifeMomentHomeCardProvider: HomeCardProvider {
    public let definition: HomeCardDefinition
    public let primaryDestination = LifeBoardDestination.insights
    public let privacyClassification: DataSensitivity

    private let repository: any LifeMomentRepository
    private let momentID: UUID

    public init(
        definition: HomeCardDefinition,
        momentID: UUID,
        sensitivity: DataSensitivity,
        repository: any LifeMomentRepository
    ) {
        self.definition = definition
        self.momentID = momentID
        privacyClassification = sensitivity
        self.repository = repository
    }

    public func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        guard let moment = try? await repository.moment(id: momentID),
              !moment.isArchived else {
            return .init(
                availability: .unavailable,
                title: definition.title,
                detail: "This moment is no longer available. You can remove this card in Home Edit.",
                updatedAt: date
            )
        }
        guard moment.permitsHomeDisplay else {
            return .init(
                availability: .redacted,
                title: definition.title,
                detail: "Open this moment to allow its date on Home.",
                updatedAt: date
            )
        }
        guard let occurrence = moment.nextOccurrence(onOrAfter: date),
              let days = moment.calendarDaysUntilNextOccurrence(from: date) else {
            return .init(
                availability: .empty,
                title: moment.title,
                detail: "This moment has passed. Archive it or choose a new date.",
                actions: inlineActions,
                updatedAt: moment.updatedAt
            )
        }

        let value = days == 0 ? "Today" : days == 1 ? "Tomorrow" : "\(days) days"
        let detail: String? = switch size {
        case .compact: nil
        case .standard, .wide: occurrence.formatted(date: .abbreviated, time: .omitted)
        case .tall, .expanded:
            moment.note ?? "A meaningful date you chose to keep close."
        }
        return .init(
            availability: .ready,
            title: moment.title,
            value: value,
            detail: detail,
            actions: inlineActions,
            updatedAt: moment.updatedAt
        )
    }
}

public struct LifeMomentContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "life-moments"
    private let repository: any LifeMomentRepository
    private let thresholdDays: Int

    public init(repository: any LifeMomentRepository, thresholdDays: Int = 7) {
        self.repository = repository
        self.thresholdDays = max(0, thresholdDays)
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        guard let moments = try? await repository.moments(includeArchived: false) else { return [] }
        return moments.compactMap { moment in
            guard moment.permitsHomeDisplay,
                  let days = moment.calendarDaysUntilNextOccurrence(from: context.date),
                  days <= thresholdDays,
                  let occurrence = moment.nextOccurrence(onOrAfter: context.date) else { return nil }
            let reason = days == 0
                ? "You asked to see this moment on its day."
                : "You asked to see this moment during its final week."
            return HomeContextCandidate(
                id: "life-moment:\(moment.id.uuidString)",
                widgetKind: .lifeMoment,
                title: moment.title,
                reason: .init(message: reason, signal: "lifeMomentThreshold"),
                destination: .insights,
                sensitivity: moment.sensitivity,
                priority: days == 0 ? 650 : 350 + (thresholdDays - days),
                relevantFrom: context.date,
                relevantUntil: occurrence.addingTimeInterval(24 * 60 * 60)
            )
        }
        .sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.id < $1.id
        }
    }
}

public struct LifeMomentsOverviewHomeCardProvider: HomeCardProvider {
    public let definition: HomeCardDefinition
    public let primaryDestination = LifeBoardDestination.insights
    public let privacyClassification = DataSensitivity.privateStandard
    private let repository: any LifeMomentRepository

    public init(definition: HomeCardDefinition, repository: any LifeMomentRepository) {
        self.definition = definition
        self.repository = repository
    }

    public func snapshot(configuration: HomeCardConfiguration, size: HomeCardSize, at date: Date) async -> HomeCardSnapshot {
        guard let moments = try? await repository.moments(includeArchived: false) else {
            return .init(availability: .degraded, title: definition.title, detail: "Moments are unavailable right now. Your Home layout is unchanged.", updatedAt: date)
        }
        guard let moment = moments.filter(\.permitsHomeDisplay).compactMap({ value -> (LifeMoment, Int)? in
            value.calendarDaysUntilNextOccurrence(from: date).map { (value, $0) }
        }).sorted(by: { $0.1 < $1.1 }).first else {
            return .init(availability: .redacted, title: definition.title, detail: "Choose a moment and allow its date on Home.", actions: inlineActions, updatedAt: date)
        }
        let value = moment.1 == 0 ? "Today" : moment.1 == 1 ? "Tomorrow" : "\(moment.1) days"
        return .init(availability: .ready, title: moment.0.title, value: value, detail: size == .compact ? nil : moment.0.eventDate.formatted(date: .abbreviated, time: .omitted), actions: inlineActions, updatedAt: moment.0.updatedAt)
    }
}

private extension String {
    var lifeMomentTrimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

import Foundation

public enum OccurrenceState: String, Codable {
    case pending
    case completed
    case skipped
    case missed
}

public enum OccurrenceResolutionType: String, Codable {
    case completed
    case skipped
    case missed
    case deferred
}

public enum OccurrenceActor: String, Codable {
    case user
    case system
    case assistant
}

public struct OccurrenceDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var occurrenceKey: String
    public var scheduleTemplateID: UUID
    public var sourceType: ScheduleSourceType
    public var sourceID: UUID
    public var scheduledAt: Date
    public var dueAt: Date?
    public var state: OccurrenceState
    public var isGenerated: Bool
    public var generationWindow: String?
    public var createdAt: Date
    public var updatedAt: Date
}

public struct OccurrenceResolutionDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var occurrenceID: UUID
    public var resolutionType: OccurrenceResolutionType
    public var resolvedAt: Date
    public var actor: String
    public var reason: String?
    public var createdAt: Date
}

public struct ParsedOccurrenceKey: Codable, Equatable, Hashable {
    public var scheduleTemplateID: UUID
    public var scheduledAt: Date
    public var sourceID: UUID?
    public var isCanonical: Bool

    public init(
        scheduleTemplateID: UUID,
        scheduledAt: Date,
        sourceID: UUID?,
        isCanonical: Bool
    ) {
        self.scheduleTemplateID = scheduleTemplateID
        self.scheduledAt = scheduledAt
        self.sourceID = sourceID
        self.isCanonical = isCanonical
    }
}

public enum OccurrenceKeyCodec {
    public static func encode(
        scheduleTemplateID: UUID,
        scheduledAt: Date,
        sourceID: UUID
    ) -> String {
        "\(scheduleTemplateID.uuidString)|\(isoFormatter.string(from: scheduledAt))|\(sourceID.uuidString)"
    }

    public static func parse(_ rawValue: String) -> ParsedOccurrenceKey? {
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty == false else { return nil }

        let segments = key.split(separator: "|")
        if segments.count >= 3,
           let templateID = UUID(uuidString: String(segments[0])),
           let scheduledAt = isoFormatter.date(from: String(segments[1])),
           let sourceID = UUID(uuidString: String(segments[2])) {
            return ParsedOccurrenceKey(
                scheduleTemplateID: templateID,
                scheduledAt: scheduledAt,
                sourceID: sourceID,
                isCanonical: true
            )
        }

        // Backward compatibility: <template_uuid>_<yyyy-MM-dd'T'HH:mm>
        let legacyComponents = key.split(separator: "_")
        if legacyComponents.count >= 2,
           let templateID = UUID(uuidString: String(legacyComponents[0])),
           let scheduledAt = legacyFormatter.date(from: String(legacyComponents[1])) {
            return ParsedOccurrenceKey(
                scheduleTemplateID: templateID,
                scheduledAt: scheduledAt,
                sourceID: nil,
                isCanonical: false
            )
        }

        return nil
    }

    public static func canonicalize(
        _ rawValue: String,
        fallbackTemplateID: UUID?,
        fallbackSourceID: UUID?
    ) -> String? {
        guard let parsed = parse(rawValue) else { return nil }
        let scheduleTemplateID = fallbackTemplateID ?? parsed.scheduleTemplateID
        guard let sourceID = parsed.sourceID ?? fallbackSourceID else {
            return nil
        }
        return encode(
            scheduleTemplateID: scheduleTemplateID,
            scheduledAt: parsed.scheduledAt,
            sourceID: sourceID
        )
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let legacyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

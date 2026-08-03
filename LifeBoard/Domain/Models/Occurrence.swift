import Foundation
import CryptoKit

/// Stable identity shared by app, widget, Watch, reminders, and history.
/// Swift's `Hasher` is intentionally randomized per process, so occurrence
/// UUIDs must be derived from a cryptographic digest of canonical inputs.
public enum BehaviorOccurrenceIdentity {
    public static func make(
        behaviorID: UUID,
        canonicalOccurrenceKey: String,
        timezoneID: String,
        sequence: Int = 0
    ) -> UUID {
        let seed = [
            behaviorID.uuidString.lowercased(),
            canonicalOccurrenceKey,
            timezoneID,
            String(max(0, sequence))
        ].joined(separator: "\u{1F}")
        var bytes = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        // RFC 4122 variant with a version-5 marker communicates name-derived
        // identity even though SHA-256 replaces SHA-1 internally.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

public enum OccurrenceState: String, Codable, Sendable {
    case pending
    case completed
    case skipped
    case missed
    case failed
}

public enum OccurrenceResolutionType: String, Codable, Sendable {
    case completed
    case skipped
    case missed
    case deferred
    case lapsed
}

/// A cross-surface result vocabulary. In particular, `.missing` and
/// `.explicitZero` are never interchangeable.
public enum BehaviorOccurrenceResultState: String, Codable, CaseIterable, Hashable, Sendable {
    case missing
    case explicitZero
    case completed
    case skipped
    case offDay
    case paused
    case failed
    case unresolved
}

public enum OccurrenceActor: String, Codable, Sendable {
    case user
    case system
    case assistant
}

public struct OccurrenceDefinition: Codable, Equatable, Hashable, Sendable {
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

public struct OccurrenceResolutionDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var occurrenceID: UUID
    public var resolutionType: OccurrenceResolutionType
    public var resolvedAt: Date
    public var actor: String
    public var reason: String?
    public var createdAt: Date
}

public struct ParsedOccurrenceKey: Codable, Equatable, Hashable, Sendable {
    public var scheduleTemplateID: UUID
    public var scheduledAt: Date
    public var sourceID: UUID?
    public var isCanonical: Bool

    /// Initializes a new instance.
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
    /// Executes encode.
    public static func encode(
        scheduleTemplateID: UUID,
        scheduledAt: Date,
        sourceID: UUID
    ) -> String {
        "\(scheduleTemplateID.uuidString)|\(makeISOFormatter().string(from: scheduledAt))|\(sourceID.uuidString)"
    }

    /// Executes parse.
    public static func parse(_ rawValue: String) -> ParsedOccurrenceKey? {
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty == false else { return nil }

        let segments = key.split(separator: "|")
        if segments.count >= 3,
           let templateID = UUID(uuidString: String(segments[0])),
           let scheduledAt = makeISOFormatter().date(from: String(segments[1])),
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
           let scheduledAt = makeLegacyFormatter().date(from: String(legacyComponents[1])) {
            return ParsedOccurrenceKey(
                scheduleTemplateID: templateID,
                scheduledAt: scheduledAt,
                sourceID: nil,
                isCanonical: false
            )
        }

        return nil
    }

    /// Executes canonicalize.
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

    private static func makeISOFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static func makeLegacyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

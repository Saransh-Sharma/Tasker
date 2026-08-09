//
//  WatchCaptureModels.swift
//  WatchCaptureKit
//
//  The phone/watch capture contract: envelopes, receipts, outbox policy,
//  and audio manifests. WCSession pairs per app, so the userInfo keys are
//  namespace-stable and never cross apps.
//

import Foundation

public enum WatchCaptureKind: String, Codable, CaseIterable, Sendable {
    case mood
    case speak
    case audio
}

public enum WatchSyncState: String, Codable, Sendable {
    case saved
    case queued
    case sending
    case synced
    case failed
}

/// Host-neutral recovery states for captures that reached the phone but could
/// not yet be committed. Hosts persist these records in their own protected
/// container; the shared package deliberately owns no storage location.
public enum WatchCaptureRecoveryReason: String, Codable, CaseIterable, Sendable {
    case awaitingAudio
    case protectedDataUnavailable
    case persistenceUnavailable
    case unsupportedSchema
    case malformedPayload
}

public struct WatchCaptureRecoveryRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var captureID: UUID?
    public var reason: WatchCaptureRecoveryReason
    public var receivedAtUTC: Date
    public var lastAttemptAtUTC: Date?
    public var attemptCount: Int
    public var envelope: WatchCaptureEnvelope?
    public var protectedPayload: Data?

    public init(
        id: UUID = UUID(),
        captureID: UUID? = nil,
        reason: WatchCaptureRecoveryReason,
        receivedAtUTC: Date = Date(),
        lastAttemptAtUTC: Date? = nil,
        attemptCount: Int = 0,
        envelope: WatchCaptureEnvelope? = nil,
        protectedPayload: Data? = nil
    ) {
        self.id = id
        self.captureID = captureID ?? envelope?.captureID
        self.reason = reason
        self.receivedAtUTC = receivedAtUTC
        self.lastAttemptAtUTC = lastAttemptAtUTC
        self.attemptCount = attemptCount
        self.envelope = envelope
        self.protectedPayload = protectedPayload
    }

    public var isRetryable: Bool {
        switch reason {
        case .awaitingAudio, .protectedDataUnavailable, .persistenceUnavailable:
            return true
        case .unsupportedSchema, .malformedPayload:
            return false
        }
    }
}

public enum WatchTransferKind: String, Codable, Sendable {
    case metadata
    case audioFile
}

public enum WatchCaptureSourceSurface: String, Codable, Sendable {
    case app
    case complication
    case smartStack
}

public enum WatchSpeechTruthState: String, Codable, Sendable {
    case transcriptOnWatchNow = "Transcript on watch now"
    case transcriptOnIPhoneLater = "Transcript on iPhone later"
    case audioOnly = "Audio only"
}

/// Namespaces the WatchConnectivity dictionary keys for each host app while
/// keeping the wire payload itself shared and versioned by JournalKit.
public struct WatchCaptureTransportNamespace: Codable, Hashable, Sendable {
    public static let offRecord = Self(rawValue: "offrecord")
    public static let lifeBoard = Self(rawValue: "lifeboard")

    public let rawValue: String

    public init(rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.rawValue = normalized.isEmpty ? "journal" : normalized
    }

    public var capturePayloadKey: String { "\(rawValue).watchCapture.payload" }
    public var captureKindKey: String { "\(rawValue).watchCapture.kind" }
    public var captureIDKey: String { "\(rawValue).watchCapture.captureID" }
    public var receiptPayloadKey: String { "\(rawValue).watchCapture.receipt" }
    public var receiptCaptureIDKey: String { "\(rawValue).watchCapture.receipt.captureID" }
}

public struct WatchRecentCapture: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID { envelope.captureID }
    public var envelope: WatchCaptureEnvelope
    public var syncState: WatchSyncState
    public var transferKind: WatchTransferKind
    public var attemptCount: Int
    public var lastAttemptAtUTC: Date?
    public var nextAttemptAtUTC: Date?
    public var lastError: String?
    public var audioFileMissing: Bool
    public var updatedAtUTC: Date

    public init(
        envelope: WatchCaptureEnvelope,
        syncState: WatchSyncState,
        transferKind: WatchTransferKind,
        attemptCount: Int = 0,
        lastAttemptAtUTC: Date? = nil,
        nextAttemptAtUTC: Date? = nil,
        lastError: String? = nil,
        audioFileMissing: Bool = false,
        updatedAtUTC: Date
    ) {
        self.envelope = envelope
        self.syncState = syncState
        self.transferKind = transferKind
        self.attemptCount = attemptCount
        self.lastAttemptAtUTC = lastAttemptAtUTC
        self.nextAttemptAtUTC = nextAttemptAtUTC
        self.lastError = lastError
        self.audioFileMissing = audioFileMissing
        self.updatedAtUTC = updatedAtUTC
    }

    private enum CodingKeys: String, CodingKey {
        case envelope
        case syncState
        case transferKind
        case attemptCount
        case lastAttemptAtUTC
        case nextAttemptAtUTC
        case lastError
        case audioFileMissing
        case updatedAtUTC
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        envelope = try container.decode(WatchCaptureEnvelope.self, forKey: .envelope)
        syncState = try container.decode(WatchSyncState.self, forKey: .syncState)
        transferKind = try container.decodeIfPresent(WatchTransferKind.self, forKey: .transferKind)
            ?? (envelope.kind == .audio ? .audioFile : .metadata)
        attemptCount = try container.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0
        lastAttemptAtUTC = try container.decodeIfPresent(Date.self, forKey: .lastAttemptAtUTC)
        nextAttemptAtUTC = try container.decodeIfPresent(Date.self, forKey: .nextAttemptAtUTC)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        audioFileMissing = try container.decodeIfPresent(Bool.self, forKey: .audioFileMissing) ?? false
        updatedAtUTC = try container.decode(Date.self, forKey: .updatedAtUTC)
    }

    public var title: String {
        switch envelope.kind {
        case .mood:
            return "Mood"
        case .speak:
            return "Thought"
        case .audio:
            return "Raw voice"
        }
    }

    public var statusText: String {
        switch syncState {
        case .saved: return "Saved on watch"
        case .queued: return "Held for later"
        case .sending: return "Sending"
        case .synced: return "On your iPhone"
        case .failed: return lastError ?? "Retry"
        }
    }
}

public enum WatchCaptureQueuePolicy {
    public static let recentLimit = 20
    public static let staleSendingInterval: TimeInterval = 120

    public static func recentProjection(from outbox: [WatchRecentCapture]) -> [WatchRecentCapture] {
        Array(outbox.sorted { $0.updatedAtUTC > $1.updatedAtUTC }.prefix(recentLimit))
    }

    public static func shouldAttemptTransfer(_ item: WatchRecentCapture, now: Date) -> Bool {
        guard item.syncState != .synced, !item.audioFileMissing else { return false }
        if item.syncState == .sending,
           let lastAttempt = item.lastAttemptAtUTC,
           now.timeIntervalSince(lastAttempt) < staleSendingInterval {
            return false
        }
        if let nextAttempt = item.nextAttemptAtUTC, nextAttempt > now {
            return false
        }
        return true
    }

    public static func backoffDelay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = max(0, min(attempt - 1, 7))
        return min(15 * pow(2, Double(exponent)), 30 * 60)
    }
}

public struct WatchAudioManifest: Codable, Hashable, Sendable {
    public var audioAssetID: UUID
    public var captureID: UUID
    public var fileName: String
    public var duration: TimeInterval
    public var codec: String
    public var sampleRateHz: Int
    public var bitRate: Int
    public var byteCount: Int64
    public var createdAtUTC: Date

    public init(
        audioAssetID: UUID = UUID(),
        captureID: UUID,
        fileName: String,
        duration: TimeInterval,
        codec: String = "aac-lc",
        sampleRateHz: Int = 24_000,
        bitRate: Int = 64_000,
        byteCount: Int64,
        createdAtUTC: Date = Date()
    ) {
        self.audioAssetID = audioAssetID
        self.captureID = captureID
        self.fileName = fileName
        self.duration = duration
        self.codec = codec
        self.sampleRateHz = sampleRateHz
        self.bitRate = bitRate
        self.byteCount = byteCount
        self.createdAtUTC = createdAtUTC
    }
}

public struct WatchCaptureEnvelope: Codable, Identifiable, Hashable, Sendable {
    public static let schemaVersion = 1
    public static let userInfoPayloadKey = WatchCaptureTransportNamespace.offRecord.capturePayloadKey
    public static let userInfoKindKey = WatchCaptureTransportNamespace.offRecord.captureKindKey
    public static let userInfoCaptureIDKey = WatchCaptureTransportNamespace.offRecord.captureIDKey

    public var id: UUID { captureID }

    public var captureID: UUID
    public var schemaVersion: Int
    public var kind: WatchCaptureKind
    public var createdAtUTC: Date
    public var sourceSurface: WatchCaptureSourceSurface
    public var privacyMode: String
    public var moodValue: String?
    public var text: String?
    public var textPreview: String?
    public var speechTruthState: WatchSpeechTruthState?
    public var audioManifest: WatchAudioManifest?

    public init(
        captureID: UUID = UUID(),
        schemaVersion: Int = Self.schemaVersion,
        kind: WatchCaptureKind,
        createdAtUTC: Date = Date(),
        sourceSurface: WatchCaptureSourceSurface = .app,
        privacyMode: String = "private",
        moodValue: String? = nil,
        text: String? = nil,
        textPreview: String? = nil,
        speechTruthState: WatchSpeechTruthState? = nil,
        audioManifest: WatchAudioManifest? = nil
    ) {
        self.captureID = captureID
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.createdAtUTC = createdAtUTC
        self.sourceSurface = sourceSurface
        self.privacyMode = privacyMode
        self.moodValue = moodValue
        self.text = text
        self.textPreview = textPreview
        self.speechTruthState = speechTruthState
        self.audioManifest = audioManifest
    }

    public var privacySafePreview: String {
        switch kind {
        case .mood:
            return moodValue ?? "Mood"
        case .speak:
            return textPreview?.isEmpty == false ? textPreview! : "Dictated thought"
        case .audio:
            if let duration = audioManifest?.duration {
                return "Audio \(Self.durationFormatter.string(from: duration) ?? "")"
            }
            return "Audio note"
        }
    }

    public func userInfoPayload(
        namespace: WatchCaptureTransportNamespace = .offRecord
    ) throws -> [String: Any] {
        [
            namespace.capturePayloadKey: try JSONEncoder.watchCapture.encode(self),
            namespace.captureKindKey: kind.rawValue,
            namespace.captureIDKey: captureID.uuidString
        ]
    }

    public static func decoded(
        from userInfo: [String: Any],
        namespace: WatchCaptureTransportNamespace = .offRecord,
        acceptingLegacyNamespaces: [WatchCaptureTransportNamespace] = [.offRecord]
    ) throws -> WatchCaptureEnvelope {
        let namespaces = [namespace] + acceptingLegacyNamespaces.filter { $0 != namespace }
        guard let data = namespaces.lazy.compactMap({ userInfo[$0.capturePayloadKey] as? Data }).first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Missing watch capture payload")
            )
        }
        return try JSONDecoder.watchCapture.decode(WatchCaptureEnvelope.self, from: data)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

public struct WatchCaptureReceipt: Codable, Hashable, Sendable {
    public static let userInfoPayloadKey = WatchCaptureTransportNamespace.offRecord.receiptPayloadKey
    public static let userInfoCaptureIDKey = WatchCaptureTransportNamespace.offRecord.receiptCaptureIDKey

    public var captureID: UUID
    public var importedEntryID: UUID
    public var importedAtUTC: Date
    public var kind: WatchCaptureKind

    public init(
        captureID: UUID,
        importedEntryID: UUID,
        importedAtUTC: Date = Date(),
        kind: WatchCaptureKind
    ) {
        self.captureID = captureID
        self.importedEntryID = importedEntryID
        self.importedAtUTC = importedAtUTC
        self.kind = kind
    }

    public func userInfoPayload(
        namespace: WatchCaptureTransportNamespace = .offRecord
    ) throws -> [String: Any] {
        [
            namespace.receiptPayloadKey: try JSONEncoder.watchCapture.encode(self),
            namespace.receiptCaptureIDKey: captureID.uuidString
        ]
    }

    public static func decoded(
        from userInfo: [String: Any],
        namespace: WatchCaptureTransportNamespace = .offRecord,
        acceptingLegacyNamespaces: [WatchCaptureTransportNamespace] = [.offRecord]
    ) throws -> WatchCaptureReceipt {
        let namespaces = [namespace] + acceptingLegacyNamespaces.filter { $0 != namespace }
        guard let data = namespaces.lazy.compactMap({ userInfo[$0.receiptPayloadKey] as? Data }).first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Missing watch import receipt payload")
            )
        }
        return try JSONDecoder.watchCapture.decode(WatchCaptureReceipt.self, from: data)
    }
}

public extension JSONEncoder {
    static var watchCapture: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var watchCapture: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

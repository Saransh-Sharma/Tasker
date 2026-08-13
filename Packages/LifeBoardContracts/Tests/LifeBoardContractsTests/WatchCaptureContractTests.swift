import Foundation
import Testing
@testable import LifeBoardContracts

struct WatchCaptureTransportTests {
    @Test func encodedEnvelopeMatchesFrozenWireFixture() throws {
        let envelope = WatchCaptureEnvelope(
            captureID: UUID(uuidString: "A5000000-0000-0000-0000-000000000001")!,
            kind: .speak,
            createdAtUTC: Date(timeIntervalSince1970: 1_700_000_000),
            sourceSurface: .complication,
            text: "A thought",
            textPreview: "A thought",
            speechTruthState: .transcriptOnWatchNow
        )

        let encoded = try JSONEncoder.watchCapture.encode(envelope)
        #expect(try normalizedJSON(encoded) == """
        {"captureID":"A5000000-0000-0000-0000-000000000001","createdAtUTC":"2023-11-14T22:13:20Z","kind":"speak","privacyMode":"private","schemaVersion":1,"sourceSurface":"complication","speechTruthState":"Transcript on watch now","text":"A thought","textPreview":"A thought"}
        """)
    }

    @Test func lifeBoardNamespaceRoundTripsWithoutLegacyKeys() throws {
        let envelope = WatchCaptureEnvelope(
            captureID: UUID(uuidString: "A5000000-0000-0000-0000-000000000001")!,
            kind: .speak,
            createdAtUTC: Date(timeIntervalSince1970: 1_700_000_000),
            sourceSurface: .complication,
            text: "A thought",
            textPreview: "A thought",
            speechTruthState: .transcriptOnWatchNow
        )

        let payload = try envelope.userInfoPayload(namespace: .lifeBoard)
        #expect(payload[WatchCaptureTransportNamespace.lifeBoard.capturePayloadKey] != nil)
        #expect(payload[WatchCaptureTransportNamespace.offRecord.capturePayloadKey] == nil)
        #expect(try WatchCaptureEnvelope.decoded(from: payload, namespace: .lifeBoard) == envelope)
    }

    @Test func lifeBoardImporterAcceptsLegacyPayloadDuringMigration() throws {
        let envelope = WatchCaptureEnvelope(
            kind: .mood,
            createdAtUTC: Date(timeIntervalSince1970: 1_700_000_000),
            moodValue: "calm"
        )
        let legacyPayload = try envelope.userInfoPayload()

        let imported = try WatchCaptureEnvelope.decoded(
            from: legacyPayload,
            namespace: .lifeBoard,
            acceptingLegacyNamespaces: [.offRecord]
        )
        #expect(imported == envelope)
    }

    @Test func queueBackoffAndRecoveryPolicyRemainFrozen() {
        let envelope = WatchCaptureEnvelope(kind: .audio)
        #expect(WatchCaptureRecoveryRecord(reason: .awaitingAudio, envelope: envelope).isRetryable)
        #expect(!WatchCaptureRecoveryRecord(reason: .unsupportedSchema, envelope: envelope).isRetryable)
        #expect(WatchCaptureQueuePolicy.backoffDelay(forAttempt: 1) == 15)
        #expect(WatchCaptureQueuePolicy.backoffDelay(forAttempt: 99) == 1_800)
    }

    private func normalizedJSON(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: normalized, as: UTF8.self)
    }
}

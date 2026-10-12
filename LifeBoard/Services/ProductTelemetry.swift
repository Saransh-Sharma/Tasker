import Foundation

struct ProductEventV1: Codable, Sendable {
    enum Name: String, Codable, Sendable, CaseIterable {
        case onboardingPresented
        case onboardingStepViewed
        case onboardingStepCompleted
        case onboardingBack
        case onboardingDeferred
        case firstCaptureInterpreted
        case firstCaptureConfirmed
        case firstCaptureFailed
        case firstCaptureSkipped
        case commitStarted
        case commitCompleted
        case commitFailed
        case revealViewed
        case coreFinalized
        case refreshPresented
        case refreshCompleted
        case refreshDeferred
        case setupCenterOpened
        case setupCenterDismissed
        case connectionInvitationShown
        case connectionInvitationDeclined
        case healthDataFirstObserved
        case connectorResult
        case evaActivationStarted
        case evaActivationSucceeded
        case evaActivationFailed
        case evaActivationDismissed
        case memoryProposalShown
        case memoryProposalSaved
        case memoryProposalEdited
        case memoryProposalDeferred
        case memoryProposalDismissed
        case contextReceiptOpened
        case contextSourceExcluded
        case contextSourceRestored
        case contextConsentChanged
        case evaActivationReviewConfirmed
        case evaGuestBootstrapStarted
        case evaGuestBootstrapSucceeded
        case evaGuestBootstrapFailed
        case evaFirstPromptSent
        case evaFirstAnswerCompleted
        case evaAppleLinkStarted
        case evaAppleLinkSucceeded
        case evaAppleLinkFailed
        case evaQuotaExhausted
        case evaTrustTierObserved
        case evaReadinessHydrated
        case evaSessionRestored
        case evaSessionRefreshed
        case evaSessionMigrated
        case evaSessionStorageDeferred
        case evaGuestSessionRecovered
        case evaAppleReauthenticationRequired
        case evaInlineActivationShown
        case evaActivationAutoResumed
        case evaActivationAndSendCompleted
        case evaSetupCenterCTAShown
    }

    let name: Name
    let timestamp: Date
    let flowVersion: Int?
    let audience: String?
    let outcome: String?
    let errorCode: String?
    let count: Int?
    let durationBucket: String?
}

extension ProductEventV1.Name {
    /// Names the server's allow-list (`Services/EVACloud/src/routes/product-events.ts`)
    /// does not have yet. The server checks a batch as a whole, so one unknown
    /// name rejects every event sent with it. These stay off the queue until a
    /// Worker deploy adds them; then they leave this set.
    /// `ProductTelemetryContractTests` fails in either direction if this drifts.
    static let awaitingServerSupport: Set<ProductEventV1.Name> = [
        .connectionInvitationShown,
        .connectionInvitationDeclined,
        .healthDataFirstObserved,
        .evaReadinessHydrated,
        .evaInlineActivationShown,
        .evaActivationAutoResumed,
        .evaActivationAndSendCompleted,
        .evaSetupCenterCTAShown,
    ]

    var isAcceptedByServer: Bool { Self.awaitingServerSupport.contains(self) == false }
}

extension ProductEventV1 {
    /// `ProductEventSchema`'s duration buckets.
    static let durationBuckets: Set<String> = ["under_1s", "1_3s", "3_10s", "10_30s", "over_30s"]

    /// The event with every optional field inside the server's rules. A field
    /// outside them fails the whole batch, so it is dropped (or clamped, for
    /// counts) here instead of being sent.
    func conformingToServerSchema() -> ProductEventV1 {
        ProductEventV1(
            name: name,
            timestamp: timestamp,
            flowVersion: flowVersion.flatMap { (1...100).contains($0) ? $0 : nil },
            audience: Self.token(audience, maximumLength: 40),
            outcome: Self.token(outcome, maximumLength: 40),
            errorCode: Self.token(errorCode, maximumLength: 80, alsoAllowing: ["."]),
            count: count.map { min(max($0, 0), 100_000) },
            durationBucket: durationBucket.flatMap { Self.durationBuckets.contains($0) ? $0 : nil }
        )
    }

    /// `^[a-zA-Z0-9_-]{1,max}$`, plus any extra characters the field allows.
    private static func token(_ value: String?, maximumLength: Int, alsoAllowing extra: Set<Character> = []) -> String? {
        guard let value, (1...maximumLength).contains(value.count) else { return nil }
        let allowed = value.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "_" || character == "-" || extra.contains(character))
        }
        return allowed ? value : nil
    }
}

actor ProductTelemetry {
    static let shared = ProductTelemetry()
    static let enabledKey = "productTelemetry.enabled"

    private struct Batch: Encodable {
        let schemaVersion = 1
        let installationId: UUID
        let events: [ProductEventV1]
    }

    private static let pendingStorageKey = "productTelemetry.pending.v1"
    /// How many unsent events survive on disk. Was 32, and a failed send
    /// re-queued only 32, so a few offline days silently lost most of the
    /// onboarding funnel. Oldest events are dropped first.
    static let maximumPendingEvents = 200
    /// The server's `maxItems` for one batch. A bigger batch is rejected whole,
    /// and because failed batches are kept, a queue past this size never drained.
    static let maximumBatchEvents = 32
    private static let immediateFlushEvents: Set<ProductEventV1.Name> = [
        .evaActivationReviewConfirmed,
        .evaGuestBootstrapSucceeded,
        .evaGuestBootstrapFailed,
        .evaFirstPromptSent,
        .evaFirstAnswerCompleted,
        .evaAppleLinkSucceeded,
        .evaAppleLinkFailed,
        .evaQuotaExhausted,
        .evaTrustTierObserved,
        .evaActivationAutoResumed,
        .evaActivationAndSendCompleted,
    ]

    private var pending: [ProductEventV1]
    private var isFlushing = false

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.pendingStorageKey),
           let restored = try? JSONDecoder().decode([ProductEventV1].self, from: data) {
            // Queues saved by earlier builds can hold names or values the
            // server rejects; left in place they would block every later event.
            pending = Array(Self.sendable(restored).suffix(Self.maximumPendingEvents))
        } else {
            pending = []
        }
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue == false { Task { await shared.discardPending() } }
        }
    }

    func record(
        _ name: ProductEventV1.Name,
        flowVersion: Int? = nil,
        audience: String? = nil,
        outcome: String? = nil,
        errorCode: String? = nil,
        count: Int? = nil,
        durationBucket: String? = nil
    ) async {
        guard Self.isEnabled, AppRuntimeConfigurationStore.current.productEventsEnabled else { return }
        guard name.isAcceptedByServer else { return }
        pending.append(ProductEventV1(
            name: name,
            timestamp: Date(),
            flowVersion: flowVersion,
            audience: audience,
            outcome: outcome,
            errorCode: errorCode,
            count: count,
            durationBucket: durationBucket
        ).conformingToServerSchema())
        if pending.count > Self.maximumPendingEvents {
            pending.removeFirst(pending.count - Self.maximumPendingEvents)
        }
        persistPending()
        if pending.count >= 8 || Self.immediateFlushEvents.contains(name) {
            Task { await self.flush() }
        }
    }

    /// Sends what is queued, oldest first, at most `maximumBatchEvents` per
    /// request. Events stay on disk until the server accepts them: the old
    /// flush cleared the queue *before* sending, so a crash or a kill
    /// mid-request lost the batch outright.
    func flush() async {
        guard Self.isEnabled,
              AppRuntimeConfigurationStore.current.productEventsEnabled,
              isFlushing == false,
              pending.isEmpty == false else { return }
        isFlushing = true
        defer { isFlushing = false }
        while let events = Self.nextBatch(from: pending) {
            do {
                let batch = Batch(installationId: Self.rotatingInstallationID(), events: events)
                _ = try await EvaCloudTransport.shared.send(
                    path: "/v1/product-events",
                    method: "POST",
                    body: JSONEncoder.evaCloud.encode(batch),
                    authenticated: false,
                    attested: false
                )
                removeSentPrefix(events.count)
            } catch let envelope as EvaErrorEnvelope where envelope.code == Self.permanentRejectionCode {
                // The server will never accept this batch. Keeping it would
                // block every event behind it, which is how the queue jammed.
                removeSentPrefix(events.count)
            } catch {
                // Kept for the next flush, bounded, oldest dropped first.
                if pending.count > Self.maximumPendingEvents {
                    pending = Array(pending.suffix(Self.maximumPendingEvents))
                }
                persistPending()
                return
            }
        }
    }

    /// The error code the server returns when a body fails its contract.
    static let permanentRejectionCode = "schema_invalid"

    /// The oldest events, no more than the server accepts in one request.
    static func nextBatch(from events: [ProductEventV1]) -> [ProductEventV1]? {
        events.isEmpty ? nil : Array(events.prefix(maximumBatchEvents))
    }

    /// Only what the server can accept, with every field inside its rules.
    static func sendable(_ events: [ProductEventV1]) -> [ProductEventV1] {
        events.filter { $0.name.isAcceptedByServer }.map { $0.conformingToServerSchema() }
    }

    /// Events recorded while a request was in flight were appended after it;
    /// only the sent prefix is removed. A consent withdrawal during the send
    /// has already emptied the queue.
    private func removeSentPrefix(_ count: Int) {
        if pending.count >= count {
            pending.removeFirst(count)
        } else {
            pending.removeAll()
        }
        persistPending()
    }

    private func discardPending() {
        pending.removeAll()
        persistPending()
    }

    private func persistPending(defaults: UserDefaults = .standard) {
        if pending.isEmpty {
            defaults.removeObject(forKey: Self.pendingStorageKey)
        } else if let data = try? JSONEncoder().encode(Array(pending.suffix(Self.maximumPendingEvents))) {
            defaults.set(data, forKey: Self.pendingStorageKey)
        }
    }

    private static func rotatingInstallationID(defaults: UserDefaults = .standard) -> UUID {
        let idKey = "productTelemetry.rotatingID"
        let dateKey = "productTelemetry.rotatingIDCreatedAt"
        let created = defaults.object(forKey: dateKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(created) < 30 * 24 * 60 * 60,
           let raw = defaults.string(forKey: idKey), let id = UUID(uuidString: raw) { return id }
        let replacement = UUID()
        defaults.set(replacement.uuidString, forKey: idKey)
        defaults.set(Date(), forKey: dateKey)
        return replacement
    }
}

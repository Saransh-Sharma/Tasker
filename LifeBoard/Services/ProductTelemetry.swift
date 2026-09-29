import Foundation

struct ProductEventV1: Codable, Sendable {
    enum Name: String, Codable, Sendable {
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
            pending = Array(restored.suffix(Self.maximumPendingEvents))
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
        pending.append(ProductEventV1(
            name: name,
            timestamp: Date(),
            flowVersion: flowVersion,
            audience: audience,
            outcome: outcome,
            errorCode: errorCode,
            count: count,
            durationBucket: durationBucket
        ))
        if pending.count > Self.maximumPendingEvents {
            pending.removeFirst(pending.count - Self.maximumPendingEvents)
        }
        persistPending()
        if pending.count >= 8 || Self.immediateFlushEvents.contains(name) {
            Task { await self.flush() }
        }
    }

    /// Sends what is queued. Events stay on disk until the server accepts
    /// them: the old flush cleared the queue *before* sending, so a crash or
    /// a kill mid-request lost the batch outright.
    func flush() async {
        guard Self.isEnabled,
              AppRuntimeConfigurationStore.current.productEventsEnabled,
              isFlushing == false,
              pending.isEmpty == false else { return }
        isFlushing = true
        defer { isFlushing = false }
        let events = pending
        do {
            let batch = Batch(installationId: Self.rotatingInstallationID(), events: events)
            _ = try await EvaCloudTransport.shared.send(
                path: "/v1/product-events",
                method: "POST",
                body: JSONEncoder.evaCloud.encode(batch),
                authenticated: false,
                attested: false
            )
            // Events recorded while the request was in flight were appended
            // after `events`; only the sent prefix is removed. A consent
            // withdrawal during the send has already emptied the queue.
            if pending.count >= events.count {
                pending.removeFirst(events.count)
            } else {
                pending.removeAll()
            }
            persistPending()
        } catch {
            // Kept for the next flush, bounded, oldest dropped first.
            if pending.count > Self.maximumPendingEvents {
                pending = Array(pending.suffix(Self.maximumPendingEvents))
            }
            persistPending()
        }
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

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

    private var pending: [ProductEventV1] = []

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
        if pending.count >= 8 { await flush() }
    }

    func flush() async {
        guard Self.isEnabled,
              AppRuntimeConfigurationStore.current.productEventsEnabled,
              pending.isEmpty == false else { return }
        let events = pending
        pending.removeAll()
        do {
            let batch = Batch(installationId: Self.rotatingInstallationID(), events: events)
            _ = try await EvaCloudTransport.shared.send(
                path: "/v1/product-events",
                method: "POST",
                body: JSONEncoder.evaCloud.encode(batch),
                authenticated: false,
                attested: false
            )
        } catch {
            if Self.isEnabled { pending.insert(contentsOf: events.prefix(32), at: 0) }
        }
    }

    private func discardPending() { pending.removeAll() }

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

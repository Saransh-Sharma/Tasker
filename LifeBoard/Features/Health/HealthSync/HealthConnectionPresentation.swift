import Foundation

/// What LifeBoard can honestly say about Apple Health during the first run.
///
/// HealthKit deliberately never reveals per-type *read* denial. Once the system
/// sheet returns, all we know is that it was presented — never that reading was
/// granted, and never that it was refused. So no case here means "connected" or
/// "denied"; every one of them describes what LifeBoard has actually observed.
///
/// `.reviewedNoDataYet` is therefore a correct, finished state rather than a
/// failure: a person can review the sheet on a phone that simply has no recent
/// Health data, and telling them "connected" would be a claim we cannot support.
enum HealthFirstSyncOutcome: Equatable {
    /// HealthKit is not present on this device (or the integration is off).
    case unavailable
    case authorizationFailed
    /// The sheet has never been presented and nothing has ever been observed.
    case notRequested
    /// The system sheet is up, or the authorization call is still in flight.
    case requesting
    /// The sheet returned and the first import is running.
    case syncing
    /// Data was genuinely observed. Counts only — never values.
    case ready(metricCount: Int, lastSync: Date?)
    /// Reviewed, finished, and nothing readable came back. Not a failure.
    case reviewedNoDataYet
    /// Something in the import did not complete. The code is non-sensitive.
    case partial(errorCode: String?)
    /// The device locked mid-import, so reads were blocked by the system.
    case protectedDataLocked
}

/// The pure resolver behind the Health power-up screen.
///
/// Deliberately a free function over plain values rather than a method on the
/// store: every interesting case here (locked device, partial import, reviewed
/// but empty) is impossible to stage in a simulator, and a resolver that reads
/// `HealthConnectionStore` directly could only be tested by running HealthKit.
enum LifeWeaveHealthFirstSync {

    /// Non-sensitive codes that mean the import itself did not complete.
    ///
    /// Deliberately a small allow-list rather than "any non-nil code". The store
    /// also reports write-preference problems (`preference_write`), which cannot
    /// be caused by this screen — onboarding never writes — and reporting one as
    /// a read problem would send people to fix something that is not broken.
    static let syncBlockingErrorCodes: Set<String> = [
        "authorization_request",
        "sync_partial",
        "sync_failed",
        "local_migration"
    ]

    /// Authorization activity is supplied by the shared connection store.
    static func resolve(
        statuses: [HealthDomain: HealthDomainStatus],
        aggregates: [HealthMetric: HealthAggregateValue],
        isRefreshing: Bool,
        lastSuccessfulSync: Date?,
        nonSensitiveErrorCode: String?,
        isAvailable: Bool,
        isAuthorizationInFlight: Bool = false
    ) -> HealthFirstSyncOutcome {
        guard isAvailable else { return .unavailable }
        if isAuthorizationInFlight { return .requesting }
        if nonSensitiveErrorCode == "authorization_request" { return .authorizationFailed }

        let observedMetricCount = aggregates.count
        let hasReviewed = statuses.values.contains(where: { $0.readRequestState != .neverRequested })
        // `receivingData` counts as observation for deciding whether anything has
        // happened at all — but see below for why it cannot, on its own, carry a
        // readiness claim.
        let hasObservedSomething = observedMetricCount > 0
            || statuses.values.contains(where: { $0.readRequestState == .receivingData })

        if hasReviewed == false && hasObservedSomething == false { return .notRequested }

        if isRefreshing { return .syncing }

        // A locked device outranks every settled state. It is a temporary block
        // on reading, not an answer about whether data exists, and "unlock and
        // come back" is the one useful thing a person can do about it — which is
        // exactly why it must never collapse into `.reviewedNoDataYet`.
        if statuses.values.contains(where: { $0.signal == .protectedDataLocked }) {
            return .protectedDataLocked
        }

        if let code = nonSensitiveErrorCode, syncBlockingErrorCodes.contains(code) {
            return .partial(errorCode: code)
        }

        // Readiness requires actual observed aggregates, never historical flags.
        if observedMetricCount > 0 {
            return .ready(metricCount: observedMetricCount, lastSync: lastSuccessfulSync)
        }

        // Deliberately *not* derived from `lastSuccessfulSync`. A completed sync
        // that read nothing still stamps a date, so a date alone proves only that
        // we asked — never that anything came back.
        return .reviewedNoDataYet
    }

    /// How many benefit areas actually produced something, for the receipt.
    /// Counts, never values: no health number is shown during onboarding.
    static func observedDomainCount(aggregates: [HealthMetric: HealthAggregateValue]) -> Int {
        Set(aggregates.keys.map(\.domain)).count
    }

    /// One settled summary for VoiceOver, posted once when the screen resolves.
    ///
    /// Returns `nil` while the outcome is still moving. Announcing each metric as
    /// it arrived turned a background import into a stream of interruptions, and
    /// the individual arrivals are not decisions anyone can act on.
    static func settledAnnouncement(for outcome: HealthFirstSyncOutcome) -> String? {
        switch outcome {
        case .ready(let metricCount, _):
            "Health sync complete. \(metricCount) metric\(metricCount == 1 ? "" : "s") available."
        case .reviewedNoDataYet:
            "Health access was reviewed. No readable Health data yet."
        case .partial:
            "Health access was reviewed. Some Health data could not be read."
        case .protectedDataLocked:
            "Health sync paused because this iPhone is locked."
        case .authorizationFailed:
            "The Health access request did not finish. You can try again."
        case .unavailable:
            "Apple Health isn't available on this device."
        case .notRequested, .requesting, .syncing:
            nil
        }
    }
}


/// These states describe observations, never inferred read authorization.
@MainActor
extension HealthConnectionStore {
    var presentation: HealthFirstSyncOutcome {
        LifeWeaveHealthFirstSync.resolve(
            statuses: statuses, aggregates: aggregates,
            isRefreshing: isRefreshing || isInitialSyncPending,
            lastSuccessfulSync: lastSuccessfulSync,
            nonSensitiveErrorCode: nonSensitiveErrorCode,
            isAvailable: PermissionKind.appleHealth.isSupportedOnThisDevice,
            isAuthorizationInFlight: isRequestingAuthorization
        )
    }
}

extension HealthFirstSyncOutcome {
    var summary: String {
        switch self {
        case .unavailable: "Apple Health isn't available on this device."
        case .notRequested: "Connect Apple Health to bring your activity into LifeBoard."
        case .requesting: "Review access in Apple Health."
        case .syncing: "Importing Health data. You can keep using LifeBoard."
        case .ready(let count, _): "Health data available · \(count) data types"
        case .reviewedNoDataYet: "No Health data is available to LifeBoard yet. You can keep logging here or review access in Apple Health."
        case .partial: "Some Health data couldn't be imported. You can try syncing again."
        case .protectedDataLocked: "Health import is paused. It will resume when you return with this device unlocked."
        case .authorizationFailed: "The Health access request didn't finish. Please try again."
        }
    }
}

import Foundation

/// Pure derivations for the cloud access coordinator: how a readiness error
/// maps to a state, and how an error is named for telemetry and for people.
///
/// Split out so the coordinator's class body stays under the file-size gate's
/// largest-type budget. Nothing here touches stored state.
extension EvaCloudAccessCoordinator {
    static func resolveState(
        readinessError: EvaProviderError?,
        previousIdentityKind: EvaIdentityKind?,
        nextAvailableAt: Date?
    ) -> EvaCloudAccessState {
        guard let error = readinessError else { return .ready }
        switch error {
        case .authenticationRequired:
            return previousIdentityKind == .apple ? .appleReauthenticationRequired : .needsActivation
        case .adultEligibilityRequired:
            return .temporarilyUnavailable("Eva couldn’t connect. Try again.")
        case .consentRequired:
            return .needsActivation
        case .creditsExhausted:
            return .quotaExhausted(nextAvailableAt)
        case .unavailable(let message):
            return .temporarilyUnavailable(message)
        case .invalidResponse:
            return .temporarilyUnavailable(error.localizedDescription)
        }
    }

    static func telemetryLabel(for state: EvaCloudAccessState) -> String {
        switch state {
        case .hydrating: "hydrating"
        case .ready: "ready"
        case .needsActivation: "needs_activation"
        case .activating: "activating"
        case .temporarilyUnavailable: "temporarily_unavailable"
        case .quotaExhausted: "quota_exhausted"
        case .appleReauthenticationRequired: "apple_reauthentication_required"
        }
    }

    static func errorCode(for error: Error) -> String {
        if let storageError = error as? EvaSecureStorageError { return storageError.telemetryCode }
        if let envelope = error as? EvaErrorEnvelope { return envelope.code }
        if let urlError = error as? URLError { return "url_\(urlError.code.rawValue)" }
        return String(describing: type(of: error))
    }

    static func message(for error: Error) -> String {
        if let storageError = error as? EvaSecureStorageError {
            return storageError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return String(localized: "Eva’s server didn’t respond. Tap to try again.")
            case .notConnectedToInternet, .networkConnectionLost:
                return String(localized: "You’re offline. Reconnect and tap to try again.")
            default:
                break
            }
        }
        if let envelope = error as? EvaErrorEnvelope, envelope.retryable {
            return String(localized: "\(envelope.message) Tap to try again.")
        }
        return error.localizedDescription
    }
}

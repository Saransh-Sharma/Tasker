import AuthenticationServices
import Foundation
import SwiftUI

/// Cloud EVA activation, owned by an object rather than by the view.
///
/// v5 kept this as five pieces of `@State` plus a task handle on the flow view.
/// That works, but it puts a network state machine — sign-in, age eligibility,
/// consent revisions, retry semantics — inside a type whose body SwiftUI inlines
/// into one stack frame at `-Onone`, and it makes the legs untestable.
///
/// The task is *owned*, not fire-and-forget: a detached task outlives the flow
/// and keeps writing to torn-down state after the user taps away.
@MainActor
final class LifeWeaveEvaActivation: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    @Published var grants: Set<EvaConsentPolicy.Grant> = []

    let account = EvaCloudAccountState.shared
    private var task: Task<Void, Never>?

    func refresh() async {
        await account.refresh()
        grants = Set(account.consent?.grants ?? [])
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Never retried automatically.
    ///
    /// Cloud activation spends single-use tokens, so an automatic retry can burn
    /// a credential the user then has to re-earn. The failure states below all
    /// end in "tap to try again" — a decision the person makes, not one the app
    /// makes for them.
    func activate(onSuccess: @escaping () -> Void) {
        guard isWorking == false else { return }
        isWorking = true
        errorMessage = nil
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isWorking = false
                self.task = nil
            }
            do {
                try await account.activateCloud()
                // Checked last: `readinessError` reports the first gate that is
                // not satisfied, and an earlier stale value would mask the real
                // one if it were read before activation ran.
                if let readinessError = account.readinessError() { throw readinessError }
                onSuccess()
            } catch is CancellationError {
                errorMessage = nil
            } catch let error as ASAuthorizationError where error.code == .canceled {
                errorMessage = "Sign in was cancelled. You can try again or finish later."
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func toggleGrant(_ grant: EvaConsentPolicy.Grant, enabled: Bool) {
        guard isWorking == false, let policy = account.consent else { return }
        var replacement = grants
        if enabled { replacement.insert(grant) } else { replacement.remove(grant) }
        isWorking = true
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isWorking = false
                self.task = nil
            }
            do {
                // Consent is a compare-and-swap on the server's revision, so the
                // local set is replaced by what the server confirms rather than
                // by what was optimistically toggled.
                let updated = try await EvaCloudTransport.shared.updateConsent(
                    expectedRevision: policy.revision,
                    grants: Array(replacement)
                )
                grants = Set(updated.grants)
                await account.refresh()
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    /// A stalled request reads to the user as "the app is broken", so name the
    /// cause and the remedy instead of surfacing Foundation's bare
    /// "The request timed out."
    static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "EVA's server didn't respond in time. Tap to try again — you won't have to sign in twice."
            case .notConnectedToInternet, .networkConnectionLost:
                return "You're offline. Reconnect and tap to try again, or finish later."
            default:
                break
            }
        }
        if let envelope = error as? EvaErrorEnvelope, envelope.retryable {
            return "\(envelope.message) Tap to try again."
        }
        return error.localizedDescription
    }
}

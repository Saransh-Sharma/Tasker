import AuthenticationServices
import CryptoKit
import Foundation
import StoreKit
import UIKit

@MainActor
final class EvaAppleIdentityService: NSObject {
    struct PreparedSignIn: Sendable {
        let challengeID: UUID
        let nonce: String
    }

    static let shared = EvaAppleIdentityService()

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var activeController: ASAuthorizationController?
    private var presentationAnchorOverride: ASPresentationAnchor?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(credentialWasRevoked),
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )
    }

    /// `onDeviceVerification` fires once the Apple exchange has landed and the
    /// remaining work is App Attest registration — two more round trips plus a
    /// DeviceCheck key generation, which is long enough that the UI should stop
    /// claiming it is still signing in.
    func signIn(
        using client: EvaCloudTransport = .shared,
        onDeviceVerification: (@MainActor () -> Void)? = nil
    ) async throws -> EvaAppleExchangeOutcome {
        let prepared = try await prepareSignIn(using: client)
        let credential = try await authorize(prepared)
        return try await exchange(
            credential,
            prepared: prepared,
            using: client,
            onDeviceVerification: onDeviceVerification
        )
    }

    /// Prepares the server challenge before SwiftUI renders Apple's standard
    /// sign-in control. `SignInWithAppleButton.onRequest` is synchronous, so a
    /// challenge fetched there would either block the main actor or require a
    /// second, custom authorization sheet.
    func prepareSignIn(using client: EvaCloudTransport = .shared) async throws -> PreparedSignIn {
        let challenge = try await client.signInChallenge()
        return PreparedSignIn(challengeID: challenge.id, nonce: challenge.nonce)
    }

    func configure(_ request: ASAuthorizationAppleIDRequest, for prepared: PreparedSignIn) {
        request.requestedScopes = []
        request.state = prepared.challengeID.uuidString
        request.nonce = Self.hashedNonce(prepared.nonce)
    }

    func exchange(
        _ credential: ASAuthorizationAppleIDCredential,
        prepared: PreparedSignIn,
        using client: EvaCloudTransport = .shared,
        onDeviceVerification: (@MainActor () -> Void)? = nil
    ) async throws -> EvaAppleExchangeOutcome {
        guard let identityTokenData = credential.identityToken,
              let authorizationCodeData = credential.authorizationCode,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            throw EvaProviderError.authenticationRequired
        }
        let session = try await client.exchangeAppleCredential(
            challengeId: prepared.challengeID,
            nonce: prepared.nonce,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            appleUserIdentifier: credential.user,
            signedAppTransaction: try await catalystAppTransaction()
        )
        onDeviceVerification?()
        try await EvaAppAttestService.shared.registerIfNeeded(using: client)
        return session
    }

    func credentialIsAuthorized() async -> Bool {
        let credentials: EvaSessionCredentials?
        do {
            credentials = try await EvaCloudSessionStore.shared.load()
        } catch {
            return false
        }
        guard let user = credentials?.appleUserIdentifier,
              !user.isEmpty else {
            return true
        }
        return await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { state, error in
                continuation.resume(returning: error == nil && state == .authorized)
            }
        }
    }

    @objc private func credentialWasRevoked() {
        Task { @MainActor in
            await EvaCloudAccountState.shared.handleAppleCredentialInvalidation()
        }
    }

    private func catalystAppTransaction() async throws -> String? {
        #if targetEnvironment(macCatalyst)
        let result = try await AppTransaction.shared
        guard case .verified = result else {
            throw EvaProviderError.unavailable(String(localized: "This Mac's App Store transaction could not be verified."))
        }
        return result.jwsRepresentation
        #else
        return nil
        #endif
    }

    private func authorize(_ prepared: PreparedSignIn) async throws -> ASAuthorizationAppleIDCredential {
        guard continuation == nil else { throw EvaProviderError.unavailable(String(localized: "Apple sign-in is already in progress.")) }
        // Resolve the anchor before presenting rather than inside the delegate
        // callback: the protocol method cannot throw, and a missing window scene
        // is a recoverable condition, not grounds for trapping the process.
        guard let anchor = Self.resolveAnchor() else {
            throw EvaProviderError.unavailable(String(localized: "Sign in with Apple needs an active LifeBoard window."))
        }
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.presentationAnchorOverride = anchor
                let request = ASAuthorizationAppleIDProvider().createRequest()
                configure(request, for: prepared)
                let controller = ASAuthorizationController(authorizationRequests: [request])
                self.activeController = controller
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor in self.cancelActiveAuthorization() }
        }
    }

    private static func hashedNonce(_ nonce: String) -> String {
        let digest = Data(SHA256.hash(data: Data(nonce.utf8)))
        return digest.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Without this, a cancelled sign-in leaves `continuation` non-nil for the
    /// lifetime of the process and every later attempt fails the guard above
    /// with "already in progress" until the app is relaunched.
    private func cancelActiveAuthorization() {
        let pending = continuation
        finishAuthorization()
        activeController?.cancel()
        activeController = nil
        pending?.resume(throwing: CancellationError())
    }

    private func finishAuthorization() {
        continuation = nil
        presentationAnchorOverride = nil
    }

    private static func resolveAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScenes = scenes.filter { $0.activationState == .foregroundActive }
        return activeScenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? activeScenes.flatMap(\.windows).first
            ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
    }
}

extension EvaAppleIdentityService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let pending = continuation
        finishAuthorization()
        activeController = nil
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            pending?.resume(throwing: EvaProviderError.authenticationRequired)
            return
        }
        pending?.resume(returning: credential)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let pending = continuation
        finishAuthorization()
        activeController = nil
        pending?.resume(throwing: error)
    }
}

extension EvaAppleIdentityService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let anchor = presentationAnchorOverride ?? Self.resolveAnchor() else {
            preconditionFailure("Apple authorization was presented without an active LifeBoard window.")
        }
        return anchor
    }
}

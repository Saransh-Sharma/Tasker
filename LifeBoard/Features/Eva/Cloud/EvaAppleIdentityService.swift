import AuthenticationServices
import CryptoKit
import Foundation
import StoreKit
import UIKit

@MainActor
final class EvaAppleIdentityService: NSObject {
    static let shared = EvaAppleIdentityService()

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(credentialWasRevoked),
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )
    }

    func signIn(using client: EvaCloudTransport = .shared) async throws -> EvaSessionCredentials {
        let challenge = try await client.signInChallenge()
        let credential = try await authorize(challengeId: challenge.id, nonce: challenge.nonce)
        guard let identityTokenData = credential.identityToken,
              let authorizationCodeData = credential.authorizationCode,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            throw EvaProviderError.authenticationRequired
        }
        let session = try await client.exchangeAppleCredential(
            challengeId: challenge.id,
            nonce: challenge.nonce,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            appleUserIdentifier: credential.user,
            signedAppTransaction: try await catalystAppTransaction()
        )
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

    private func authorize(challengeId: UUID, nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        guard continuation == nil else { throw EvaProviderError.unavailable(String(localized: "Apple sign-in is already in progress.")) }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            request.state = challengeId.uuidString
            let digest = Data(SHA256.hash(data: Data(nonce.utf8)))
            request.nonce = digest.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension EvaAppleIdentityService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: EvaProviderError.authenticationRequired)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

extension EvaAppleIdentityService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let scene = scenes.first else {
            preconditionFailure("Sign in with Apple requires an active window scene.")
        }
        return ASPresentationAnchor(windowScene: scene)
    }
}

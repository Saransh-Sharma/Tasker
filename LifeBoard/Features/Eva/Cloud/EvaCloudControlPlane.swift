import Foundation
import StoreKit

private struct EvaCloudConfigurationEnvelope: Decodable {
    let signedConfiguration: String
}

private struct EvaCloudChallenge: Decodable {
    let challengeId: UUID?
    let nonce: String?
    let challenge: String?
}

private struct EvaCloudExchangeResponse: Decodable {
    let accountId: String
    let familyId: UUID
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
    let requiresAdultEligibility: Bool?
    let requiresAttestation: Bool?
    let created: Bool?
    let identityKind: EvaIdentityKind?
    let trustTier: String?
    let requiresConsentReview: Bool?
    let quota: EvaQuotaState?
    let credits: EvaCreditState?
}

private struct EvaCloudReauthenticationResponse: Decodable {
    let accountId: String
    let familyId: UUID
    let accessToken: String
    let accessTokenExpiresAt: Date
}

private struct EvaGuestBootstrapRequest: Encodable {
    let bootstrapId: UUID
    let installationId: UUID
    let platform: String
    let grants: [EvaConsentPolicy.Grant]
    let signedAppTransaction: String?
    let deviceCheckToken: String?
}

extension EvaCloudTransport {
    func runtimeConfiguration(forceRefresh: Bool = false) async throws -> EvaCloudRuntimeConfiguration {
        if !forceRefresh, let fresh = await configurationStore.loadFresh() { return fresh }
        do {
            let data = try await send(path: "/v1/eva/config", method: "GET", body: nil, authenticated: false, attested: false, retryOnce: true)
            let envelope = try JSONDecoder.evaCloud.decode(EvaCloudConfigurationEnvelope.self, from: data)
            return try await configurationStore.accept(envelope.signedConfiguration)
        } catch {
            if let cached = await configurationStore.loadLastVerified() { return cached }
            throw EvaProviderError.unavailable("Cloud configuration could not be verified.")
        }
    }

    func appleChallenge(purpose: String = "signIn") async throws -> (id: UUID, nonce: String) {
        let data = try JSONEncoder.evaCloud.encode(["purpose": purpose])
        let response = try await send(path: "/v1/auth/challenge", method: "POST", body: data, authenticated: false, attested: false, retryOnce: true)
        let challenge = try JSONDecoder.evaCloud.decode(EvaCloudChallenge.self, from: response)
        guard let id = challenge.challengeId, let nonce = challenge.nonce else { throw EvaProviderError.invalidResponse }
        return (id, nonce)
    }

    func signInChallenge() async throws -> (id: UUID, nonce: String) {
        try await appleChallenge()
    }

    func bootstrapGuest(grants: [EvaConsentPolicy.Grant]) async throws -> EvaSessionCredentials {
        await ProductTelemetry.shared.record(.evaGuestBootstrapStarted)
        let installationID = EvaInstallationIdentity.current
        let bootstrapID = try await sessionStore.guestBootstrapID(for: installationID)
        let body = EvaGuestBootstrapRequest(
            bootstrapId: bootstrapID,
            installationId: installationID,
            platform: EvaInstallationIdentity.platform,
            grants: grants,
            signedAppTransaction: try await Self.signedAppTransaction(),
            deviceCheckToken: await EvaAppAttestService.shared.deviceCheckToken()
        )
        do {
            let data = try await send(
                path: "/v1/auth/guest/bootstrap",
                method: "POST",
                body: JSONEncoder.evaCloud.encode(body),
                authenticated: false,
                attested: false
            )
            let response = try JSONDecoder.evaCloud.decode(EvaCloudExchangeResponse.self, from: data)
            let credentials = credentials(from: response, appleUserIdentifier: nil, defaultIdentityKind: .guest)
            try await sessionStore.save(credentials)
            await ProductTelemetry.shared.record(.evaGuestBootstrapSucceeded)
            await ProductTelemetry.shared.record(.evaTrustTierObserved, outcome: response.trustTier ?? "low")
            return credentials
        } catch {
            await ProductTelemetry.shared.record(.evaGuestBootstrapFailed, errorCode: Self.telemetryErrorCode(error))
            throw error
        }
    }

    func exchangeAppleCredential(
        challengeId: UUID,
        nonce: String,
        identityToken: String,
        authorizationCode: String,
        appleUserIdentifier: String,
        signedAppTransaction: String?
    ) async throws -> EvaAppleExchangeOutcome {
        let body = EvaAppleExchangeRequestV1(
            challengeId: challengeId,
            nonce: nonce,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            installationId: EvaInstallationIdentity.current,
            platform: EvaInstallationIdentity.platform,
            signedAppTransaction: signedAppTransaction
        )
        let data = try await send(
            path: "/v1/auth/apple/exchange",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(body),
            authenticated: false,
            attested: false
        )
        let response = try JSONDecoder.evaCloud.decode(EvaCloudExchangeResponse.self, from: data)
        let credentials = credentials(from: response, appleUserIdentifier: appleUserIdentifier, defaultIdentityKind: .apple)
        try await sessionStore.save(credentials)
        return EvaAppleExchangeOutcome(
            credentials: credentials,
            requiresAdultEligibility: response.requiresAdultEligibility ?? true,
            requiresAttestation: response.requiresAttestation ?? (EvaInstallationIdentity.platform == "ios"),
            created: response.created ?? false
        )
    }

    func linkAppleCredential(
        challengeId: UUID,
        nonce: String,
        identityToken: String,
        authorizationCode: String,
        appleUserIdentifier: String,
        signedAppTransaction: String?
    ) async throws -> EvaAppleExchangeOutcome {
        await ProductTelemetry.shared.record(.evaAppleLinkStarted)
        let body = EvaAppleExchangeRequestV1(
            challengeId: challengeId,
            nonce: nonce,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            installationId: EvaInstallationIdentity.current,
            platform: EvaInstallationIdentity.platform,
            signedAppTransaction: signedAppTransaction
        )
        let data: Data
        do {
          data = try await send(
            path: "/v1/auth/apple/link",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(body),
            authenticated: true,
            attested: false
          )
        } catch {
          await ProductTelemetry.shared.record(.evaAppleLinkFailed, errorCode: Self.telemetryErrorCode(error))
          throw error
        }
        let response = try JSONDecoder.evaCloud.decode(EvaCloudExchangeResponse.self, from: data)
        let credentials = credentials(from: response, appleUserIdentifier: appleUserIdentifier, defaultIdentityKind: .apple)
        try await sessionStore.save(credentials)
        await ProductTelemetry.shared.record(.evaAppleLinkSucceeded)
        return EvaAppleExchangeOutcome(
            credentials: credentials,
            requiresAdultEligibility: response.requiresAdultEligibility ?? false,
            requiresAttestation: response.requiresAttestation ?? false,
            created: false
        )
    }

    func reauthenticateAppleCredential(
        challengeId: UUID,
        nonce: String,
        identityToken: String,
        authorizationCode: String,
        appleUserIdentifier: String,
        signedAppTransaction: String?
    ) async throws {
        guard let current = try await sessionStore.load(),
              current.resolvedIdentityKind == .apple,
              current.appleUserIdentifier == nil || current.appleUserIdentifier == appleUserIdentifier else {
            throw EvaProviderError.authenticationRequired
        }
        let body = EvaAppleExchangeRequestV1(
            challengeId: challengeId,
            nonce: nonce,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            installationId: current.installationId,
            platform: current.platform,
            signedAppTransaction: signedAppTransaction
        )
        let data = try await send(
            path: "/v1/auth/apple/reauthenticate",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(body),
            authenticated: true,
            attested: false
        )
        let response = try JSONDecoder.evaCloud.decode(EvaCloudReauthenticationResponse.self, from: data)
        guard response.accountId == current.accountId, response.familyId == current.familyId else {
            throw EvaProviderError.invalidResponse
        }
        try await sessionStore.save(EvaSessionCredentials(
            accountId: current.accountId,
            familyId: current.familyId,
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshToken: current.refreshToken,
            refreshTokenExpiresAt: current.refreshTokenExpiresAt,
            installationId: current.installationId,
            platform: current.platform,
            appleUserIdentifier: current.appleUserIdentifier,
            identityKind: current.identityKind,
            trustTier: current.trustTier
        ))
    }

    func attestationChallenge() async throws -> String {
        let data = try await send(path: "/v1/attestation/challenge", method: "POST", body: Data("{}".utf8), authenticated: true, attested: false)
        let challenge = try JSONDecoder.evaCloud.decode(EvaCloudChallenge.self, from: data)
        guard let value = challenge.challenge else { throw EvaProviderError.invalidResponse }
        return value
    }

    func registerAttestation(challenge: String, keyIdentifier: String, attestation: String) async throws {
        _ = try await send(
            path: "/v1/attestation/register",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(["challenge": challenge, "keyId": keyIdentifier, "attestation": attestation]),
            authenticated: true,
            attested: false
        )
    }

    func verifyRegisteredAttestation() async throws {
        _ = try await send(
            path: "/v1/attestation/verify",
            method: "POST",
            body: Data("{}".utf8),
            authenticated: true,
            attested: true
        )
    }

    func registerAgeEligibility(lowerBound: Int?, declaration: String, policyRequired: Bool = false) async throws {
        _ = try await send(
            path: "/v1/age/eligibility",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(EvaAdultEligibilityRequestV1(
                declaration: declaration,
                lowerBound: lowerBound,
                policyVersion: "apple-dar-13-v2",
                policyRequired: policyRequired
            )),
            authenticated: true,
            attested: true
        )
    }


    func quota() async throws -> EvaQuotaState {
        try JSONDecoder.evaCloud.decode(EvaQuotaState.self, from: await send(
            path: "/v1/eva/quota", method: "GET", body: nil, authenticated: true, attested: false, retryOnce: true
        ))
    }

    func credits() async throws -> EvaCreditState {
        try JSONDecoder.evaCloud.decode(EvaCreditState.self, from: await send(
            path: "/v1/eva/credits", method: "GET", body: nil, authenticated: true, attested: false, retryOnce: true
        ))
    }

    func consent() async throws -> EvaConsentPolicy {
        try JSONDecoder.evaCloud.decode(EvaConsentPolicy.self, from: await send(
            path: "/v1/eva/consent", method: "GET", body: nil, authenticated: true, attested: false, retryOnce: true
        ))
    }

    func updateConsent(expectedRevision: Int, grants: [EvaConsentPolicy.Grant]) async throws -> EvaConsentPolicy {
        struct Body: Encodable { let expectedRevision: Int; let grants: [EvaConsentPolicy.Grant] }
        let data = try await send(
            path: "/v1/eva/consent",
            method: "PUT",
            body: JSONEncoder.evaCloud.encode(Body(expectedRevision: expectedRevision, grants: grants)),
            authenticated: true,
            attested: true
        )
        return try JSONDecoder.evaCloud.decode(EvaConsentPolicy.self, from: data)
    }

    func logout() async {
        _ = try? await send(path: "/v1/auth/logout", method: "POST", body: Data("{}".utf8), authenticated: true, attested: false)
        try? await sessionStore.clear()
        await EvaAppAttestService.shared.clearRegistration()
    }

    func deleteAccount() async throws {
        _ = try await send(
            path: "/v1/account",
            method: "DELETE",
            body: JSONEncoder.evaCloud.encode(["confirmation": "deleteCloudEvaData"]),
            authenticated: true,
            attested: true
        )
        try? await sessionStore.clear()
        try? await sessionStore.clearGuestBootstrapID()
        await EvaAppAttestService.shared.clearRegistration()
    }


    private func credentials(
        from response: EvaCloudExchangeResponse,
        appleUserIdentifier: String?,
        defaultIdentityKind: EvaIdentityKind
    ) -> EvaSessionCredentials {
        EvaSessionCredentials(
            accountId: response.accountId,
            familyId: response.familyId,
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshToken: response.refreshToken,
            refreshTokenExpiresAt: response.refreshTokenExpiresAt,
            installationId: EvaInstallationIdentity.current,
            platform: EvaInstallationIdentity.platform,
            appleUserIdentifier: appleUserIdentifier,
            identityKind: response.identityKind ?? defaultIdentityKind,
            trustTier: response.trustTier
        )
    }

    private static func signedAppTransaction() async throws -> String? {
        #if targetEnvironment(macCatalyst)
        let result = try await AppTransaction.shared
        guard case .verified = result else { return nil }
        return result.jwsRepresentation
        #else
        return nil
        #endif
    }

    private static func telemetryErrorCode(_ error: Error) -> String {
        if let envelope = error as? EvaErrorEnvelope { return envelope.code }
        if let urlError = error as? URLError { return "url_\(urlError.code.rawValue)" }
        return "unexpected"
    }
}

import Foundation

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

    func signInChallenge() async throws -> (id: UUID, nonce: String) {
        let data = try JSONEncoder.evaCloud.encode(["purpose": "signIn"])
        let response = try await send(path: "/v1/auth/challenge", method: "POST", body: data, authenticated: false, attested: false, retryOnce: true)
        let challenge = try JSONDecoder.evaCloud.decode(EvaCloudChallenge.self, from: response)
        guard let id = challenge.challengeId, let nonce = challenge.nonce else { throw EvaProviderError.invalidResponse }
        return (id, nonce)
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
        let credentials = EvaSessionCredentials(
            accountId: response.accountId,
            familyId: response.familyId,
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshToken: response.refreshToken,
            refreshTokenExpiresAt: response.refreshTokenExpiresAt,
            installationId: EvaInstallationIdentity.current,
            platform: EvaInstallationIdentity.platform,
            appleUserIdentifier: appleUserIdentifier
        )
        try await sessionStore.save(credentials)
        return EvaAppleExchangeOutcome(
            credentials: credentials,
            requiresAdultEligibility: response.requiresAdultEligibility ?? true,
            requiresAttestation: response.requiresAttestation ?? (EvaInstallationIdentity.platform == "ios"),
            created: response.created ?? false
        )
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

    func registerAdultEligibility(lowerBound: Int?, declaration: String) async throws {
        _ = try await send(
            path: "/v1/age/eligibility",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(EvaAdultEligibilityRequestV1(
                declaration: declaration,
                lowerBound: lowerBound,
                policyVersion: "apple-dar-v1"
            )),
            authenticated: true,
            attested: true
        )
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
        _ = try await send(path: "/v1/account", method: "DELETE", body: Data("{}".utf8), authenticated: true, attested: true)
        try await sessionStore.clear()
        await EvaAppAttestService.shared.clearRegistration()
    }
}

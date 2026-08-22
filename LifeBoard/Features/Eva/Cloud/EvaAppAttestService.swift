import CryptoKit
import DeviceCheck
import Foundation

actor EvaAppAttestService {
    static let shared = EvaAppAttestService()

    private struct Registration: Codable {
        let keyIdentifier: String
        let accountID: String
        let installationID: UUID
    }

    private let registrationKey = "eva.cloud.app-attest-registration.v3"
    private let legacyAccountRegistrationKey = "eva.cloud.app-attest-registration.v2"
    private let legacyKeyIdentifierKey = "eva.cloud.app-attest-key-id.v1"

    var isSupported: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        DCAppAttestService.shared.isSupported
        #endif
    }

    @discardableResult
    func registerIfNeeded(using client: EvaCloudTransport) async -> Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        guard let accountID = await client.currentAccountIDForAttestation() else { return false }
        guard DCAppAttestService.shared.isSupported else {
            await client.recordLowTrust(for: accountID)
            await ProductTelemetry.shared.record(.evaTrustTierObserved, outcome: "low")
            return false
        }
        if let registration = storedRegistration,
           registration.accountID == accountID,
           registration.installationID == EvaInstallationIdentity.current {
            // App Attest private keys do not survive reinstall, migration, or
            // restore even when preferences containing a key identifier do.
            // Prove the stored key still works before reporting high trust.
            do {
                try await client.verifyRegisteredAttestation()
                await client.recordHighTrust(for: accountID)
                return true
            } catch {
                clearRegistration()
            }
        }
        clearRegistration()
        do {
            let challenge = try await client.attestationChallenge()
            let keyIdentifier = try await generateKey()
            let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
            let attestation = try await attestKey(keyIdentifier, clientDataHash: hash)
            try await client.registerAttestation(
                challenge: challenge,
                keyIdentifier: keyIdentifier,
                attestation: attestation.base64EncodedString()
            )
            let registration = Registration(
                keyIdentifier: keyIdentifier,
                accountID: accountID,
                installationID: EvaInstallationIdentity.current
            )
            UserDefaults.standard.set(try JSONEncoder().encode(registration), forKey: registrationKey)
            await client.recordHighTrust(for: accountID)
            await ProductTelemetry.shared.record(.evaTrustTierObserved, outcome: "high")
            return true
        } catch {
            await client.recordLowTrust(for: accountID)
            await ProductTelemetry.shared.record(.evaTrustTierObserved, outcome: "low")
            return false
        }
        #endif
    }

    func canAssert() -> Bool { storedRegistration != nil }

    func deviceCheckToken() async -> String? {
        #if targetEnvironment(macCatalyst)
        return nil
        #else
        guard DCDevice.current.isSupported else { return nil }
        return await withCheckedContinuation { continuation in
            DCDevice.current.generateToken { data, _ in
                continuation.resume(returning: data?.base64EncodedString())
            }
        }
        #endif
    }

    func assertion(for payload: Data) async throws -> String {
        #if targetEnvironment(macCatalyst)
        return ""
        #else
        guard let keyIdentifier = storedRegistration?.keyIdentifier else { throw EvaProviderError.authenticationRequired }
        let hash = Data(SHA256.hash(data: payload))
        let assertion = try await generateAssertion(keyIdentifier, clientDataHash: hash)
        return assertion.base64EncodedString()
        #endif
    }

    func clearRegistration() {
        UserDefaults.standard.removeObject(forKey: registrationKey)
        UserDefaults.standard.removeObject(forKey: legacyAccountRegistrationKey)
        UserDefaults.standard.removeObject(forKey: legacyKeyIdentifierKey)
    }

    private var storedRegistration: Registration? {
        // A v1 key had no account binding. Reusing it after a guest-to-Apple
        // merge could assert for the wrong server account, so migrate by
        // generating a fresh account-scoped key on the next registration.
        if UserDefaults.standard.string(forKey: legacyKeyIdentifierKey) != nil {
            UserDefaults.standard.removeObject(forKey: legacyKeyIdentifierKey)
        }
        if UserDefaults.standard.data(forKey: legacyAccountRegistrationKey) != nil {
            UserDefaults.standard.removeObject(forKey: legacyAccountRegistrationKey)
        }
        guard let data = UserDefaults.standard.data(forKey: registrationKey) else { return nil }
        return try? JSONDecoder().decode(Registration.self, from: data)
    }

    #if !targetEnvironment(macCatalyst)
    private func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DCAppAttestService.shared.generateKey { keyIdentifier, error in
                if let keyIdentifier { continuation.resume(returning: keyIdentifier) }
                else { continuation.resume(throwing: error ?? EvaProviderError.authenticationRequired) }
            }
        }
    }

    private func attestKey(_ keyIdentifier: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DCAppAttestService.shared.attestKey(keyIdentifier, clientDataHash: clientDataHash) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? EvaProviderError.authenticationRequired) }
            }
        }
    }

    private func generateAssertion(_ keyIdentifier: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DCAppAttestService.shared.generateAssertion(keyIdentifier, clientDataHash: clientDataHash) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? EvaProviderError.authenticationRequired) }
            }
        }
    }
    #endif
}

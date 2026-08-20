import CryptoKit
import DeviceCheck
import Foundation

actor EvaAppAttestService {
    static let shared = EvaAppAttestService()

    private let keyIdentifierKey = "eva.cloud.app-attest-key-id.v1"

    var isSupported: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        DCAppAttestService.shared.isSupported
        #endif
    }

    func registerIfNeeded(using client: EvaCloudTransport) async throws {
        #if targetEnvironment(macCatalyst)
        return
        #else
        guard DCAppAttestService.shared.isSupported else { throw EvaProviderError.unavailable("App Attest is unavailable on this device.") }
        if storedKeyIdentifier != nil { return }
        let challenge = try await client.attestationChallenge()
        let keyIdentifier = try await generateKey()
        let hash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await attestKey(keyIdentifier, clientDataHash: hash)
        try await client.registerAttestation(
            challenge: challenge,
            keyIdentifier: keyIdentifier,
            attestation: attestation.base64EncodedString()
        )
        UserDefaults.standard.set(keyIdentifier, forKey: keyIdentifierKey)
        #endif
    }

    func assertion(for payload: Data) async throws -> String {
        #if targetEnvironment(macCatalyst)
        return ""
        #else
        guard let keyIdentifier = storedKeyIdentifier else { throw EvaProviderError.authenticationRequired }
        let hash = Data(SHA256.hash(data: payload))
        let assertion = try await generateAssertion(keyIdentifier, clientDataHash: hash)
        return assertion.base64EncodedString()
        #endif
    }

    func clearRegistration() {
        UserDefaults.standard.removeObject(forKey: keyIdentifierKey)
    }

    private var storedKeyIdentifier: String? {
        UserDefaults.standard.string(forKey: keyIdentifierKey)
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

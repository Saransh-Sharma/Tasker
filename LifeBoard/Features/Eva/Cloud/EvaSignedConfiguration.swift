import CryptoKit
import Foundation

struct EvaCloudRuntimeConfiguration: Codable, Sendable {
    enum CloudState: String, Codable, Sendable {
        case enabled
        case degraded
        case disabled
    }

    struct RoutePolicy: Codable, Sendable {
        let enabled: Bool
        let inputTokenCap: Int
        let outputTokenCap: Int
        let reasoning: String
        let billable: Bool
        let structured: Bool
    }

    let schemaVersion: Int
    let version: Int
    let issuedAt: Date
    let environment: String
    let cloudState: CloudState
    let ttsEnabled: Bool
    let maintenanceMessage: String?
    let offlineRecoveryPolicy: String
    let textModel: String
    let speechModel: String
    let speechVoice: String
    let minimumClientVersion: String
    let contractVersions: [Int]
    let routes: [EvaCloudRoute: RoutePolicy]
}

struct EvaSignedConfigurationVerifier {
    let pinnedPublicKey: Data?
    let expectedEnvironment: String?
    let acceptedVersion: Int
    let now: Date

    func verify(_ compactJWS: String) throws -> EvaCloudRuntimeConfiguration {
        let segments = compactJWS.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3,
              let headerData = Data(base64URLEncoded: String(segments[0])),
              let payload = Data(base64URLEncoded: String(segments[1])),
              let signature = Data(base64URLEncoded: String(segments[2])) else {
            throw EvaConfigurationError.invalidSignature
        }
        let header = try JSONSerialization.jsonObject(with: headerData) as? [String: String]
        guard header?["alg"] == "EdDSA", header?["kid"] == "eva-config-v2" else {
            throw EvaConfigurationError.invalidSignature
        }
        guard let pinnedPublicKey, pinnedPublicKey.count == 32 else {
            throw EvaConfigurationError.missingPinnedKey
        }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pinnedPublicKey)
        let signingInput = Data("\(segments[0]).\(segments[1])".utf8)
        guard publicKey.isValidSignature(signature, for: signingInput) else {
            throw EvaConfigurationError.invalidSignature
        }
        let configuration = try JSONDecoder.evaCloud.decode(EvaCloudRuntimeConfiguration.self, from: payload)
        guard configuration.schemaVersion == 2,
              configuration.contractVersions.contains(1),
              configuration.environment == expectedEnvironment,
              configuration.textModel == "gpt-5.6-luna",
              configuration.speechModel == "tts-1",
              configuration.speechVoice == "nova",
              configuration.offlineRecoveryPolicy == "offerTryOffline" else {
            throw EvaConfigurationError.unsupported
        }
        guard configuration.issuedAt <= now.addingTimeInterval(5 * 60),
              configuration.issuedAt >= now.addingTimeInterval(-7 * 24 * 60 * 60) else {
            throw EvaConfigurationError.stale
        }
        guard configuration.version >= acceptedVersion else { throw EvaConfigurationError.rollback }
        return configuration
    }
}

actor EvaSignedConfigurationStore {
    static let shared = EvaSignedConfigurationStore()

    private struct CachedConfiguration: Codable {
        let signedConfiguration: String
        let fetchedAt: Date
    }

    private let acceptedVersionKey = "eva.cloud.config.accepted-version"
    private let freshLifetime: TimeInterval = 6 * 60 * 60
    private let staleLifetime: TimeInterval = 7 * 24 * 60 * 60

    func loadFresh() -> EvaCloudRuntimeConfiguration? {
        guard let cached = try? loadCache(), Date().timeIntervalSince(cached.fetchedAt) <= freshLifetime else {
            return nil
        }
        return try? verify(cached.signedConfiguration)
    }

    func loadLastVerified() -> EvaCloudRuntimeConfiguration? {
        guard let cached = try? loadCache(), Date().timeIntervalSince(cached.fetchedAt) <= staleLifetime else {
            return nil
        }
        return try? verify(cached.signedConfiguration)
    }

    func accept(_ signedConfiguration: String) throws -> EvaCloudRuntimeConfiguration {
        let configuration = try verify(signedConfiguration)
        let cached = CachedConfiguration(signedConfiguration: signedConfiguration, fetchedAt: Date())
        let data = try JSONEncoder.evaCloud.encode(cached)
        let url = try cacheURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        UserDefaults.standard.set(configuration.version, forKey: acceptedVersionKey)
        return configuration
    }

    private func verify(_ compactJWS: String) throws -> EvaCloudRuntimeConfiguration {
        try EvaSignedConfigurationVerifier(
            pinnedPublicKey: try pinnedPublicKey(),
            expectedEnvironment: expectedEnvironment(),
            acceptedVersion: UserDefaults.standard.integer(forKey: acceptedVersionKey),
            now: Date()
        ).verify(compactJWS)
    }

    private func expectedEnvironment() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "EVACloudEnvironment") as? String
    }

    private func pinnedPublicKey() throws -> Data {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "EVAConfigSigningPublicKey") as? String,
              value.isEmpty == false,
              let data = Data(base64URLEncoded: value),
              data.count == 32 else {
            throw EvaConfigurationError.missingPinnedKey
        }
        return data
    }

    private func loadCache() throws -> CachedConfiguration {
        try JSONDecoder.evaCloud.decode(CachedConfiguration.self, from: Data(contentsOf: try cacheURL()))
    }

    private func cacheURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appending(path: "EVACloud/config-v2.json")
    }
}

enum EvaConfigurationError: Error, Equatable {
    case invalidSignature
    case unsupported
    case rollback
    case stale
    case missingPinnedKey
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        normalized.append(String(repeating: "=", count: (4 - normalized.count % 4) % 4))
        self.init(base64Encoded: normalized)
    }
}

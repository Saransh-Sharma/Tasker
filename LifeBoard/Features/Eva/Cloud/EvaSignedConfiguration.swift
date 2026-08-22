import CryptoKit
import Foundation

struct EvaCloudRuntimeConfiguration: Codable, Sendable {
    struct AppRuntimeConfiguration: Codable, Equatable, Sendable {
        static let releaseDefault = AppRuntimeConfiguration(
            onboardingLifeWeaveV6Enabled: true,
            existingUserRefreshVersion: 1,
            existingUserRefreshEnabled: true,
            productEventsEnabled: true
        )

        let onboardingLifeWeaveV6Enabled: Bool
        let existingUserRefreshVersion: Int
        let existingUserRefreshEnabled: Bool
        let productEventsEnabled: Bool
    }

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

    struct GuestAccessPolicy: Codable, Sendable {
        let bootstrapEnabled: Bool
        let inferenceEnabled: Bool
        let appleLinkingEnabled: Bool
        let rolloutPercent: Int
    }

    struct UsagePolicy: Codable, Sendable {
        let billableLimit: Int
        let helperLimit: Int
        let rollingWindowSeconds: Int
    }

    struct AgePolicy: Codable, Sendable {
        let minimumAge: Int
        let unknownAgeAllowed: Bool
        let requiredRegionFailClosed: Bool
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
    let appRuntime: AppRuntimeConfiguration
    let guestAccess: GuestAccessPolicy?
    let usagePolicy: UsagePolicy?
    let agePolicy: AgePolicy?
    let routes: [EvaCloudRoute: RoutePolicy]

    var requiresAgeDecision: Bool {
        cloudState != .disabled && (
            agePolicy?.requiredRegionFailClosed == true
            || agePolicy?.unknownAgeAllowed == false
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case version
        case issuedAt
        case environment
        case cloudState
        case ttsEnabled
        case maintenanceMessage
        case offlineRecoveryPolicy
        case textModel
        case speechModel
        case speechVoice
        case minimumClientVersion
        case contractVersions
        case appRuntime
        case guestAccess
        case usagePolicy
        case agePolicy
        case routes
    }

    init(
        schemaVersion: Int,
        version: Int,
        issuedAt: Date,
        environment: String,
        cloudState: CloudState,
        ttsEnabled: Bool,
        maintenanceMessage: String?,
        offlineRecoveryPolicy: String,
        textModel: String,
        speechModel: String,
        speechVoice: String,
        minimumClientVersion: String,
        contractVersions: [Int],
        appRuntime: AppRuntimeConfiguration = .releaseDefault,
        guestAccess: GuestAccessPolicy? = nil,
        usagePolicy: UsagePolicy? = nil,
        agePolicy: AgePolicy? = nil,
        routes: [EvaCloudRoute: RoutePolicy]
    ) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.issuedAt = issuedAt
        self.environment = environment
        self.cloudState = cloudState
        self.ttsEnabled = ttsEnabled
        self.maintenanceMessage = maintenanceMessage
        self.offlineRecoveryPolicy = offlineRecoveryPolicy
        self.textModel = textModel
        self.speechModel = speechModel
        self.speechVoice = speechVoice
        self.minimumClientVersion = minimumClientVersion
        self.contractVersions = contractVersions
        self.appRuntime = appRuntime
        self.guestAccess = guestAccess
        self.usagePolicy = usagePolicy
        self.agePolicy = agePolicy
        self.routes = routes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        version = try container.decode(Int.self, forKey: .version)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        environment = try container.decode(String.self, forKey: .environment)
        cloudState = try container.decode(CloudState.self, forKey: .cloudState)
        ttsEnabled = try container.decode(Bool.self, forKey: .ttsEnabled)
        maintenanceMessage = try container.decodeIfPresent(String.self, forKey: .maintenanceMessage)
        offlineRecoveryPolicy = try container.decode(String.self, forKey: .offlineRecoveryPolicy)
        textModel = try container.decode(String.self, forKey: .textModel)
        speechModel = try container.decode(String.self, forKey: .speechModel)
        speechVoice = try container.decode(String.self, forKey: .speechVoice)
        minimumClientVersion = try container.decode(String.self, forKey: .minimumClientVersion)
        contractVersions = try container.decode([Int].self, forKey: .contractVersions)
        appRuntime = try container.decodeIfPresent(AppRuntimeConfiguration.self, forKey: .appRuntime) ?? .releaseDefault
        guestAccess = try container.decodeIfPresent(GuestAccessPolicy.self, forKey: .guestAccess)
        usagePolicy = try container.decodeIfPresent(UsagePolicy.self, forKey: .usagePolicy)
        agePolicy = try container.decodeIfPresent(AgePolicy.self, forKey: .agePolicy)

        let wireRoutes = try container.decode([String: RoutePolicy].self, forKey: .routes)
        var decodedRoutes: [EvaCloudRoute: RoutePolicy] = [:]
        decodedRoutes.reserveCapacity(wireRoutes.count)
        for (rawRoute, policy) in wireRoutes {
            guard let route = EvaCloudRoute(rawValue: rawRoute) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .routes,
                    in: container,
                    debugDescription: "Unsupported Cloud EVA route: \(rawRoute)"
                )
            }
            decodedRoutes[route] = policy
        }
        routes = decodedRoutes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(version, forKey: .version)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encode(environment, forKey: .environment)
        try container.encode(cloudState, forKey: .cloudState)
        try container.encode(ttsEnabled, forKey: .ttsEnabled)
        try container.encodeIfPresent(maintenanceMessage, forKey: .maintenanceMessage)
        try container.encode(offlineRecoveryPolicy, forKey: .offlineRecoveryPolicy)
        try container.encode(textModel, forKey: .textModel)
        try container.encode(speechModel, forKey: .speechModel)
        try container.encode(speechVoice, forKey: .speechVoice)
        try container.encode(minimumClientVersion, forKey: .minimumClientVersion)
        try container.encode(contractVersions, forKey: .contractVersions)
        try container.encode(appRuntime, forKey: .appRuntime)
        try container.encodeIfPresent(guestAccess, forKey: .guestAccess)
        try container.encodeIfPresent(usagePolicy, forKey: .usagePolicy)
        try container.encodeIfPresent(agePolicy, forKey: .agePolicy)
        try container.encode(
            Dictionary(uniqueKeysWithValues: routes.map { ($0.key.rawValue, $0.value) }),
            forKey: .routes
        )
    }
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
        guard let configuration = try? verify(cached.signedConfiguration) else { return nil }
        AppRuntimeConfigurationStore.accept(configuration.appRuntime)
        return configuration
    }

    func loadLastVerified() -> EvaCloudRuntimeConfiguration? {
        guard let cached = try? loadCache(), Date().timeIntervalSince(cached.fetchedAt) <= staleLifetime else {
            return nil
        }
        guard let configuration = try? verify(cached.signedConfiguration) else { return nil }
        AppRuntimeConfigurationStore.accept(configuration.appRuntime)
        return configuration
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
        AppRuntimeConfigurationStore.accept(configuration.appRuntime)
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

enum AppRuntimeConfigurationStore {
    private static let key = "app.runtimeConfiguration.lastVerified.v1"

    static var current: EvaCloudRuntimeConfiguration.AppRuntimeConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(
                EvaCloudRuntimeConfiguration.AppRuntimeConfiguration.self,
                from: data
              ) else { return .releaseDefault }
        return value
    }

    static func accept(_ configuration: EvaCloudRuntimeConfiguration.AppRuntimeConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: key)
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

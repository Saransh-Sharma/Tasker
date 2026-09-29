import Foundation

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

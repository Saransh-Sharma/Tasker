import CoreData
import Foundation

public enum PersistentBootstrapState: Sendable {
    case loading
    case ready(NSPersistentCloudKitContainer)
    case failed(String)
}

public enum PersistentSyncMode: Equatable, Sendable {
    case fullSync
    case writeClosed(reason: String)

    public var modeName: String {
        switch self {
        case .fullSync: "full_sync"
        case .writeClosed: "write_closed"
        }
    }

    public var reason: String {
        switch self {
        case .fullSync: "healthy_split_store"
        case .writeClosed(let reason): reason
        }
    }
}

public struct PersistentStoreLoadReport {
    public let loadedConfigurations: Set<String>
    public let errors: [NSError]

    public init(loadedConfigurations: Set<String>, errors: [NSError]) {
        self.loadedConfigurations = loadedConfigurations
        self.errors = errors
    }
}

public enum CloudKitMirroringMode: Equatable {
    case enabled
    case disabled(reason: String)

    public var reason: String {
        switch self {
        case .enabled: "enabled"
        case .disabled(let reason): reason
        }
    }
}

public struct CloudKitRuntimeContext {
    public let environment: [String: String]
    public let arguments: [String]
    public let isSimulator: Bool

    public init(environment: [String: String], arguments: [String], isSimulator: Bool) {
        self.environment = environment
        self.arguments = arguments
        self.isSimulator = isSimulator
    }

    public static func current(processInfo: ProcessInfo = .processInfo) -> Self {
#if targetEnvironment(simulator)
        let isSimulator = true
#else
        let isSimulator = false
#endif
        return Self(
            environment: processInfo.environment,
            arguments: processInfo.arguments,
            isSimulator: isSimulator
        )
    }
}

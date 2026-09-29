import CloudKit
import CoreData
import Foundation
import Observation
#if targetEnvironment(macCatalyst)
import Security
#endif

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
    /// Whether the signed process carries the CloudKit iCloud service.
    ///
    /// CloudKit does not report a missing entitlement as an error: creating a
    /// container without one traps the process (`EXC_BREAKPOINT` inside
    /// `PFCloudKitContainerProvider`). An unsigned or ad-hoc Mac Catalyst build
    /// has no entitlements at all, so mirroring must be skipped before Core Data
    /// ever reaches CloudKit.
    public let hasCloudKitEntitlement: Bool

    public init(
        environment: [String: String],
        arguments: [String],
        isSimulator: Bool,
        hasCloudKitEntitlement: Bool = true
    ) {
        self.environment = environment
        self.arguments = arguments
        self.isSimulator = isSimulator
        self.hasCloudKitEntitlement = hasCloudKitEntitlement
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
            isSimulator: isSimulator,
            hasCloudKitEntitlement: processHasCloudKitEntitlement()
        )
    }

    /// iOS device builds cannot install without their provisioned entitlements,
    /// so only Mac Catalyst — which runs unsigned and ad-hoc builds — is checked.
    private static func processHasCloudKitEntitlement() -> Bool {
#if targetEnvironment(macCatalyst)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.icloud-services" as CFString,
                  nil
              ),
              let services = value as? [String] else {
            return false
        }
        return services.contains("CloudKit")
#else
        return true
#endif
    }
}

// MARK: - Cloud sync status

/// What iCloud sync has actually done, recorded from the signals that exist:
/// whether mirroring is on for this build, the iCloud account status, and
/// every `NSPersistentCloudKitContainer` setup/import/export event.
///
/// The Recovery Center used to print "syncing to your private iCloud" for
/// every full-sync launch without looking at any of these — including a
/// signed-out iPhone and a Mac build with no CloudKit entitlement. It reads
/// this now, and so can anything else that needs to know whether a first
/// import has landed (onboarding on a second device).
public final class CloudSyncStatusStore: @unchecked Sendable {
    public static let shared = CloudSyncStatusStore()

    public enum AccountStatus: Equatable, Sendable {
        case unknown
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
    }

    /// Why sync stopped, in the terms the person can act on.
    public enum PauseReason: Equatable, Sendable {
        case storageFull
        case offline
        case accountUnavailable
        case other
    }

    public struct Snapshot: Equatable, Sendable {
        /// `nil` until bootstrap or preflight has said.
        public var mirroringEnabled: Bool?
        public var accountStatus: AccountStatus = .unknown
        public var lastImportAt: Date?
        public var lastExportAt: Date?
        /// Events that started and have not ended.
        public var inFlightEventCount = 0
        /// The latest failed event's reason and when it failed. Cleared by
        /// the next successful event of any kind.
        public var pause: PauseReason?
        public var pausedAt: Date?
        /// Survives relaunches: a first import finished on this install.
        public var hasCompletedFirstImport = false

        public var lastSyncAt: Date? {
            switch (lastImportAt, lastExportAt) {
            case let (lhs?, rhs?): return max(lhs, rhs)
            case let (lhs?, nil): return lhs
            case let (nil, rhs?): return rhs
            case (nil, nil): return nil
            }
        }
    }

    private static let firstImportKey = "cloudSync.firstImportCompletedAt"

    private let lock = NSLock()
    private var state: Snapshot
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var initial = Snapshot()
        initial.hasCompletedFirstImport = defaults.object(forKey: Self.firstImportKey) != nil
        state = initial
    }

    public var snapshot: Snapshot {
        lock.withLock { state }
    }

    public func recordMirroring(enabled: Bool) {
        lock.withLock { state.mirroringEnabled = enabled }
    }

    public func recordAccountStatus(_ status: AccountStatus) {
        lock.withLock { state.accountStatus = status }
    }

    public enum EventKind: Sendable {
        case setup
        case importing
        case exporting
    }

    /// Records one container event. `endDate == nil` means it just started.
    public func recordEvent(
        kind: EventKind,
        endDate: Date?,
        succeeded: Bool,
        error: Error?
    ) {
        var firstImportJustCompleted = false
        lock.withLock {
            guard let endDate else {
                state.inFlightEventCount += 1
                return
            }
            state.inFlightEventCount = max(0, state.inFlightEventCount - 1)
            guard succeeded, error == nil else {
                state.pause = error.map(Self.pauseReason(for:)) ?? .other
                state.pausedAt = endDate
                return
            }
            state.pause = nil
            state.pausedAt = nil
            switch kind {
            case .setup:
                break
            case .importing:
                state.lastImportAt = endDate
                if state.hasCompletedFirstImport == false {
                    state.hasCompletedFirstImport = true
                    firstImportJustCompleted = true
                }
            case .exporting:
                state.lastExportAt = endDate
            }
        }
        if firstImportJustCompleted {
            defaults.set(Date(), forKey: Self.firstImportKey)
        }
    }

    /// Whether it is worth waiting for iCloud before concluding the synced
    /// store is empty: mirroring is on, the account is signed in, and no
    /// import has ever finished on this install.
    public var mightStillReceiveFirstImport: Bool {
        let current = snapshot
        return current.mirroringEnabled != false
            && current.accountStatus != .noAccount
            && current.accountStatus != .restricted
            && current.hasCompletedFirstImport == false
    }

    /// Waits for a first import to finish, up to `timeout`. Returns `true`
    /// if one has finished (now or earlier), `false` on timeout or when
    /// there is nothing to wait for — an offline person is never stuck.
    public func waitForFirstImport(timeout: Duration = .seconds(6)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while true {
            let current = snapshot
            if current.hasCompletedFirstImport { return true }
            if mightStillReceiveFirstImport == false { return false }
            if current.pause == .offline || current.pause == .accountUnavailable { return false }
            guard clock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(250))
            guard Task.isCancelled == false else { return false }
        }
    }

    static func pauseReason(for error: Error) -> PauseReason {
        let nsError = error as NSError
        guard nsError.domain == CKError.errorDomain else {
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                return pauseReason(for: underlying)
            }
            return nsError.domain == NSURLErrorDomain ? .offline : .other
        }
        switch CKError.Code(rawValue: nsError.code) {
        case .quotaExceeded:
            return .storageFull
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .offline
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .accountUnavailable
        case .partialFailure:
            // The per-item errors say what actually happened.
            let partials: [Error] = (nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error])
                .map { Array($0.values) } ?? []
            let reasons = partials.map(pauseReason(for:))
            if reasons.contains(.storageFull) { return .storageFull }
            if reasons.contains(.accountUnavailable) { return .accountUnavailable }
            if reasons.contains(.offline) { return .offline }
            return .other
        default:
            return .other
        }
    }
}

// MARK: - Read-only mode

/// Whether the store opened read-only (the write-closed fallback), as an
/// observable value a shell can show a banner for.
///
/// `WriteClosedRepositoryAdapters` refuse every write in that mode, but
/// nothing on screen said so: edits failed one by one with no explanation.
/// Mirrors `AppDelegate.persistentSyncMode` via
/// `.lifeboardPersistentSyncModeDidChange`.
@MainActor
@Observable
public final class PersistentStoreReadOnlyState {
    public static let shared = PersistentStoreReadOnlyState()

    public private(set) var isReadOnly = false

    public init() {}

    public func update(isReadOnly: Bool) {
        guard self.isReadOnly != isReadOnly else { return }
        self.isReadOnly = isReadOnly
    }
}

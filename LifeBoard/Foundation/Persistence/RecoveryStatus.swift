import Foundation

/// The health of everything that stands between a user's work and losing it.
///
/// This is a read model, not a store. Every value is aggregated from the
/// subsystem that already owns it — the persistent-store bootstrap's sync mode,
/// the journal derived index, the Notes search index — so the Recovery Center
/// never becomes a second source of truth that can disagree with the first.
///
/// Copy rule: primary text is plain language. Core Data, CloudKit, FTS5 and
/// "index generation" are implementation details a person recovering their data
/// should never have to learn. Diagnostics carry the technical detail instead.
public struct RecoveryStatus: Equatable, Sendable {
    /// Deliberately not a simple ok/error pair.
    ///
    /// `working` exists so a rebuild in progress reads as progress rather than
    /// as damage, and `attention` exists so a degraded-but-safe state is not
    /// escalated to a failure. Conflating either with `unavailable` is what
    /// makes recovery UI frightening.
    public enum Health: String, Codable, CaseIterable, Sendable {
        /// Nothing to do.
        case healthy
        /// Work is underway and expected to finish on its own.
        case working
        /// Usable, but something is degraded and the user may want to act.
        case attention
        /// The subsystem cannot be reached or is read-only.
        case unavailable
    }

    public struct Area: Identifiable, Equatable, Sendable {
        /// Stable across refreshes so rows keep identity and do not re-animate.
        public let id: String
        public let title: String
        /// One plain sentence. No jargon, no error codes.
        public let detail: String
        public let health: Health
        /// Present only when the user can actually do something about it.
        public let recovery: Recovery?

        public init(
            id: String,
            title: String,
            detail: String,
            health: Health,
            recovery: Recovery? = nil
        ) {
            self.id = id
            self.title = title
            self.detail = detail
            self.health = health
            self.recovery = recovery
        }
    }

    /// A rebuildable derived surface. Rebuilding one never touches canonical
    /// content — that is the whole reason it is safe to offer as a button.
    public enum Recovery: String, Equatable, Sendable {
        case rebuildJournalIndex
        case rebuildNotesIndex
        case rebuildHomeProjections

        public var actionTitle: String {
            switch self {
            case .rebuildJournalIndex: return String(localized: "Rebuild journal search")
            case .rebuildNotesIndex: return String(localized: "Rebuild notes search")
            case .rebuildHomeProjections: return String(localized: "Refresh Home")
            }
        }

        /// Shown before the action runs, so the user knows what is not at risk.
        public var reassurance: String {
            String(localized: "Your entries stay exactly as they are.")
        }
    }

    public var areas: [Area]
    public var generatedAt: Date

    public init(areas: [Area], generatedAt: Date) {
        self.areas = areas
        self.generatedAt = generatedAt
    }

    /// The single line shown at the top. Leads with safety, because that is the
    /// question someone opening this screen is actually asking.
    public var headline: String {
        if areas.contains(where: { $0.health == .unavailable }) {
            return String(localized: "Your data is safe. Editing is paused.")
        }
        if areas.contains(where: { $0.health == .working }) {
            return String(localized: "Still updating.")
        }
        let attention = areas.filter { $0.health == .attention }
        if attention.count == 1, let area = attention.first {
            return String(localized: "Your data is safe. \(area.detail)")
        }
        if attention.count > 1 {
            return String(localized: "Your data is safe. Check the rows below.")
        }
        return String(localized: "Everything is up to date.")
    }

    public var worstHealth: Health {
        if areas.contains(where: { $0.health == .unavailable }) { return .unavailable }
        if areas.contains(where: { $0.health == .attention }) { return .attention }
        if areas.contains(where: { $0.health == .working }) { return .working }
        return .healthy
    }
}

/// Builds a `RecoveryStatus` from the subsystems that already track it.
///
/// Each input is injected rather than read from a singleton so the composition
/// is testable without a live Core Data stack, and so a subsystem that cannot
/// report is represented honestly instead of defaulting to "healthy".
public struct RecoveryStatusService: Sendable {
    /// Mirrors `PersistentSyncMode` without depending on `AppDelegate`, keeping
    /// this type usable from tests and from any target that lacks the app class.
    public enum StoreMode: Equatable, Sendable {
        case fullSync
        case readOnly(reason: String)
    }

    /// What iCloud sync is actually doing, derived from real signals
    /// (`CloudSyncStatusStore`). `nil` from the provider means "cannot tell",
    /// and the row then claims only what is certain: saved on this device.
    public enum CloudSyncState: Equatable, Sendable {
        /// This build does not mirror to iCloud.
        case off
        /// Mirroring is on but no iCloud account is signed in.
        case noAccount
        /// An import or export is running.
        case syncing
        /// The last successful import or export.
        case synced(at: Date)
        /// Mirroring is on and nothing has completed yet this session.
        case waiting
        case paused(PauseReason)

        public enum PauseReason: Equatable, Sendable {
            case storageFull
            case offline
            case accountUnavailable
            case other
        }
    }

    public enum DerivedIndexState: Equatable, Sendable {
        case ready
        case rebuilding
        case needsRebuild
        case notApplicable
    }

    private let storeMode: @Sendable () -> StoreMode
    /// `nil` means "this subsystem cannot report right now", and the row is
    /// omitted entirely. Defaulting an unobservable subsystem to `.ready` would
    /// make the one screen a user consults about data loss the one screen that
    /// invents reassurance.
    private let journalIndex: @Sendable () -> DerivedIndexState?
    private let notesIndex: @Sendable () -> DerivedIndexState?
    private let pendingJobCount: @Sendable () -> Int
    private let cloudSync: @Sendable () -> CloudSyncState?
    private let now: @Sendable () -> Date

    public init(
        storeMode: @escaping @Sendable () -> StoreMode,
        journalIndex: @escaping @Sendable () -> DerivedIndexState?,
        notesIndex: @escaping @Sendable () -> DerivedIndexState?,
        pendingJobCount: @escaping @Sendable () -> Int,
        cloudSync: @escaping @Sendable () -> CloudSyncState? = { nil },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storeMode = storeMode
        self.journalIndex = journalIndex
        self.notesIndex = notesIndex
        self.pendingJobCount = pendingJobCount
        self.cloudSync = cloudSync
        self.now = now
    }

    public func status() -> RecoveryStatus {
        var areas: [RecoveryStatus.Area] = []

        switch storeMode() {
        case .fullSync:
            // This line used to promise iCloud sync on every full-sync
            // launch without checking — signed out, no entitlement, or
            // quota full all read "syncing". It now says only what the
            // sync signals support.
            let sync = cloudSyncPresentation(cloudSync())
            areas.append(
                .init(
                    id: "store",
                    title: String(localized: "Your work"),
                    detail: sync.detail,
                    health: sync.health
                )
            )
        case .readOnly:
            // The reason string is an internal token like
            // `persistent_store_schema_invalid`. It belongs in diagnostics, not
            // in front of someone worried about losing their journal.
            areas.append(
                .init(
                    id: "store",
                    title: String(localized: "Your work"),
                    detail: String(localized: "Read-only while LifeBoard checks your data."),
                    health: .unavailable
                )
            )
        }

        if let journal = journalIndex() {
            areas.append(
                indexArea(
                    id: "journal-index",
                    title: String(localized: "Journal search"),
                    state: journal,
                    recovery: .rebuildJournalIndex
                )
            )
        }
        if let notes = notesIndex() {
            areas.append(
                indexArea(
                    id: "notes-index",
                    title: String(localized: "Notes search"),
                    state: notes,
                    recovery: .rebuildNotesIndex
                )
            )
        }

        let jobs = pendingJobCount()
        if jobs > 0 {
            areas.append(
                .init(
                    id: "jobs",
                    title: String(localized: "Attachments"),
                    detail: jobs == 1
                        ? String(localized: "Processing 1 attachment.")
                        : String(localized: "Processing \(jobs) attachments."),
                    health: .working
                )
            )
        }

        return RecoveryStatus(areas: areas, generatedAt: now())
    }

    private func cloudSyncPresentation(
        _ state: CloudSyncState?
    ) -> (detail: String, health: RecoveryStatus.Health) {
        switch state {
        case nil:
            return (String(localized: "Saved on this device."), .healthy)
        case .off?:
            return (String(localized: "Saved on this device. iCloud sync is off."), .healthy)
        case .noAccount?:
            return (String(localized: "Saved on this device. Sign in to iCloud to sync."), .healthy)
        case .syncing?:
            return (String(localized: "Saved on this device. Syncing with iCloud…"), .healthy)
        case .waiting?:
            return (String(localized: "Saved on this device. Waiting to sync with iCloud."), .healthy)
        case .synced(let date)?:
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let elapsed = now().timeIntervalSince(date)
            let when = elapsed < 60
                ? String(localized: "just now")
                : formatter.localizedString(for: date, relativeTo: now())
            return (String(localized: "Saved on this device. Synced with iCloud \(when)."), .healthy)
        case .paused(let reason)?:
            switch reason {
            case .storageFull:
                return (
                    String(localized: "Saved on this device. iCloud storage is full."),
                    .attention
                )
            case .offline:
                return (String(localized: "Saved on this device. Syncs when you’re back online."), .healthy)
            case .accountUnavailable:
                return (
                    String(localized: "Saved on this device. iCloud is unavailable."),
                    .attention
                )
            case .other:
                return (String(localized: "Saved on this device. Sync will try again soon."), .attention)
            }
        }
    }

    private func indexArea(
        id: String,
        title: String,
        state: DerivedIndexState,
        recovery: RecoveryStatus.Recovery
    ) -> RecoveryStatus.Area {
        switch state {
        case .ready:
            return .init(id: id, title: title, detail: String(localized: "Ready."), health: .healthy)
        case .rebuilding:
            return .init(
                id: id,
                title: title,
                detail: String(localized: "Rebuilding. Recent entries may not appear yet."),
                health: .working
            )
        case .needsRebuild:
            return .init(
                id: id,
                title: title,
                detail: String(localized: "Some results may be missing."),
                health: .attention,
                recovery: recovery
            )
        case .notApplicable:
            return .init(id: id, title: title, detail: String(localized: "Nothing to search yet."), health: .healthy)
        }
    }
}

extension RecoveryStatusService {
    /// The app-wide instance.
    ///
    /// Only the persistent-store mode is wired today, because it is the only one
    /// of these subsystems that exposes a synchronous, authoritative snapshot.
    /// The journal and Notes index states return `nil` rather than a cheerful
    /// default, so their rows are absent until they can answer honestly — an
    /// absent row is recoverable, a fabricated "Ready" is not.
    static func live(
        journalIndexState: @escaping @Sendable () -> DerivedIndexState? = { nil },
        notesIndexState: @escaping @Sendable () -> DerivedIndexState? = { nil },
        pendingJobs: @escaping @Sendable () -> Int = { 0 }
    ) -> RecoveryStatusService {
        RecoveryStatusService(
            storeMode: {
                switch AppDelegate.persistentSyncModeSnapshot() {
                case .fullSync:
                    return .fullSync
                case .writeClosed(let reason):
                    return .readOnly(reason: reason)
                }
            },
            journalIndex: journalIndexState,
            notesIndex: notesIndexState,
            pendingJobCount: pendingJobs,
            cloudSync: { cloudSyncState(from: CloudSyncStatusStore.shared.snapshot) }
        )
    }

    /// Maps the recorded sync signals onto the Recovery Center's states.
    /// `nil` when the launch has not yet said whether mirroring is on.
    static func cloudSyncState(from snapshot: CloudSyncStatusStore.Snapshot) -> CloudSyncState? {
        guard let mirroringEnabled = snapshot.mirroringEnabled else { return nil }
        guard mirroringEnabled else { return .off }
        switch snapshot.accountStatus {
        case .noAccount, .restricted:
            return .noAccount
        case .temporarilyUnavailable:
            return .paused(.accountUnavailable)
        case .available, .unknown:
            break
        }
        if let pause = snapshot.pause {
            switch pause {
            case .storageFull: return .paused(.storageFull)
            case .offline: return .paused(.offline)
            case .accountUnavailable: return .paused(.accountUnavailable)
            case .other: return .paused(.other)
            }
        }
        if snapshot.inFlightEventCount > 0 { return .syncing }
        if let last = snapshot.lastSyncAt { return .synced(at: last) }
        return .waiting
    }

    /// Classifies a derived index from what it actually contains.
    ///
    /// `nil` in, `nil` out: an index that cannot report its own contents is
    /// omitted from the Recovery Center rather than shown as healthy. An index
    /// with rows is ready; an empty index is only "needs rebuild" when there is
    /// source content it should have covered — an empty index over an empty
    /// journal is correct, not broken.
    public static func classifyIndex(
        indexedItemCount: Int?,
        sourceItemCount: Int
    ) -> DerivedIndexState? {
        guard let indexedItemCount else { return nil }
        if indexedItemCount > 0 { return .ready }
        return sourceItemCount > 0 ? .needsRebuild : .notApplicable
    }
}

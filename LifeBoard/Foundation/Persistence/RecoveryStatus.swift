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
            case .rebuildJournalIndex: return "Rebuild journal search"
            case .rebuildNotesIndex: return "Rebuild notes search"
            case .rebuildHomeProjections: return "Refresh home"
            }
        }

        /// Shown before the action runs, so the user knows what is not at risk.
        public var reassurance: String {
            "Your entries stay exactly as they are. Only the search shortcut is rebuilt."
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
            return "Your data is safe. Some editing is paused."
        }
        if areas.contains(where: { $0.health == .working }) {
            return "Your data is safe. Some things are still catching up."
        }
        if areas.contains(where: { $0.health == .attention }) {
            return "Your data is safe. One thing could use attention."
        }
        return "Everything is up to date."
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
    private let now: @Sendable () -> Date

    public init(
        storeMode: @escaping @Sendable () -> StoreMode,
        journalIndex: @escaping @Sendable () -> DerivedIndexState?,
        notesIndex: @escaping @Sendable () -> DerivedIndexState?,
        pendingJobCount: @escaping @Sendable () -> Int,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storeMode = storeMode
        self.journalIndex = journalIndex
        self.notesIndex = notesIndex
        self.pendingJobCount = pendingJobCount
        self.now = now
    }

    public func status() -> RecoveryStatus {
        var areas: [RecoveryStatus.Area] = []

        switch storeMode() {
        case .fullSync:
            areas.append(
                .init(
                    id: "store",
                    title: "Your work",
                    detail: "Saved on this device and syncing to your private iCloud.",
                    health: .healthy
                )
            )
        case .readOnly:
            // The reason string is an internal token like
            // `persistent_store_schema_invalid`. It belongs in diagnostics, not
            // in front of someone worried about losing their journal.
            areas.append(
                .init(
                    id: "store",
                    title: "Your work",
                    detail: "Everything you have written is safe, but editing is paused while the app checks its private copy.",
                    health: .unavailable
                )
            )
        }

        if let journal = journalIndex() {
            areas.append(
                indexArea(
                    id: "journal-index",
                    title: "Journal search",
                    state: journal,
                    recovery: .rebuildJournalIndex
                )
            )
        }
        if let notes = notesIndex() {
            areas.append(
                indexArea(
                    id: "notes-index",
                    title: "Notes search",
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
                    title: "Finishing up",
                    detail: jobs == 1
                        ? "One attachment is still being processed."
                        : "\(jobs) attachments are still being processed.",
                    health: .working
                )
            )
        }

        return RecoveryStatus(areas: areas, generatedAt: now())
    }

    private func indexArea(
        id: String,
        title: String,
        state: DerivedIndexState,
        recovery: RecoveryStatus.Recovery
    ) -> RecoveryStatus.Area {
        switch state {
        case .ready:
            return .init(id: id, title: title, detail: "Ready.", health: .healthy)
        case .rebuilding:
            return .init(
                id: id,
                title: title,
                detail: "Rebuilding. Searching may miss recent items until it finishes.",
                health: .working
            )
        case .needsRebuild:
            return .init(
                id: id,
                title: title,
                detail: "Some items may not appear in search yet.",
                health: .attention,
                recovery: recovery
            )
        case .notApplicable:
            return .init(id: id, title: title, detail: "Not set up yet.", health: .healthy)
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
            pendingJobCount: pendingJobs
        )
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

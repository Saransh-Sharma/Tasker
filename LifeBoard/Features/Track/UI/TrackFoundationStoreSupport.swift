import Foundation

/// Remembers which routine run was minimized across stores and launches.
enum RoutineRunnerMinimizeMemory {
    static let defaultsKey = "lifeboard.track.routineRunner.minimizedRunID"

    static func load(from defaults: UserDefaults = .standard) -> UUID? {
        defaults.string(forKey: defaultsKey).flatMap(UUID.init(uuidString:))
    }

    static func save(_ id: UUID?, to defaults: UserDefaults = .standard) {
        if let id {
            defaults.set(id.uuidString, forKey: defaultsKey)
        } else {
            defaults.removeObject(forKey: defaultsKey)
        }
    }
}

enum TrackHydrationReceiptAnchor: Equatable, Sendable {
    /// The Water button in the Quick log strip.
    case quickLog
    /// The +250 / +500 buttons on the hydration tile.
    case hydrationTile
}

/// A deleted Track record and the write that restores it.
struct TrackDeletionReceipt: Identifiable {
    enum Domain: Hashable, Sendable { case hydration, sleep, mood }

    let id = UUID()
    let domain: Domain
    let message: String
    let restore: @MainActor () async throws -> Void

    var presentation: ActionReceiptPresentation {
        ActionReceiptPresentation(id: id, message: message)
    }
}

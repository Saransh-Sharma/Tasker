import Foundation
import LifeBoardDomain

public struct RestorationState: Codable, Equatable, Sendable {
    public var selectedDestination: Destination
    public var paths: [Destination: [AppRoute]]
    public var dashboardMode: DashboardMode
    public var daypartSelection: DaypartSelection
    public var recoverableCaptureDraftID: UUID?

    public init(
        selectedDestination: Destination = .home,
        paths: [Destination: [AppRoute]] = [:],
        dashboardMode: DashboardMode = .smart,
        daypartSelection: DaypartSelection = .automatic,
        recoverableCaptureDraftID: UUID? = nil
    ) {
        self.selectedDestination = selectedDestination
        self.paths = paths
        self.dashboardMode = dashboardMode
        self.daypartSelection = daypartSelection
        self.recoverableCaptureDraftID = recoverableCaptureDraftID
    }
}

/// Serializes and coalesces restoration writes away from navigation's main-
/// actor interaction path. A generation check prevents an older delayed write
/// from overwriting a newer selection or navigation path.
struct RestorationEnvelope: Sendable {
    let sequence: UInt64
    let state: RestorationState
}

actor RestorationWriter {
    struct ThreadSafeDefaults: @unchecked Sendable {
        let value: UserDefaults
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private var generation = 0
    private var latestSequence: UInt64 = 0
    private var pendingTask: Task<Void, Never>?

    init(defaults: ThreadSafeDefaults) {
        self.defaults = defaults.value
    }

    func enqueue(_ envelope: RestorationEnvelope) {
        guard envelope.sequence > latestSequence else { return }
        latestSequence = envelope.sequence
        let state = envelope.state
        generation &+= 1
        let candidateGeneration = generation
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard Task.isCancelled == false else { return }
            await self?.commit(state, generation: candidateGeneration)
        }
    }

    func flush(_ envelope: RestorationEnvelope) {
        guard envelope.sequence > latestSequence else { return }
        latestSequence = envelope.sequence
        let state = envelope.state
        generation &+= 1
        pendingTask?.cancel()
        pendingTask = nil
        write(state)
    }

    private func commit(_ state: RestorationState, generation candidate: Int) {
        guard candidate == generation else { return }
        pendingTask = nil
        write(state)
    }

    private func write(_ state: RestorationState) {
        guard let data = try? encoder.encode(state) else { return }
        defaults.set(data, forKey: FoundationPreferenceKey.restorationState)
    }
}

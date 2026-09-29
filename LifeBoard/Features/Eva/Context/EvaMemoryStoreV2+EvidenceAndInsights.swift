import Foundation

// MARK: - Evidence Lens and shared intelligence state

struct EvaEvidenceExclusion: Codable, Equatable, Identifiable, Sendable {
    var sourceID: UUID
    var kind: String
    var display: String
    var excludedAt: Date

    var id: String { "\(kind.lowercased()):\(sourceID.uuidString)" }
}

enum EvaEvidenceExclusionStore {
    private static let key = "eva.evidence-exclusions.v1"
    private static let lock = NSLock()

    static func all(defaults: UserDefaults = .standard) -> [EvaEvidenceExclusion] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([EvaEvidenceExclusion].self, from: data) else { return [] }
        return values.sorted { $0.excludedAt > $1.excludedAt }
    }

    static func exclude(_ event: NormalizedLifeEvent, defaults: UserDefaults = .standard) {
        var values = all(defaults: defaults)
        let evidence = event.evidence.first
        let value = EvaEvidenceExclusion(
            sourceID: event.sourceID,
            kind: evidence?.kind ?? event.kind,
            display: evidence?.display ?? event.provenance,
            excludedAt: Date()
        )
        values.removeAll { $0.id == value.id }
        values.append(value)
        save(values, defaults: defaults)
    }

    static func restore(id: String, defaults: UserDefaults = .standard) {
        save(all(defaults: defaults).filter { $0.id != id }, defaults: defaults)
    }

    static func isExcluded(_ event: NormalizedLifeEvent, defaults: UserDefaults = .standard) -> Bool {
        let keys = Set(all(defaults: defaults).map(\.id))
        let evidenceKind = event.evidence.first?.kind ?? event.kind
        return keys.contains("\(evidenceKind.lowercased()):\(event.sourceID.uuidString)")
    }

    static func applying(to event: NormalizedLifeEvent, defaults: UserDefaults = .standard) -> NormalizedLifeEvent {
        guard isExcluded(event, defaults: defaults) else { return event }
        var value = event
        value.allowedDestinations.subtract([.eva, .insights, .home])
        return value
    }

    private static func save(_ values: [EvaEvidenceExclusion], defaults: UserDefaults) {
        lock.lock()
        defer { lock.unlock() }
        defaults.set(try? JSONEncoder().encode(values), forKey: key)
    }
}

struct EvaInsightState: Codable, Equatable, Sendable {
    var dismissedInsightIDs: Set<String> = []
    var proactiveHistory = EvaProactiveHistory()
}

enum EvaInsightStateStore {
    private static let key = "eva.insight-state.v1"

    static func load(defaults: UserDefaults = .standard) -> EvaInsightState {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(EvaInsightState.self, from: data) else { return .init() }
        return value
    }

    static func dismiss(insightID: String, kind: String, now: Date = Date(), defaults: UserDefaults = .standard) {
        var value = load(defaults: defaults)
        value.dismissedInsightIDs.insert(insightID)
        value.proactiveHistory.dismissals.append(.init(kind: kind, dismissedAt: now))
        save(value, defaults: defaults)
    }

    static func recordDelivery(insightID: String, kind: String, at date: Date = Date(), defaults: UserDefaults = .standard) {
        var value = load(defaults: defaults)
        value.proactiveHistory.deliveries.append(.init(insightID: insightID, kind: kind, deliveredAt: date))
        value.proactiveHistory.deliveries = Array(value.proactiveHistory.deliveries.suffix(100))
        save(value, defaults: defaults)
    }

    static func restore(insightID: String, defaults: UserDefaults = .standard) {
        var value = load(defaults: defaults)
        value.dismissedInsightIDs.remove(insightID)
        save(value, defaults: defaults)
    }

    static func isDismissed(_ insightID: String, defaults: UserDefaults = .standard) -> Bool {
        load(defaults: defaults).dismissedInsightIDs.contains(insightID)
    }

    private static func save(_ value: EvaInsightState, defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

actor EvaProactiveCoordinator {
    static let shared = EvaProactiveCoordinator()

    func admitted(_ candidates: [EvaProactiveCandidate], now: Date = Date()) -> [EvaProactiveCandidate] {
        var admitted: [EvaProactiveCandidate] = []
        for candidate in candidates {
            let state = EvaInsightStateStore.load()
            guard state.dismissedInsightIDs.contains(candidate.insight.id) == false else { continue }
            if state.proactiveHistory.deliveries.contains(where: { $0.insightID == candidate.insight.id }) {
                admitted.append(candidate)
                continue
            }
            guard case .deliver = EvaProactivityPolicy.decision(for: candidate, now: now) else { continue }
            EvaInsightStateStore.recordDelivery(insightID: candidate.insight.id, kind: candidate.kind, at: now)
            admitted.append(candidate)
        }
        return admitted
    }

    func dismiss(_ candidate: EvaProactiveCandidate, now: Date = Date()) {
        EvaInsightStateStore.dismiss(insightID: candidate.insight.id, kind: candidate.kind, now: now)
    }
}

enum EvaProactivityPolicy {
    static func decision(
        for candidate: EvaProactiveCandidate,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> EvaProactiveDecision {
        let preferences = NotificationPreferencesStore.shared.load()
        let quiet = preferences.quietHoursEnabled
            ? EvaQuietHours(
                startMinute: preferences.quietHoursStartHour * 60 + preferences.quietHoursStartMinute,
                endMinute: preferences.quietHoursEndHour * 60 + preferences.quietHoursEndMinute
            )
            : nil
        return EvaProactiveGovernor().evaluate(
            candidate,
            history: EvaInsightStateStore.load(defaults: defaults).proactiveHistory,
            quietHours: quiet,
            now: now
        )
    }
}

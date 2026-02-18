import Foundation

public final class ReminderMergeEngine {
    public enum TombstoneDecision: Equatable {
        case keep
        case applyDelete(clock: SyncClock)
        case resurrect(clock: SyncClock)
    }

    public enum MergeWinner: String, Equatable {
        case local
        case remote
        case unchanged
    }

    public struct MergeInput {
        public var nodeID: String
        public var provider: String
        public var localObservedAt: Date
        public var remoteClock: SyncClock
        public var state: ReminderMergeState
        public var previousKnown: ReminderMergeEnvelope.KnownFields?
        public var localKnown: ReminderMergeEnvelope.KnownFields
        public var remoteKnown: ReminderMergeEnvelope.KnownFields
        public var hasRemoteItem: Bool
        public var lastSeenRemoteModification: Date?

        public init(
            nodeID: String,
            provider: String,
            localObservedAt: Date,
            remoteClock: SyncClock,
            state: ReminderMergeState,
            previousKnown: ReminderMergeEnvelope.KnownFields?,
            localKnown: ReminderMergeEnvelope.KnownFields,
            remoteKnown: ReminderMergeEnvelope.KnownFields,
            hasRemoteItem: Bool,
            lastSeenRemoteModification: Date?
        ) {
            self.nodeID = nodeID
            self.provider = provider
            self.localObservedAt = localObservedAt
            self.remoteClock = remoteClock
            self.state = state
            self.previousKnown = previousKnown
            self.localKnown = localKnown
            self.remoteKnown = remoteKnown
            self.hasRemoteItem = hasRemoteItem
            self.lastSeenRemoteModification = lastSeenRemoteModification
        }
    }

    public struct MergeResult {
        public var known: ReminderMergeEnvelope.KnownFields
        public var state: ReminderMergeState
        public var tombstoneDecision: TombstoneDecision
        public var winner: MergeWinner

        public init(
            known: ReminderMergeEnvelope.KnownFields,
            state: ReminderMergeState,
            tombstoneDecision: TombstoneDecision,
            winner: MergeWinner
        ) {
            self.known = known
            self.state = state
            self.tombstoneDecision = tombstoneDecision
            self.winner = winner
        }
    }

    public init() {}

    public func merge(input: MergeInput) -> MergeResult {
        var state = input.state
        var localWins = 0
        var remoteWins = 0
        var localWriteClock: SyncClock?
        var remoteWriteClock: SyncClock?

        func localCandidate(for field: ReminderScalarField, changed: Bool) -> SyncClock? {
            guard changed else {
                return nil
            }
            let observedMillis = Int64(input.localObservedAt.timeIntervalSince1970 * 1_000)
            let base = maxClock(state.fieldClocks[field], state.lastWriteClock)
            let next = SyncClock.next(
                nodeID: input.nodeID,
                base: base,
                observedMillis: observedMillis
            )
            localWriteClock = maxClock(localWriteClock, next)
            return next
        }

        func remoteCandidate(changed: Bool) -> SyncClock? {
            guard changed else {
                return nil
            }
            remoteWriteClock = maxClock(remoteWriteClock, input.remoteClock)
            return input.remoteClock
        }

        func resolveScalar<T: Equatable>(
            field: ReminderScalarField,
            localValue: T,
            remoteValue: T,
            priorValue: T?
        ) -> T {
            let localChanged = priorValue.map { $0 != localValue } ?? true
            let remoteChanged = priorValue.map { $0 != remoteValue } ?? true
            let localClock = localCandidate(for: field, changed: localChanged)
            let remoteClock = remoteCandidate(changed: remoteChanged)
            let winningClock = winningClockFor(
                local: localClock,
                remote: remoteClock,
                fallback: state.fieldClocks[field]
            )

            if let winningClock {
                state.fieldClocks[field] = winningClock
            }

            switch decideWinner(local: localClock, remote: remoteClock) {
            case .local:
                localWins += 1
                return localValue
            case .remote:
                remoteWins += 1
                return remoteValue
            case .unchanged:
                return priorValue ?? remoteValue
            }
        }

        let mergedTitle = resolveScalar(
            field: .title,
            localValue: input.localKnown.title,
            remoteValue: input.remoteKnown.title,
            priorValue: input.previousKnown?.title
        )
        let mergedNotes = resolveScalar(
            field: .notes,
            localValue: input.localKnown.notes,
            remoteValue: input.remoteKnown.notes,
            priorValue: input.previousKnown?.notes
        )
        let mergedDueDate = resolveScalar(
            field: .dueDate,
            localValue: input.localKnown.dueDate,
            remoteValue: input.remoteKnown.dueDate,
            priorValue: input.previousKnown?.dueDate
        )
        let mergedCompletionDate = resolveScalar(
            field: .completionDate,
            localValue: input.localKnown.completionDate,
            remoteValue: input.remoteKnown.completionDate,
            priorValue: input.previousKnown?.completionDate
        )
        let mergedCompleted = resolveScalar(
            field: .isCompleted,
            localValue: input.localKnown.isCompleted,
            remoteValue: input.remoteKnown.isCompleted,
            priorValue: input.previousKnown?.isCompleted
        )
        let mergedPriority = resolveScalar(
            field: .priority,
            localValue: input.localKnown.priority,
            remoteValue: input.remoteKnown.priority,
            priorValue: input.previousKnown?.priority
        )
        let mergedURL = resolveScalar(
            field: .urlString,
            localValue: input.localKnown.urlString,
            remoteValue: input.remoteKnown.urlString,
            priorValue: input.previousKnown?.urlString
        )

        let mergedAlarmDates = mergeAlarmDates(
            state: &state,
            localAlarmDates: input.localKnown.alarmDates,
            remoteAlarmDates: input.remoteKnown.alarmDates,
            priorAlarmDates: input.previousKnown?.alarmDates ?? [],
            localClock: localWriteClock,
            remoteClock: remoteWriteClock
        )

        let mergedKnown = ReminderMergeEnvelope.KnownFields(
            title: mergedTitle,
            notes: mergedNotes,
            dueDate: mergedDueDate,
            completionDate: mergedCompletionDate,
            isCompleted: mergedCompleted,
            priority: mergedPriority,
            urlString: mergedURL,
            alarmDates: mergedAlarmDates
        )

        let latestWriteClock = maxClock(localWriteClock, remoteWriteClock)
        state.lastWriteClock = maxClock(state.lastWriteClock, latestWriteClock)

        let winner: MergeWinner = {
            if localWins > remoteWins { return .local }
            if remoteWins > localWins { return .remote }
            return .unchanged
        }()

        let tombstoneDecision = resolveTombstone(
            hasRemoteItem: input.hasRemoteItem,
            provider: input.provider,
            state: &state,
            latestWriteClock: latestWriteClock,
            remoteClock: input.remoteClock,
            nodeID: input.nodeID,
            lastSeenRemoteModification: input.lastSeenRemoteModification
        )

        return MergeResult(
            known: mergedKnown,
            state: state,
            tombstoneDecision: tombstoneDecision,
            winner: winner
        )
    }

    public func decodeEnvelope(data: Data?) -> ReminderMergeEnvelope? {
        guard let data else { return nil }
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(ReminderMergeEnvelope.self, from: data) {
            return envelope
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let title = object["title"] as? String
        else {
            return nil
        }
        let known = ReminderMergeEnvelope.KnownFields(
            title: title,
            notes: object["notes"] as? String,
            dueDate: Self.decodeDate(object["dueDate"]),
            completionDate: Self.decodeDate(object["completionDate"]),
            isCompleted: object["isCompleted"] as? Bool ?? false,
            priority: object["priority"] as? Int ?? 0,
            urlString: object["urlString"] as? String,
            alarmDates: (object["alarmDates"] as? [Any] ?? []).compactMap(Self.decodeDate)
        )
        // Preserve unknown legacy payload bytes by carrying the original blob forward as passthrough.
        return ReminderMergeEnvelope(known: known, passthroughData: data)
    }

    public func encodeEnvelope(
        known: ReminderMergeEnvelope.KnownFields,
        preferredPassthroughData: Data?,
        fallbackPassthroughData: Data?
    ) -> Data? {
        let envelope = ReminderMergeEnvelope(
            known: known,
            passthroughData: preferredPassthroughData ?? fallbackPassthroughData
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(envelope)
    }

    public static func alarmDateKey(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    public static func alarmDate(from key: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: key)
    }

    private static func decodeDate(_ raw: Any?) -> Date? {
        switch raw {
        case let value as Date:
            return value
        case let value as String:
            return ISO8601DateFormatter().date(from: value)
        case let value as NSNumber:
            return Date(timeIntervalSince1970: value.doubleValue)
        default:
            return nil
        }
    }

    private func mergeAlarmDates(
        state: inout ReminderMergeState,
        localAlarmDates: [Date],
        remoteAlarmDates: [Date],
        priorAlarmDates: [Date],
        localClock: SyncClock?,
        remoteClock: SyncClock?
    ) -> [Date] {
        let localKeys = Set(localAlarmDates.map(Self.alarmDateKey))
        let remoteKeys = Set(remoteAlarmDates.map(Self.alarmDateKey))
        let priorKeys = Set(priorAlarmDates.map(Self.alarmDateKey))

        var addSet = state.alarmAddSet
        var removeSet = state.alarmRemoveSet

        let localChanged = localKeys != priorKeys
        let remoteChanged = remoteKeys != priorKeys

        if localChanged, let localClock {
            for key in localKeys {
                addSet[key] = maxClock(addSet[key], localClock)
            }
            for key in priorKeys.subtracting(localKeys) {
                removeSet[key] = maxClock(removeSet[key], localClock)
            }
        }

        if remoteChanged, let remoteClock {
            for key in remoteKeys {
                addSet[key] = maxClock(addSet[key], remoteClock)
            }
            for key in priorKeys.subtracting(remoteKeys) {
                removeSet[key] = maxClock(removeSet[key], remoteClock)
            }
        }

        state.alarmAddSet = addSet
        state.alarmRemoveSet = removeSet

        let allKeys = Set(addSet.keys).union(removeSet.keys).union(localKeys).union(remoteKeys).union(priorKeys)
        let merged = allKeys.compactMap { key -> Date? in
            guard let addClock = addSet[key] else {
                return nil
            }
            if let removeClock = removeSet[key], removeClock >= addClock {
                return nil
            }
            return Self.alarmDate(from: key)
        }
        return merged.sorted()
    }

    private func resolveTombstone(
        hasRemoteItem: Bool,
        provider: String,
        state: inout ReminderMergeState,
        latestWriteClock: SyncClock?,
        remoteClock: SyncClock,
        nodeID: String,
        lastSeenRemoteModification: Date?
    ) -> TombstoneDecision {
        if hasRemoteItem == false {
            let observedMillis = Int64((lastSeenRemoteModification ?? Date()).timeIntervalSince1970 * 1_000)
            let base = maxClock(state.lastWriteClock, state.tombstoneClock)
            let deletionClock = SyncClock.next(
                nodeID: "remote.\(provider)",
                base: base,
                observedMillis: observedMillis
            )
            if let latestWriteClock, latestWriteClock > deletionClock {
                state.tombstoneClock = nil
                state.lastWriteClock = maxClock(state.lastWriteClock, latestWriteClock)
                return .resurrect(clock: latestWriteClock)
            }
            state.tombstoneClock = maxClock(state.tombstoneClock, deletionClock)
            state.lastWriteClock = maxClock(state.lastWriteClock, deletionClock)
            return .applyDelete(clock: deletionClock)
        }

        guard let tombstone = state.tombstoneClock else {
            return .keep
        }

        let liveClock = maxClock(latestWriteClock, remoteClock)
        if let liveClock, liveClock > tombstone {
            state.tombstoneClock = nil
            state.lastWriteClock = maxClock(state.lastWriteClock, liveClock)
            return .resurrect(clock: liveClock)
        }

        state.lastWriteClock = maxClock(state.lastWriteClock, tombstone)
        return .applyDelete(clock: tombstone)
    }

    private func decideWinner(local: SyncClock?, remote: SyncClock?) -> MergeWinner {
        switch (local, remote) {
        case let (local?, remote?):
            if local == remote { return .unchanged }
            return local > remote ? .local : .remote
        case (.some, .none):
            return .local
        case (.none, .some):
            return .remote
        case (.none, .none):
            return .unchanged
        }
    }

    private func winningClockFor(
        local: SyncClock?,
        remote: SyncClock?,
        fallback: SyncClock?
    ) -> SyncClock? {
        maxClock(maxClock(local, remote), fallback)
    }

    private func maxClock(_ lhs: SyncClock?, _ rhs: SyncClock?) -> SyncClock? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return lhs > rhs ? lhs : rhs
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }
}

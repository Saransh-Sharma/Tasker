import Foundation
import UIKit

extension TrackFoundationStore {
    func installStarterPack(_ preview: StarterPackPreview) async {
        let selected = preview.items.filter(\.isSelected)
        var createdIDs: [StarterPackItemKind: Set<UUID>] = [:]
        var createdGoals: [GoalDefinition] = []
        var createdRoutines: [RoutineDefinition] = []
        do {
            for item in selected {
                switch item.kind {
                case .goal:
                    let goal = GoalDefinition(title: item.title, type: .completion)
                    try await repository.saveGoal(goal)
                    createdGoals.append(goal)
                    createdIDs[.goal, default: []].insert(goal.id)
                case .routine:
                    let steps = Self.steps(for: preview.pack)
                    let routine = RoutineDefinition(title: item.title, steps: steps)
                    try await repository.saveRoutine(routine)
                    try await repository.saveRoutineSchedule(Self.defaultSchedule(for: preview.pack, routineID: routine.id))
                    createdRoutines.append(routine)
                    createdIDs[.routine, default: []].insert(routine.id)
                case .habit, .reminder:
                    guard let starterPackMutationApplier else {
                        throw NSError(
                            domain: "LifeBoard.StarterPack",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "Couldn’t add habits. Try again.")]
                        )
                    }
                    let id = try await starterPackMutationApplier.createHabit(
                        title: item.title,
                        pack: preview.pack,
                        itemKind: item.kind
                    )
                    createdIDs[item.kind, default: []].insert(id)
                }
            }
            try await repository.saveStarterPackInstallation(.init(pack: preview.pack, createdIDs: createdIDs))
            await load()
        } catch {
            for var goal in createdGoals {
                goal.isArchived = true
                goal.updatedAt = Date()
                try? await repository.saveGoal(goal)
            }
            for var routine in createdRoutines {
                routine.isArchived = true
                routine.updatedAt = Date()
                try? await repository.saveRoutine(routine)
            }
            if let starterPackMutationApplier {
                let habitIDs = (createdIDs[.habit] ?? []).union(createdIDs[.reminder] ?? [])
                for id in habitIDs { try? await starterPackMutationApplier.archiveHabit(id: id) }
            }
            errorMessage = Self.readableFailure(error)
            await load()
        }
    }

    func removeStarterPack(_ installation: StarterPackInstallation) async {
        guard installation.removedAt == nil else { return }
        do {
            let goalIDs = installation.createdIDs[.goal] ?? []
            for var goal in definitions where goalIDs.contains(goal.id) {
                goal.isArchived = true
                goal.updatedAt = Date()
                try await repository.saveGoal(goal)
            }
            let routineIDs = installation.createdIDs[.routine] ?? []
            for var routine in routines where routineIDs.contains(routine.id) {
                routine.isArchived = true
                routine.updatedAt = Date()
                try await repository.saveRoutine(routine)
            }
            if let starterPackMutationApplier {
                let habitIDs = (installation.createdIDs[.habit] ?? []).union(installation.createdIDs[.reminder] ?? [])
                for id in habitIDs {
                    try await starterPackMutationApplier.archiveHabit(id: id)
                }
            }
            var removed = installation
            removed.removedAt = Date()
            try await repository.saveStarterPackInstallation(removed)
            await load()
        } catch { errorMessage = Self.readableFailure(error) }
    }

    private static func steps(for pack: StarterPack) -> [RoutineStep] {
        switch pack {
        case .morningFoundation:
            [.init(title: String(localized: "Rate your energy"), kind: .checkIn, ordinal: 0), .init(title: String(localized: "Pick today’s theme"), kind: .choice, ordinal: 1, choices: [String(localized: "Focus"), String(localized: "Care"), String(localized: "Recovery")])]
        case .workdayReset:
            [.init(title: String(localized: "Close distractions"), kind: .instruction, ordinal: 0), .init(title: String(localized: "Slow breathing"), kind: .timer, ordinal: 1, duration: 120)]
        case .lowEnergyRecovery:
            [.init(title: String(localized: "Pick what you need"), kind: .choice, ordinal: 0, choices: [String(localized: "Rest"), String(localized: "Water"), String(localized: "A smaller step")]), .init(title: String(localized: "Do one thing"), kind: .instruction, ordinal: 1)]
        case .medicationSupport:
            [.init(title: String(localized: "Check medications"), kind: .instruction, ordinal: 0), .init(title: String(localized: "Log doses"), kind: .checkIn, ordinal: 1)]
        case .eveningWindDown:
            [.init(title: String(localized: "Close the day"), kind: .instruction, ordinal: 0), .init(title: String(localized: "Quick reflection"), kind: .checkIn, ordinal: 1, isRequired: false, isSkippable: true)]
        }
    }

    private static func defaultSchedule(for pack: StarterPack, routineID: UUID) -> RoutineSchedule {
        let daypart: ResolvedDaypart
        switch pack {
        case .morningFoundation: daypart = .morning
        case .workdayReset, .lowEnergyRecovery, .medicationSupport: daypart = .afternoon
        case .eveningWindDown: daypart = .evening
        }
        return RoutineSchedule(routineID: routineID, weekdays: Set(1...7), daypart: daypart)
    }
}

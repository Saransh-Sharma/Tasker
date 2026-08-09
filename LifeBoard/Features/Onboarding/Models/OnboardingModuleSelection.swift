import Foundation

/// One thing the user can choose to track, and everything that choice implies.
///
/// Onboarding used to introduce a habit and a task and nothing else, so journal,
/// nutrition, fasting, wellness, focus, goals, routines, and life moments all
/// shipped invisible — and the Home cards that depend on them stayed empty
/// forever. A module is the single place that ties a user-facing choice to the
/// Home cards it fills, the permissions it needs, and the setup it seeds.
struct OnboardingTrackableModule: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// One short line. What you get — not how it works.
    let blurb: String
    /// SF Symbol only — never an emoji (design contract).
    let symbolName: String
    /// Home cards this module fills, in placement order.
    let homeCardKinds: [DashboardWidgetKind]
    /// Apple Health domains this module reads or writes.
    let healthDomains: Set<HealthDomain>
    /// Whether the module's reminders are meaningless without notifications.
    let needsNotifications: Bool
    /// Permissions iOS asks for at the point of use. Onboarding explains these
    /// but must not request them — that would mean two dialogs for one action.
    let pointOfUsePermissions: [PermissionKind]
    /// Whether the surface is compiled into this build at all.
    let isAvailable: Bool
}

enum OnboardingModuleCatalog {
    static let habitsID = "habits"
    static let moodID = "mood"
    static let hydrationID = "hydration"
    static let medicationID = "medication"
    static let journalID = "journal"
    static let nutritionID = "nutrition"
    static let fastingID = "fasting"
    static let bodyID = "body"
    static let focusID = "focus"
    static let goalsID = "goals"
    static let momentsID = "moments"
    static let notesID = "notes"

    /// Every module, with its availability resolved against the current build.
    /// Unavailable modules are filtered out rather than shown disabled — offering
    /// a choice that cannot be honoured is worse than not offering it.
    static var all: [OnboardingTrackableModule] {
        [
            OnboardingTrackableModule(
                id: habitsID,
                title: "Habits",
                blurb: "Build consistency without a streak to break.",
                symbolName: "repeat",
                homeCardKinds: [],
                healthDomains: [],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: true
            ),
            OnboardingTrackableModule(
                id: moodID,
                title: "Mood & energy",
                blurb: "A quick check-in, no scoring.",
                symbolName: "face.smiling",
                homeCardKinds: [.lifeSnapshot],
                healthDomains: [],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.careModulesV2Enabled
            ),
            OnboardingTrackableModule(
                id: hydrationID,
                title: "Hydration",
                blurb: "Water you drink, against a target you set.",
                symbolName: "drop",
                homeCardKinds: [],
                healthDomains: [.hydration],
                needsNotifications: false,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.careModulesV2Enabled
            ),
            OnboardingTrackableModule(
                id: medicationID,
                title: "Medication",
                blurb: "Doses and windows, confirmed by you.",
                symbolName: "pills",
                homeCardKinds: [.care],
                healthDomains: [],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.careModulesV2Enabled
            ),
            OnboardingTrackableModule(
                id: journalID,
                title: "Journal",
                blurb: "Write, speak, or photograph the day.",
                symbolName: "book.closed",
                homeCardKinds: [.journal],
                healthDomains: [],
                needsNotifications: false,
                pointOfUsePermissions: [.microphone, .speech],
                isAvailable: V2FeatureFlags.journalV1Enabled
            ),
            OnboardingTrackableModule(
                id: nutritionID,
                title: "Nutrition",
                blurb: "Meals and macros, against a goal you set.",
                symbolName: "fork.knife",
                homeCardKinds: [.nutritionSummary, .recentMeal, .logMeal],
                healthDomains: [.nutrition],
                needsNotifications: false,
                pointOfUsePermissions: [.camera],
                isAvailable: V2FeatureFlags.nutritionV1Enabled
            ),
            OnboardingTrackableModule(
                id: fastingID,
                title: "Fasting",
                blurb: "A timer you start, with honest history.",
                symbolName: "hourglass",
                homeCardKinds: [.fasting],
                healthDomains: [.fasting],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.fastingV2Enabled
            ),
            OnboardingTrackableModule(
                id: bodyID,
                title: "Body & workouts",
                blurb: "Weight, workouts, sleep, and movement.",
                symbolName: "figure.run",
                homeCardKinds: [.bodyMetric, .workout, .sleep, .movement],
                healthDomains: [.body, .workouts, .sleep, .activity, .energy],
                needsNotifications: false,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.wellnessCoreV1Enabled
            ),
            OnboardingTrackableModule(
                id: focusID,
                title: "Focus sessions",
                blurb: "Timed work on one thing at a time.",
                symbolName: "timer",
                homeCardKinds: [.focusNow],
                healthDomains: [],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.focusExecutionV2Enabled
            ),
            OnboardingTrackableModule(
                id: goalsID,
                title: "Goals & routines",
                blurb: "Longer arcs, and the steps that feed them.",
                symbolName: "target",
                homeCardKinds: [.goals, .routines],
                healthDomains: [],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.goalsRoutinesV1Enabled
            ),
            OnboardingTrackableModule(
                id: momentsID,
                title: "Life moments",
                blurb: "Countdowns to what you are waiting for.",
                symbolName: "sparkles",
                homeCardKinds: [.lifeMoment],
                healthDomains: [],
                needsNotifications: true,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.lifeMomentsV1Enabled
            ),
            OnboardingTrackableModule(
                id: notesID,
                title: "Notes",
                blurb: "Somewhere to put the rest of it.",
                symbolName: "note.text",
                homeCardKinds: [],
                healthDomains: [],
                needsNotifications: false,
                pointOfUsePermissions: [],
                isAvailable: V2FeatureFlags.knowledgeNotesV1Enabled
            )
        ].filter(\.isAvailable)
    }

    static func module(id: String) -> OnboardingTrackableModule? {
        all.first { $0.id == id }
    }

    /// What the intent chosen two steps earlier suggests. Preselected, never
    /// forced — the grid stays fully editable.
    static func recommended(for goal: OnboardingPrimaryGoal?) -> Set<String> {
        let base: Set<String> = [habitsID, moodID]
        guard let goal else { return base }
        switch goal {
        case .wholeWeek:
            return base.union([focusID, goalsID])
        case .workDeadlines:
            return base.union([focusID])
        case .lifeAdmin:
            return base.union([medicationID])
        case .habitsRoutines:
            return base.union([goalsID])
        case .calendarChaos:
            return base.union([focusID])
        case .dailyExecution:
            return base.union([journalID])
        }
    }

    // MARK: - Derived consequences

    /// The Apple Health domains implied by a selection.
    static func healthDomains(for selection: Set<String>) -> Set<HealthDomain> {
        all.filter { selection.contains($0.id) }
            .reduce(into: Set<HealthDomain>()) { $0.formUnion($1.healthDomains) }
    }

    /// The permissions the onboarding step should actually ask for. Calendar is
    /// always included: it fills two cards that ship in every Home layout.
    static func requestablePermissions(for selection: Set<String>) -> [PermissionKind] {
        var kinds: [PermissionKind] = []
        if all.contains(where: { selection.contains($0.id) && $0.needsNotifications }) {
            kinds.append(.notifications)
        }
        kinds.append(.calendar)
        if healthDomains(for: selection).isEmpty == false,
           PermissionKind.appleHealth.isSupportedOnThisDevice {
            kinds.append(.appleHealth)
        }
        return kinds
    }

    /// Permissions worth naming on the same screen but not requesting there.
    static func pointOfUsePermissions(for selection: Set<String>) -> [PermissionKind] {
        var seen: Set<String> = []
        return all
            .filter { selection.contains($0.id) }
            .flatMap(\.pointOfUsePermissions)
            .filter { seen.insert($0.rawValue).inserted }
    }

    /// The Home layout implied by a selection.
    ///
    /// Replaces the fixed curated layout, which placed ten cards regardless of
    /// what the user had — seven of which rendered empty on day one. The spine
    /// is always present; module cards are added only when their module was
    /// chosen, and the setup checklist leads until it has nothing left to say.
    static func homePlacements(for selection: Set<String>) -> [DashboardWidgetPlacementValue] {
        var specifications: [(DashboardWidgetKind, WidgetSizePreset)] = [
            (.setupChecklist, .wide),
            (.focusNow, .wide),
            (.tasks, .standard)
        ]

        let ordered = all.filter { selection.contains($0.id) }
        for module in ordered {
            for kind in module.homeCardKinds where specifications.contains(where: { $0.0 == kind }) == false {
                specifications.append((kind, size(for: kind)))
            }
        }

        specifications.append(contentsOf: [
            (.scheduleCapacity, .standard),
            (.quickCapture, .compact),
            (.compactTimeline, .wide),
            (.progressReflection, .standard)
        ])

        let placements = specifications.enumerated().map { index, specification in
            DashboardWidgetPlacementValue(
                widgetKind: specification.0.rawValue,
                semanticSize: specification.1,
                ordinal: index
            )
        }
        return HomeGridPackingService.normalized(placements)
    }

    private static func size(for kind: DashboardWidgetKind) -> WidgetSizePreset {
        switch kind {
        case .lifeSnapshot, .journal: return .wide
        case .logMeal: return .compact
        default: return .standard
        }
    }
}

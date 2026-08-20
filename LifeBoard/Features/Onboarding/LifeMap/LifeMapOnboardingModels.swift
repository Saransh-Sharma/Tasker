import Foundation
import SwiftUI

/// The flow, in three phases.
///
/// `core` builds and commits the Life Map and is the only phase whose
/// completion the product promises. `powerUps` connect the outside world —
/// calendar, Health, reminders, EVA — and are entirely optional, which is why
/// they sit *after* the commit rather than inside it. `closing` orients the
/// user and hands them to EVA; both exit paths converge on it, so a user who
/// declines every power-up still meets the app and its assistant.
enum LifeMapOnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case welcome
    case desiredChange
    case friction
    case lifeAreas
    case priorities
    case capacity
    case connections
    case capture
    case reveal
    case calendar
    case health
    case reminders
    case eva
    case tour
    case firstWin

    var id: Int { rawValue }

    static let core: [Self] = [
        .welcome, .desiredChange, .friction, .lifeAreas, .priorities,
        .capacity, .connections, .capture, .reveal
    ]

    /// The optional connect chain, in the order it is offered.
    static let powerUps: [Self] = [.calendar, .health, .reminders, .eva]

    /// Seen on both exit paths — "Power it up" and "Show me around" alike.
    static let closing: [Self] = [.tour, .firstWin]

    var coreProgress: Double {
        guard let index = Self.core.firstIndex(of: self) else { return 1 }
        return Double(index) / Double(max(1, Self.core.count - 1))
    }

    var isPowerUp: Bool { Self.powerUps.contains(self) }
    var isClosing: Bool { Self.closing.contains(self) }

    /// The power-up steps worth showing for this workspace.
    ///
    /// Derived from the same `OnboardingModuleCatalog` call the permission rows
    /// use, so a module the user did not choose can never produce a step that
    /// asks for a permission nothing would consume. Calendar is always present:
    /// the catalog offers it unconditionally because two cards in every Home
    /// layout depend on it.
    static func visiblePowerUps(
        requestablePermissions: [PermissionKind],
        includesEva: Bool
    ) -> [Self] {
        var steps: [Self] = []
        if requestablePermissions.contains(.calendar) { steps.append(.calendar) }
        if requestablePermissions.contains(.appleHealth) { steps.append(.health) }
        if requestablePermissions.contains(.notifications) { steps.append(.reminders) }
        if includesEva { steps.append(.eva) }
        return steps
    }
}

enum LifeMapDesiredChange: String, CaseIterable, Codable, Identifiable {
    case seeWeek
    case clearHead
    case flexibleConsistency
    case makeRoom
    case knowNext

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seeWeek: "See my whole week clearly"
        case .clearHead: "Stop carrying everything in my head"
        case .flexibleConsistency: "Stay consistent without rigidity"
        case .makeRoom: "Make room for health and relationships"
        case .knowNext: "Know what to do next"
        }
    }

    var symbol: String {
        switch self {
        case .seeWeek: "calendar.day.timeline.left"
        case .clearHead: "brain.head.profile"
        case .flexibleConsistency: "arrow.trianglehead.2.clockwise.rotate.90"
        case .makeRoom: "heart.fill"
        case .knowNext: "location.north.fill"
        }
    }

    var primaryGoal: OnboardingPrimaryGoal {
        switch self {
        case .seeWeek: .wholeWeek
        case .clearHead: .lifeAdmin
        case .flexibleConsistency: .habitsRoutines
        case .makeRoom: .calendarChaos
        case .knowNext: .dailyExecution
        }
    }
}

enum LifeMapFriction: String, CaseIterable, Codable, Identifiable {
    case scattered
    case plansBreak
    case urgentWins
    case rigidBurden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scattered: "Everything lives in different places"
        case .plansBreak: "Plans fall apart when the day changes"
        case .urgentWins: "Urgent things hide what matters"
        case .rigidBurden: "Rigid systems become another burden"
        }
    }

    var symbol: String {
        switch self {
        case .scattered: "square.3.layers.3d.down.right.slash"
        case .plansBreak: "calendar.badge.exclamationmark"
        case .urgentWins: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .rigidBurden: "shippingbox.fill"
        }
    }
}

enum LifeMapModuleGroup: String, CaseIterable, Codable, Identifiable {
    case planFocus
    case routinesHealth
    case reflectionGrowth
    case eva

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planFocus: "Plan & Focus"
        case .routinesHealth: "Routines & Health"
        case .reflectionGrowth: "Reflection & Growth"
        case .eva: "EVA"
        }
    }

    var subtitle: String {
        switch self {
        case .planFocus: "Tasks, calendar capacity, and focus sessions"
        case .routinesHealth: "Habits, care, nutrition, and recovery"
        case .reflectionGrowth: "Journal, goals, moments, and insights"
        case .eva: "A private guide that helps connect the system"
        }
    }

    var symbol: String {
        switch self {
        case .planFocus: "scope"
        case .routinesHealth: "heart.text.clipboard"
        case .reflectionGrowth: "sparkles.rectangle.stack"
        case .eva: "wand.and.stars"
        }
    }

    var moduleIDs: Set<String> {
        switch self {
        case .planFocus:
            [OnboardingModuleCatalog.focusID]
        case .routinesHealth:
            [
                OnboardingModuleCatalog.habitsID,
                OnboardingModuleCatalog.moodID,
                OnboardingModuleCatalog.nutritionID,
                OnboardingModuleCatalog.bodyID
            ]
        case .reflectionGrowth:
            [
                OnboardingModuleCatalog.journalID,
                OnboardingModuleCatalog.goalsID,
                OnboardingModuleCatalog.momentsID,
                OnboardingModuleCatalog.notesID
            ]
        case .eva:
            // EVA places no Home cards and needs no module of its own; what the
            // toggle decides is whether the EVA power-up step is offered at all.
            // It previously returned an empty set *and* nothing consulted the
            // group, so the control was inert and the EVA step appeared even for
            // a user who had just switched it off.
            []
        }
    }
}

enum LifeMapCaptureKind: String, CaseIterable, Codable, Identifiable {
    case task
    case note
    case journal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: "Task"
        case .note: "Note"
        case .journal: "Journal"
        }
    }

    var symbol: String {
        switch self {
        case .task: "checkmark.circle"
        case .note: "note.text"
        case .journal: "book.closed"
        }
    }
}

struct LifeMapStagedCapture: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var kind: LifeMapCaptureKind
    var lifeAreaTemplateID: String?
    var isReviewed: Bool

    init(
        id: UUID = UUID(),
        text: String,
        kind: LifeMapCaptureKind = .task,
        lifeAreaTemplateID: String? = nil,
        isReviewed: Bool = false
    ) {
        self.id = id
        self.text = text
        self.kind = kind
        self.lifeAreaTemplateID = lifeAreaTemplateID
        self.isReviewed = isReviewed
    }
}

struct LifeMapDraft: Codable, Equatable {
    /// Selection bounds. These were previously spelled as bare `2` and `5` in
    /// both the model and the view, which is exactly the shape of bug where the
    /// button enables at a count the model then refuses to advance on.
    static let minimumLifeAreas = 2
    static let maximumLifeAreas = 5
    static let maximumFrictions = 2

    /// Schema 6 was the first Life Map snapshot schema. Schema 7 replaced the
    /// two power-up steps with the finer-grained connect chain and made the
    /// permission record outcome-verified, so a schema-6 partial journey has no
    /// honest translation and intentionally restarts at welcome — as does any
    /// earlier onboarding snapshot, whose payload is a different shape entirely.
    static let currentSchemaVersion = 7

    var schemaVersion = Self.currentSchemaVersion
    var step: LifeMapOnboardingStep = .welcome
    var entryContext: OnboardingEntryContext = .freshFlow
    var desiredChange: LifeMapDesiredChange?
    var frictionIDs: [String] = []
    var orderedLifeAreaTemplateIDs: [String] = []
    var dayShape = OnboardingDayShapeDraft(
        weekdayStartMinute: 9 * 60,
        weekdayEndMinute: 17 * 60,
        weekendStartMinute: 9 * 60,
        weekendEndMinute: 14 * 60,
        worksWeekends: false,
        weekStartsOn: .monday
    )
    var moduleGroupIDs: [String] = []
    var moduleIDs: [String] = []
    var stagedCapture: LifeMapStagedCapture?
    var resolvedLifeAreaIDsByTemplate: [String: UUID] = [:]
    var skippedCapture = false

    // MARK: Power-up outcomes
    //
    // Split deliberately into granted and denied rather than a single "we asked
    // about this" list. The previous single `permissionIDs` was appended to
    // unconditionally, so a user who tapped Allow and then Don't Allow in the
    // system sheet was shown a green "Connected" checkmark for a permission
    // they had just refused.

    /// Permissions the system confirmed. Only these earn a granted state.
    var grantedPermissionIDs: [String] = []

    /// Permissions the system refused, so the step can offer recovery instead
    /// of silently re-asking.
    var deniedPermissionIDs: [String] = []

    /// Calendars the user chose to read. Empty is a real answer meaning "no
    /// calendars", not "all of them" — see `FilterCalendarEventsUseCase`.
    var selectedCalendarIDs: [String] = []

    /// Health domains the user explicitly agreed LifeBoard may *write* back to.
    /// Read authorization is separate and does not imply this.
    var healthWriteBackDomainIDs: [String] = []

    /// Cloud EVA passed every gate during onboarding.
    var evaCloudReady = false

    /// The user chose on-device EVA, or postponed the decision.
    var evaDeferred = false

    /// The orientation tour ran to completion.
    var didTour = false

    /// Guards the one-shot Life Map -> EVA profile write. The write happens
    /// after the commit, so it cannot ride `commitPhase`.
    var didWriteEvaProfile = false

    /// Set once the user actually touches the capacity step.
    ///
    /// Merge-mode commits use this to decide whether to overwrite an existing
    /// week-start preference: an established user who walked past the capacity
    /// screen without editing it has not asked to have their week rebuilt.
    /// New optional fields with defaults are additive, so the schema stays 6.
    var didEditDayShape = false

    /// How far the commit got, so a retry resumes instead of replaying.
    var commitPhase: LifeMapCommitPhase = .notStarted

    var isLifeAreaSelectionValid: Bool {
        (Self.minimumLifeAreas...Self.maximumLifeAreas).contains(orderedLifeAreaTemplateIDs.count)
    }

    var isCaptureResolved: Bool {
        skippedCapture || stagedCapture?.isReviewed == true
    }
}

struct LifeMapProfile: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = Self.currentSchemaVersion
    var desiredChangeID: String
    var frictionIDs: [String]
    var createdAt: Date
    var updatedAt: Date
}

struct LifeMapSceneNode: Identifiable, Equatable {
    enum Kind: Equatable { case root, lifeArea }

    let id: String
    let title: String
    let symbol: String
    let colorHex: String?
    let kind: Kind
    let emphasis: Double
}

struct LifeMapSceneModel: Equatable {
    static let roots: [LifeMapSceneNode] = [
        .init(id: "home", title: "Home", symbol: "house.fill", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "plan", title: "Plan", symbol: "calendar", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "track", title: "Track", symbol: "chart.bar.fill", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "insights", title: "Insights", symbol: "sparkles", colorHex: nil, kind: .root, emphasis: 1),
        .init(id: "eva", title: "EVA", symbol: "wand.and.stars", colorHex: nil, kind: .root, emphasis: 1)
    ]

    var roots = Self.roots
    var lifeAreas: [LifeMapSceneNode]
    var capacityFraction: Double
    var centerPromise: String
    var captureTitle: String?
}

final class LifeMapProfileStore: @unchecked Sendable {
    static let shared = LifeMapProfileStore()

    private let defaults: UserDefaults
    private let key = "life_map_profile_v1"

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.suiteName)
            ?? .standard
    }

    func load() -> LifeMapProfile? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(LifeMapProfile.self, from: $0) }
    }

    func save(_ profile: LifeMapProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

import Foundation
import SwiftUI

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
    case permissionsPowerUp
    case evaPowerUp

    var id: Int { rawValue }

    static let core: [Self] = [
        .welcome, .desiredChange, .friction, .lifeAreas, .priorities,
        .capacity, .connections, .capture, .reveal
    ]

    var coreProgress: Double {
        guard let index = Self.core.firstIndex(of: self) else { return 1 }
        return Double(index) / Double(max(1, Self.core.count - 1))
    }

    var isPowerUp: Bool { self == .permissionsPowerUp || self == .evaPowerUp }
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

    /// Schema 6 is the first Life Map snapshot schema. Earlier onboarding
    /// snapshots use a different payload and intentionally restart at welcome.
    static let currentSchemaVersion = 6

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
    var permissionIDs: [String] = []
    var skippedCapture = false

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

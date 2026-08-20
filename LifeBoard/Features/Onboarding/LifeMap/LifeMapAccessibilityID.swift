import Foundation

/// Accessibility identifiers for the Life Map flow.
///
/// The draft flow shipped four raw string literals and no per-step or
/// per-choice identifiers at all, which left every UI assertion reaching for
/// localized labels. Localized labels are not a test contract: they change with
/// copy edits and break under RTL and non-English runs.
///
/// Kept deliberately parallel to `LifeMapOnboardingStep` so a new step cannot
/// be added without an identifier. `scripts/check-accessibility-identifiers.sh`
/// hashes every one of these, so any change here is an intentional contract
/// change and must land with a regenerated snapshot.
enum LifeMapAccessibilityID {
    static let flow = "onboarding.lifeMap.flow"
    static let canvas = "onboarding.lifeMap.canvas"
    static let error = "onboarding.error"
    static let progress = "onboarding.lifeMap.progress"
    static let backButton = "onboarding.lifeMap.back"

    // Steps, in flow order. `step(_:)` is derived from the enum rather than
    // spelled out so the two can never drift.
    static func step(_ step: LifeMapOnboardingStep) -> String {
        "onboarding.lifeMap.step.\(step.identifierSuffix)"
    }

    // Controls.
    static let primaryAction = "onboarding.primaryAction"
    static let secondaryAction = "onboarding.secondaryAction"
    static let captureField = "onboarding.capture.field"
    static let captureInterpret = "onboarding.capture.interpret"
    static let captureApprove = "onboarding.capture.approve"
    static let captureSkip = "onboarding.capture.skip"
    static let captureKindPicker = "onboarding.capture.kindPicker"
    static let captureAreaPicker = "onboarding.capture.areaPicker"
    static let tuneModules = "onboarding.connections.tune"
    static let worksWeekends = "onboarding.capacity.worksWeekends"
    static let weekStartsOn = "onboarding.capacity.weekStartsOn"
    static let homePreview = "onboarding.reveal.homePreview"

    // Parameterized, matching the established `onboarding.<thing>.<id>` shape.
    static func desiredChange(_ id: String) -> String { "onboarding.desiredChange.\(id)" }
    static func friction(_ id: String) -> String { "onboarding.friction.\(id)" }
    static func lifeArea(_ id: String) -> String { "onboarding.lifeArea.\(id)" }
    static func priority(_ id: String) -> String { "onboarding.priority.\(id)" }
    static func moveEarlier(_ id: String) -> String { "onboarding.priority.\(id).earlier" }
    static func moveLater(_ id: String) -> String { "onboarding.priority.\(id).later" }
    static func moduleGroup(_ id: String) -> String { "onboarding.moduleGroup.\(id)" }
    static func module(_ id: String) -> String { "onboarding.module.\(id)" }
    static func rootNode(_ id: String) -> String { "onboarding.lifeMap.root.\(id)" }
    static func permission(_ id: String) -> String { "onboarding.permission.\(id)" }
    static func permissionSkip(_ id: String) -> String { "onboarding.permission.\(id).skip" }

    // Power-up chain. Denied states reuse `PermissionRecoveryCard`, which
    // publishes its own `permission.recovery.<kind>` identifier — overriding it
    // here would rename a contract other surfaces already assert on.
    static let calendarList = "onboarding.calendar.list"
    static func calendarRow(_ id: String) -> String { "onboarding.calendar.row.\(id)" }
    static let healthWriteBackList = "onboarding.health.writeBack"
    static func healthWriteBackRow(_ id: String) -> String { "onboarding.health.writeBack.\(id)" }
    static let evaRequirements = "onboarding.eva.requirements"
    static let evaConsentList = "onboarding.eva.consent"
    static func evaConsentRow(_ id: String) -> String { "onboarding.eva.consent.\(id)" }
    static let evaOffline = "onboarding.eva.offline"

    // Closing.
    static func tourBeat(_ id: String) -> String { "onboarding.tour.beat.\(id)" }
    static let tourNext = "onboarding.tour.next"
    static let firstWinPrompts = "onboarding.firstWin.prompts"
    static func firstWinPrompt(_ id: String) -> String { "onboarding.firstWin.prompt.\(id)" }
}

extension LifeMapOnboardingStep {
    /// Stable, human-readable identifier fragment.
    ///
    /// Deliberately not `String(describing:)` — that would silently rename every
    /// accessibility identifier if a case were ever renamed, turning a source
    /// refactor into a broken UI-test contract with no compiler error.
    var identifierSuffix: String {
        switch self {
        case .welcome: "welcome"
        case .desiredChange: "desiredChange"
        case .friction: "friction"
        case .lifeAreas: "lifeAreas"
        case .priorities: "priorities"
        case .capacity: "capacity"
        case .connections: "connections"
        case .capture: "capture"
        case .reveal: "reveal"
        case .calendar: "calendar"
        case .health: "health"
        case .reminders: "reminders"
        case .eva: "eva"
        case .tour: "tour"
        case .firstWin: "firstWin"
        }
    }
}

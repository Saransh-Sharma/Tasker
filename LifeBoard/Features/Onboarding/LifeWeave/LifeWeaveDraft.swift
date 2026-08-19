import Foundation

/// The four rough shapes a day comes in, plus the escape hatch.
///
/// v5 opened on two time steppers, which asks a person to be precise about
/// something most people are not precise about, and quietly tells anyone on
/// shifts, caregiving, or an irregular week that they are using the app wrong.
/// A preset is one tap; `Edit hours` still reaches the same steppers underneath.
enum LifeWeaveDayShapePreset: String, Codable, CaseIterable, Sendable {
    case typical
    case early
    case later
    /// "My days move around." A first-class answer, not a fallback.
    case flexible
    case custom

    var title: String {
        switch self {
        case .typical: "Typical weekdays"
        case .early: "Early days"
        case .later: "Later days"
        case .flexible: "My days move around"
        case .custom: "My own hours"
        }
    }

    /// Weekday window in minutes from midnight, or `nil` where the preset does
    /// not assert one.
    var weekdayWindow: (start: Int, end: Int)? {
        switch self {
        case .typical: (9 * 60, 17 * 60)
        case .early: (7 * 60, 15 * 60)
        case .later: (11 * 60, 19 * 60)
        // Deliberately wide rather than absent. Capacity needs *some* boundary or
        // Plan cannot say a day is full; a generous one is the honest answer to
        // "it changes a lot", and it never blocks planning outside itself.
        case .flexible: (8 * 60, 20 * 60)
        case .custom: nil
        }
    }
}

/// The v6 persisted journey.
///
/// Schema 8. Schemas 6 and 7 were the v5 Life Map drafts; a v5 draft is not
/// decoded into this type directly but translated by `LifeWeaveMigration`, which
/// is why this has no legacy fields and no hand-written decoder.
///
/// What is deliberately absent: `moduleGroupIDs` / `moduleIDs`, because the
/// module screen is gone and the set is now derived from intent and areas; and
/// `didTour`, because there is no tour.
struct LifeWeaveDraft: Codable, Equatable {
    /// Selection bounds. Spelled once, here, because the v5 bug shape was the
    /// button enabling at a count the model then refused to advance on.
    static let minimumLifeAreas = 2
    static let maximumLifeAreas = 5
    static let maximumBlockers = 2

    static let currentSchemaVersion = 8

    var schemaVersion = Self.currentSchemaVersion
    var step: LifeWeaveStep = .arrival
    var entryContext: OnboardingEntryContext = .freshFlow

    var intent: LifeWeaveIntent?
    /// Optional, inline, and never re-asked on a screen of its own.
    var blockerIDs: [String] = []

    /// Selection order, with the primary area moved to index 0.
    ///
    /// One array rather than a set plus a separate ranking: the commit writes
    /// `sortOrder = index` straight from this, so the "which needs the clearest
    /// path" tap and the stored order cannot drift apart.
    var orderedLifeAreaTemplateIDs: [String] = []
    var primaryLifeAreaTemplateID: String?

    var dayShapePreset: LifeWeaveDayShapePreset = .typical
    var dayShape = OnboardingDayShapeDraft(
        weekdayStartMinute: 9 * 60,
        weekdayEndMinute: 17 * 60,
        weekendStartMinute: 9 * 60,
        weekendEndMinute: 14 * 60,
        worksWeekends: false,
        weekStartsOn: .monday
    )
    /// Set once the user actually touches the step. A merge-mode commit uses this
    /// to decide whether it may overwrite an established week start.
    var didEditDayShape = false

    var stagedCapture: LifeMapStagedCapture?
    var skippedCapture = false
    var resolvedLifeAreaIDsByTemplate: [String: UUID] = [:]

    // MARK: Power-up outcomes
    //
    // Granted and denied are separate lists, not one "we asked" list — the v5
    // bug was a green "Connected" row for a permission the user had just
    // refused in the system sheet.

    var grantedPermissionIDs: [String] = []
    var deniedPermissionIDs: [String] = []
    /// Empty means *no calendars*, not all of them. See `FilterCalendarEventsUseCase`.
    var selectedCalendarIDs: [String] = []
    /// Domains the user agreed LifeBoard may **write** to. Read authorization is
    /// a separate answer and never implies this.
    var healthWriteBackDomainIDs: [String] = []
    var evaCloudReady = false
    var evaDeferred = false

    /// Guards the one-shot Life Map -> EVA profile write.
    var didWriteEvaProfile = false

    /// How far the commit got, so a retry resumes instead of replaying.
    var commitPhase: LifeMapCommitPhase = .notStarted

    var isLifeAreaSelectionValid: Bool {
        (Self.minimumLifeAreas...Self.maximumLifeAreas).contains(orderedLifeAreaTemplateIDs.count)
    }

    /// The capture step is satisfied by an explicit skip or a reviewed capture.
    /// A typed-but-unreviewed capture is neither, which is what keeps the commit
    /// from writing something the user never approved.
    var isCaptureResolved: Bool {
        skippedCapture || stagedCapture?.isReviewed == true
    }

    /// The v5 vocabulary the commit path and the EVA mapper still speak.
    var desiredChange: LifeMapDesiredChange? { intent?.desiredChange }
}

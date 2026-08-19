import Foundation

/// The one thing the user wants to feel different, asked once.
///
/// v5 spent two full screens here: a "desired change" and a separate "what gets
/// in the way". They are the same conversation, and charging a whole screen for
/// the second one bought a signal the product barely reads. The blockers survive
/// as an *optional* chip row that unfolds under the chosen intent.
enum LifeWeaveIntent: String, CaseIterable, Codable, Identifiable, Sendable {
    case clarityToday
    case reduceMentalLoad
    case resilientPlanning
    case steadyRoutines
    case wholeLifeView
    case somethingElse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clarityToday: "Know what matters today"
        case .reduceMentalLoad: "Get things out of my head"
        case .resilientPlanning: "Make plans that survive real life"
        case .steadyRoutines: "Stay steady with routines"
        case .wholeLifeView: "Keep the important parts of life together"
        case .somethingElse: "Something else"
        }
    }

    var subtitle: String? {
        switch self {
        case .clarityToday: "See the next useful thing without digging."
        case .reduceMentalLoad: "Capture now. Organize when it matters."
        case .resilientPlanning: "Work with your time instead of fighting it."
        case .steadyRoutines: "Track what helps without chasing perfection."
        case .wholeLifeView: "Work, home, health, relationships, and more."
        case .somethingElse: nil
        }
    }

    var symbol: String {
        switch self {
        case .clarityToday: "location.north.fill"
        case .reduceMentalLoad: "brain.head.profile"
        case .resilientPlanning: "calendar.day.timeline.left"
        case .steadyRoutines: "arrow.trianglehead.2.clockwise.rotate.90"
        case .wholeLifeView: "square.grid.2x2"
        case .somethingElse: "ellipsis.circle"
        }
    }

    /// The v5 vocabulary this intent stands for.
    ///
    /// `LifeMapEvaProfileMapper`, `LifeMapProfile`, and the starter catalog all
    /// speak `LifeMapDesiredChange`, and every one of them is correct as written.
    /// Bridging here keeps v6 from forking the profile, the opening prompts, and
    /// the Home recommendation inputs just to rename five constants.
    var desiredChange: LifeMapDesiredChange? {
        switch self {
        case .clarityToday: .knowNext
        case .reduceMentalLoad: .clearHead
        case .resilientPlanning: .seeWeek
        case .steadyRoutines: .flexibleConsistency
        case .wholeLifeView: .makeRoom
        case .somethingElse: nil
        }
    }

    var primaryGoal: OnboardingPrimaryGoal? { desiredChange?.primaryGoal }

    /// The reverse bridge, for migrating an interrupted v5 draft.
    init(desiredChange: LifeMapDesiredChange) {
        switch desiredChange {
        case .knowNext: self = .clarityToday
        case .clearHead: self = .reduceMentalLoad
        case .seeWeek: self = .resilientPlanning
        case .flexibleConsistency: self = .steadyRoutines
        case .makeRoom: self = .wholeLifeView
        }
    }
}

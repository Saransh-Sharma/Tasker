import Foundation

/// The one thing the user wants to feel different, asked once.
///
/// v5 spent two full screens here: a "desired change" and a separate "what gets
/// in the way". They are the same conversation, and charging a whole screen for
/// the second one bought a signal the product barely reads. The blockers are no
/// longer asked at all; `LifeWeaveDraft.blockerIDs` stays decodable and empty.
enum LifeWeaveIntent: String, CaseIterable, Codable, Identifiable, Sendable {
    case clarityToday
    case reduceMentalLoad
    case resilientPlanning
    case steadyRoutines
    case wholeLifeView
    case somethingElse

    var id: String { rawValue }

    /// The option label. Lives in `LifeWeaveCopy` with the rest of the
    /// first-run words; there are no subtitles, by design.
    var title: String { LifeWeaveCopy.Intent.title(self) }

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

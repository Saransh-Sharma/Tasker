import Foundation

/// The v6 first run, in two phases.
///
/// `core` is the whole promise: six decisions that build and commit the user's
/// Life Map. `powerUps` connect the outside world and are reached **only** from
/// the reveal's secondary action, which is the structural difference from v5 —
/// there, the connect chain sat on the way out of onboarding and every user was
/// walked past it, and a five-beat root tour ran after that.
///
/// There is no closing phase. The five roots are not explained before the user
/// has a reason to care which one to open; `Destination` teaches itself from the
/// dock, and the contextual tips take the tour's job at the moment each root is
/// first opened.
enum LifeWeaveStep: Int, CaseIterable, Codable, Identifiable {
    case arrival
    case intent
    case lifeAreas
    case dayShape
    case firstCapture
    case reveal
    case calendar
    case health
    case reminders
    case eva

    var id: Int { rawValue }

    /// The only phase whose completion the product promises, and the only one
    /// that writes canonical records. It depends on no permission, no network,
    /// no model, and no account.
    static let core: [Self] = [.arrival, .intent, .lifeAreas, .dayShape, .firstCapture, .reveal]

    /// The optional connect chain, in the order it is offered.
    static let powerUps: [Self] = [.calendar, .health, .reminders, .eva]

    var isPowerUp: Bool { Self.powerUps.contains(self) }

    /// One-based position for the progress control and the VoiceOver value.
    ///
    /// The sighted UI shows a six-segment track; VoiceOver gets "Step 3 of 6,
    /// Life Areas". Percentages are deliberately gone — 0%, 12%, 25% invited the
    /// reading that a life can be a completion bar.
    var coreIndex: Int? {
        Self.core.firstIndex(of: self).map { $0 + 1 }
    }

    static var coreCount: Int { core.count }

    /// The power-up steps worth showing for this workspace.
    ///
    /// Derived from the same permission set the connect rows consume, so a
    /// capability nothing would use can never produce a step that asks for it.
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

    /// Stable accessibility-identifier suffix.
    ///
    /// Hand-written rather than derived from the case name so that renaming a
    /// case cannot silently rename a published identifier and break the snapshot
    /// in `scripts/accessibility-identifiers.sha256` without anyone noticing.
    var identifierSuffix: String {
        switch self {
        case .arrival: "arrival"
        case .intent: "intent"
        case .lifeAreas: "lifeAreas"
        case .dayShape: "dayShape"
        case .firstCapture: "firstCapture"
        case .reveal: "reveal"
        case .calendar: "calendar"
        case .health: "health"
        case .reminders: "reminders"
        case .eva: "eva"
        }
    }
}

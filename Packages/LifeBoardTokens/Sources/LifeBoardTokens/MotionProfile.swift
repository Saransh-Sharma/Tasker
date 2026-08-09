import SwiftUI

// The semantic motion vocabulary. It lived in the 123-type
// `LifeOSFoundationContracts` grab bag, which no package can depend on;
// every UI primitive that animates needs it, so it belongs with the other
// tokens.
public enum MotionProfile: String, Codable, CaseIterable, Hashable, Sendable {
    case press
    case selection
    case localState
    case contentInsertion
    case controlMorph
    case directManipulation
    case micro
    case cardReflow
    case route
    case celebration
    /// A card landing in or returning to a stack.
    case deckSettle
    /// A progress thread advancing one notch.
    case threadAdvance
    /// The morning commit landing.
    case firstLight
    case ambient
}

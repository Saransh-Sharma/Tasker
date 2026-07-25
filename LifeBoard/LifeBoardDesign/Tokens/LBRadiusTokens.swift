import CoreGraphics

/// Compatibility radii for the legacy Sunrise components.
///
/// These used to be an independent scale (chip 25, card 22, largeCard 28,
/// dock 32, sheet 30) that disagreed with both `LifeBoardCornerTokens` and
/// `LifeBoardFoundationRadius`. Three radius scales meant a Sunrise card and a
/// Foundation card sitting on the same screen had visibly different corners.
/// Every role now resolves from the canonical scale so the legacy screens
/// inherit the clay geometry without being rewritten.
enum LBRadiusTokens {
    /// Chips and pills. The design contract makes these true capsules.
    static let chip: CGFloat = LifeBoardFoundationRadius.pill
    static let card: CGFloat = LifeBoardClayDepth.raised.cornerRadius
    static let largeCard: CGFloat = LifeBoardClayDepth.floating.cornerRadius
    static let iconWell: CGFloat = LifeBoardClayDepth.well.cornerRadius
    static let dock: CGFloat = LifeBoardFoundationRadius.modal
    static let sheet: CGFloat = LifeBoardFoundationRadius.modal
}

import CoreGraphics

/// Compatibility radii for the legacy Sunrise components.
///
/// These used to be an independent scale (chip 25, card 22, largeCard 28,
/// dock 32, sheet 30) that disagreed with both `CornerTokens` and
/// `Radius`. Three radius scales meant a Sunrise card and a
/// Foundation card sitting on the same screen had visibly different corners.
/// Every role now resolves from the canonical scale so the legacy screens
/// inherit the clay geometry without being rewritten.
enum RadiusTokens {
    /// Chips and pills. The design contract makes these true capsules.
    static let chip: CGFloat = Radius.pill
    static let card: CGFloat = ClayDepth.raised.cornerRadius
    static let largeCard: CGFloat = ClayDepth.floating.cornerRadius
    static let iconWell: CGFloat = ClayDepth.well.cornerRadius
    static let dock: CGFloat = Radius.modal
    static let sheet: CGFloat = Radius.modal
}

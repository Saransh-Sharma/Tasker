import SwiftUI

/// Compatibility type roles for the legacy Sunrise components.
///
/// These are semantic text styles, so they scale with Dynamic Type rather than
/// freezing labels at phone-only point sizes.
///
/// The family assignments now follow the canonical contract: SF Pro Rounded
/// carries greetings, metrics and friendly section emphasis; SF Pro carries
/// task content and long-form reading. `dateHero` and `sectionTitle` were
/// previously `.serif`, which made every legacy screen read as a different
/// product from the Foundation roots, and `body` was `.rounded`, which put
/// long-form reading in the wrong family.
enum LBTypographyTokens {
    static let dateHero = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let heroOverline = Font.system(.caption2, design: .rounded, weight: .bold)
    static let sectionTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let cardTitle = Font.system(.headline, design: .rounded, weight: .bold)
    static let body = Font.system(.body, weight: .regular)
    static let bodyStrong = Font.system(.body, weight: .semibold)
    static let meta = Font.system(.footnote, weight: .medium)
    static let chip = Font.system(.callout, design: .rounded, weight: .semibold)
    static let numeric = Font.system(.footnote, design: .monospaced, weight: .medium)
    static let dockLabel = Font.system(.caption2, design: .rounded, weight: .semibold)
    static let habitDayLabel = Font.system(.caption2, design: .rounded, weight: .bold)
}

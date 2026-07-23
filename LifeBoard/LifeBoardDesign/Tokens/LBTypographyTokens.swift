import SwiftUI

enum LBTypographyTokens {
    // Compatibility roles now use semantic text styles, so all remaining
    // Sunrise components scale with Dynamic Type instead of freezing labels
    // at phone-only point sizes.
    static let dateHero = Font.system(.largeTitle, design: .serif, weight: .medium)
    static let heroOverline = Font.system(.caption2, design: .rounded, weight: .bold)
    static let sectionTitle = Font.system(.title2, design: .serif, weight: .semibold)
    static let cardTitle = Font.system(.headline, design: .rounded, weight: .bold)
    static let body = Font.system(.body, design: .rounded, weight: .regular)
    static let bodyStrong = Font.system(.body, design: .rounded, weight: .semibold)
    static let meta = Font.system(.footnote, design: .rounded, weight: .medium)
    static let chip = Font.system(.callout, design: .rounded, weight: .semibold)
    static let numeric = Font.system(.footnote, design: .monospaced, weight: .medium)
    static let dockLabel = Font.system(.caption2, design: .rounded, weight: .semibold)
    static let habitDayLabel = Font.system(.caption2, design: .rounded, weight: .bold)
}

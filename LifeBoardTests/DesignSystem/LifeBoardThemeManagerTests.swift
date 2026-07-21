import XCTest
import UIKit
@testable import LifeBoard

@MainActor
final class LifeBoardThemeManagerTests: XCTestCase {
    func testThemeManagerAlwaysResolvesSingleBrandTheme() {
        let currentTheme = LifeBoardThemeManager.shared.currentTheme

        XCTAssertEqual(currentTheme.index, 0)
        XCTAssertEqual(currentTheme.palette, .sunrise)
    }

    func testLifeBoardThemePreservesPassedIndexForCompatibility() {
        let theme = LifeBoardTheme(index: 7)

        XCTAssertEqual(theme.index, 7)
        XCTAssertEqual(theme.palette, .sunrise)
    }

    func testReloadFromPersistenceKeepsSingleBrandTheme() {
        LifeBoardThemeManager.shared.reloadFromPersistence()

        XCTAssertEqual(LifeBoardThemeManager.shared.currentTheme.index, 0)
        XCTAssertEqual(LifeBoardThemeManager.shared.currentTheme.palette, .sunrise)
    }

    func testTokenResolverKeepsPhoneValuesStable() {
        let baseline = LifeBoardThemeManager.shared.currentTheme.tokens
        let resolved = LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified)

        XCTAssertEqual(resolved.spacing.s16, baseline.spacing.s16)
        XCTAssertEqual(resolved.corner.r2, baseline.corner.r2)
        XCTAssertEqual(resolved.typography.body.pointSize, baseline.typography.body.pointSize)
        XCTAssertEqual(
            resolved.color.bgCanvas.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
            baseline.color.bgCanvas.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        )
    }

    func testTokenResolverIsStableForSameLayoutAndTraitCluster() {
        let traits = LifeBoardTokenTraitContext(
            colorScheme: .light,
            contentSizeCategory: .large,
            accessibilityContrast: .normal
        )

        let first = LifeBoardThemeManager.shared.tokens(for: .padRegular, traits: traits)
        let second = LifeBoardThemeManager.shared.tokens(for: .padRegular, traits: traits)

        XCTAssertEqual(first.spacing.sectionGap, second.spacing.sectionGap)
        XCTAssertEqual(first.corner.card, second.corner.card)
        XCTAssertEqual(first.typography.title2.pointSize, second.typography.title2.pointSize)
    }

    func testCurrentPaletteCarriesSunriseNeutrals() {
        let palette = LifeBoardThemeManager.shared.currentTheme.palette

        assertEqualColor(palette.neutralIvory, UIColor(lifeboardHex: "#FFFDFC"))
        assertEqualColor(palette.neutralDarkInk0, UIColor(lifeboardHex: "#080C17"))
        assertEqualColor(palette.neutralDarkBorder2, UIColor(lifeboardHex: "#56617B"))
    }

    private func assertEqualColor(_ lhs: UIColor, _ rhs: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        var lR: CGFloat = 0
        var lG: CGFloat = 0
        var lB: CGFloat = 0
        var lA: CGFloat = 0
        var rR: CGFloat = 0
        var rG: CGFloat = 0
        var rB: CGFloat = 0
        var rA: CGFloat = 0
        XCTAssertTrue(lhs.getRed(&lR, green: &lG, blue: &lB, alpha: &lA), file: file, line: line)
        XCTAssertTrue(rhs.getRed(&rR, green: &rG, blue: &rB, alpha: &rA), file: file, line: line)
        XCTAssertEqual(lR, rR, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lG, rG, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lB, rB, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lA, rA, accuracy: 0.001, file: file, line: line)
    }
}

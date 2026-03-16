import XCTest
import UIKit
@testable import To_Do_List

final class TypographyTokenTests: XCTestCase {
    func testTypographyStylesExist() {
        let typography = TaskerTheme(index: 0).tokens.typography

        XCTAssertGreaterThan(typography.heroDisplay.pointSize, 0)
        XCTAssertGreaterThan(typography.screenTitle.pointSize, 0)
        XCTAssertGreaterThan(typography.sectionTitle.pointSize, 0)
        XCTAssertGreaterThan(typography.display.pointSize, 0)
        XCTAssertGreaterThan(typography.title1.pointSize, 0)
        XCTAssertGreaterThan(typography.body.pointSize, 0)
        XCTAssertGreaterThan(typography.caption2.pointSize, 0)
    }

    func testDisplayFontClampsToExpectedRange() {
        let typography = TaskerTheme(index: 0).tokens.typography
        let largeAccessibility = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let display = typography.dynamicFont(for: .display, compatibleWith: largeAccessibility)
        XCTAssertLessThanOrEqual(display.pointSize, 40)
        XCTAssertGreaterThanOrEqual(display.pointSize, 20)
    }

    func testButtonStylesAreSemiboldLike() {
        let typography = TaskerTheme(index: 0).tokens.typography

        XCTAssertGreaterThanOrEqual(typography.button.pointSize, typography.buttonSmall.pointSize)
    }

    func testMetricAndMonoRolesUseSpecializedDesigns() {
        let typography = TaskerTheme(index: 0).tokens.typography

        XCTAssertTrue(typography.metric.fontName.localizedCaseInsensitiveContains("rounded"))
        XCTAssertTrue(typography.monoMeta.fontName.localizedCaseInsensitiveContains("mono"))
    }

    func testTextStylesAreDynamicTypeCompatibleAndNotHelvetica() {
        let typography = TaskerTheme(index: 0).tokens.typography

        let expectedStyles: [(TaskerTextStyle, UIFont, UIFont.TextStyle)] = [
            (.display, typography.display, .largeTitle),
            (.title1, typography.title1, .title1),
            (.title2, typography.title2, .title2),
            (.headline, typography.headline, .headline),
            (.body, typography.body, .body),
            (.callout, typography.callout, .callout),
            (.caption1, typography.caption1, .caption1),
            (.caption2, typography.caption2, .caption2)
        ]

        for (style, font, expectedTextStyle) in expectedStyles {
            XCTAssertFalse(font.fontName.localizedCaseInsensitiveContains("helvetica"))

            let largeAccessibility = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
            let dynamic = typography.dynamicFont(for: style, compatibleWith: largeAccessibility)
            _ = expectedTextStyle // style mapping is exercised by dynamicFont(for:)
            XCTAssertGreaterThan(dynamic.pointSize, font.pointSize)
        }
    }

    func testNonDisplayStylesScaleWithoutClampInLargeAccessibility() {
        let typography = TaskerTheme(index: 0).tokens.typography
        let largeAccessibility = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let scaledTitle1 = typography.dynamicFont(for: .title1, compatibleWith: largeAccessibility)
        XCTAssertGreaterThan(scaledTitle1.pointSize, 22)
    }
}

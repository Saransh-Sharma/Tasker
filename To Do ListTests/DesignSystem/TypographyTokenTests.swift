import XCTest
import UIKit
@testable import Tasker

final class TypographyTokenTests: XCTestCase {
    func testTypographyStylesExist() {
        let typography = TaskerTheme(index: 0).tokens.typography

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

    func testTextStylesAreDynamicTypeCompatibleAndNotHelvetica() {
        let typography = TaskerTheme(index: 0).tokens.typography

        let expectedStyles: [(UIFont, UIFont.TextStyle)] = [
            (typography.display, .largeTitle),
            (typography.title1, .title1),
            (typography.title2, .title2),
            (typography.headline, .headline),
            (typography.body, .body),
            (typography.callout, .callout),
            (typography.caption1, .caption1),
            (typography.caption2, .caption2)
        ]

        for (font, expectedTextStyle) in expectedStyles {
            let descriptorStyle = font.fontDescriptor.object(forKey: .textStyle) as? String
            XCTAssertEqual(descriptorStyle, expectedTextStyle.rawValue)
            XCTAssertFalse(font.fontName.localizedCaseInsensitiveContains("helvetica"))
        }
    }

    func testNonDisplayStylesScaleWithoutClampInLargeAccessibility() {
        let typography = TaskerTheme(index: 0).tokens.typography
        let largeAccessibility = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let scaledTitle1 = typography.dynamicFont(for: .title1, compatibleWith: largeAccessibility)
        XCTAssertGreaterThan(scaledTitle1.pointSize, 22)
    }
}

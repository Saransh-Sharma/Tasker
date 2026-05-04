import XCTest
import UIKit
@testable import LifeBoard

@MainActor
final class SpacingElevationCornerTests: XCTestCase {
    func testSpacingRecipeValues() {
        let spacing = LifeBoardTheme(index: 0).tokens.spacing

        XCTAssertEqual(spacing.screenHorizontal, 20)
        XCTAssertEqual(spacing.cardPadding, 20)
        XCTAssertEqual(spacing.sectionGap, 28)
        XCTAssertEqual(spacing.buttonHeight, 48)
    }

    func testCornerScaleValues() {
        let corner = LifeBoardTheme(index: 0).tokens.corner

        XCTAssertEqual(corner.r1, 12)
        XCTAssertEqual(corner.r2, 14)
        XCTAssertEqual(corner.r3, 18)
        XCTAssertEqual(corner.r4, 22)
        XCTAssertEqual(corner.pill, 999)
    }

    func testElevationOrdering() {
        let elevation = LifeBoardTheme(index: 0).tokens.elevation

        XCTAssertLessThan(elevation.e1.shadowOffsetY, elevation.e2.shadowOffsetY)
        XCTAssertLessThan(elevation.e2.shadowOffsetY, elevation.e3.shadowOffsetY)
    }

    func testLayoutResolverClassifiesBreakpointsAsExpected() {
        let phoneMetrics = LifeBoardLayoutMetrics(width: 390, height: 844, idiom: .phone)
        XCTAssertEqual(LifeBoardLayoutResolver.classify(metrics: phoneMetrics), .phone)

        let compactPad = LifeBoardLayoutMetrics(width: 699, height: 1024, idiom: .pad)
        XCTAssertEqual(LifeBoardLayoutResolver.classify(metrics: compactPad), .padCompact)

        let regularPad = LifeBoardLayoutMetrics(width: 700, height: 1024, idiom: .pad)
        XCTAssertEqual(LifeBoardLayoutResolver.classify(metrics: regularPad), .padRegular)

        let expandedPad = LifeBoardLayoutMetrics(width: 1024, height: 1366, idiom: .pad)
        XCTAssertEqual(LifeBoardLayoutResolver.classify(metrics: expandedPad), .padExpanded)
    }

    @MainActor
    func testLayoutResolverFallsBackToWindowMetricsWhenViewWidthIsZero() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        let view = UIView(frame: .zero)
        window.addSubview(view)
        window.layoutIfNeeded()

        let metrics = LifeBoardLayoutResolver.metrics(for: view)
        XCTAssertEqual(metrics.width, 900, accuracy: 0.1)
        XCTAssertEqual(metrics.height, 700, accuracy: 0.1)
    }

    func testPhoneLayoutTokensMatchLegacyThemeTokens() {
        let theme = LifeBoardTheme(index: 0)
        let legacy = theme.tokens
        let phone = theme.tokens(for: .phone)

        XCTAssertEqual(phone.spacing.screenHorizontal, legacy.spacing.screenHorizontal)
        XCTAssertEqual(phone.spacing.sectionGap, legacy.spacing.sectionGap)
        XCTAssertEqual(phone.corner.card, legacy.corner.card)
        XCTAssertEqual(phone.corner.modal, legacy.corner.modal)
        XCTAssertEqual(phone.typography.display.pointSize, legacy.typography.display.pointSize)
        XCTAssertEqual(phone.typography.body.pointSize, legacy.typography.body.pointSize)
        XCTAssertEqual(phone.elevation.e2.shadowBlur, legacy.elevation.e2.shadowBlur)
    }

    func testPadLayoutTokensIncreaseDensityAndScale() {
        let theme = LifeBoardTheme(index: 0)
        let phone = theme.tokens(for: .phone)
        let pad = theme.tokens(for: .padRegular)

        XCTAssertGreaterThan(pad.spacing.screenHorizontal, phone.spacing.screenHorizontal)
        XCTAssertGreaterThan(pad.corner.card, phone.corner.card)
        XCTAssertGreaterThan(pad.typography.title1.pointSize, phone.typography.title1.pointSize)
        XCTAssertGreaterThanOrEqual(pad.elevation.e2.shadowBlur, phone.elevation.e2.shadowBlur)
    }

    @MainActor
    func testLifeBoardChipTintedSelectionUsesMutedBackground() {
        let chip = LifeBoardChipView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        chip.selectedStyle = .tinted
        chip.isSelected = true

        let expected = LifeBoardThemeManager.shared.currentTheme.tokens.color.accentWash
        XCTAssertEqualColor(chip.backgroundColor, expected)
    }

    @MainActor
    func testLifeBoardChipFilledSelectionUsesPrimaryBackground() {
        let chip = LifeBoardChipView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        chip.selectedStyle = .filled
        chip.isSelected = true

        let expected = LifeBoardThemeManager.shared.currentTheme.tokens.color.chipSelectedBackground
        XCTAssertEqualColor(chip.backgroundColor, expected)
    }

    @MainActor
    func testLifeBoardTextFieldFocusRingUsesActionFocus() {
        let textField = LifeBoardTextField(kind: .singleLine)
        textField.sendActions(for: .editingDidBegin)

        XCTAssertEqual(textField.layer.borderWidth, 2)
        XCTAssertEqualColor(UIColor(cgColor: textField.layer.borderColor ?? UIColor.clear.cgColor), UIColor.lifeboard.actionFocus)

        textField.sendActions(for: .editingDidEnd)
        XCTAssertEqual(textField.layer.borderWidth, 1)
        XCTAssertEqualColor(UIColor(cgColor: textField.layer.borderColor ?? UIColor.clear.cgColor), UIColor.lifeboard.borderDefault)
    }

    private func XCTAssertEqualColor(
        _ lhs: UIColor?,
        _ rhs: UIColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let lhs else {
            return XCTFail("Color was nil", file: file, line: line)
        }
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
        XCTAssertEqual(lR, rR, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(lG, rG, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(lB, rB, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(lA, rA, accuracy: 0.01, file: file, line: line)
    }
}

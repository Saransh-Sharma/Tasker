import XCTest
import UIKit
@testable import LifeBoard
import LifeBoardTokens
@MainActor
final class SpacingElevationCornerTests: XCTestCase {
    func testSpacingRecipeValues() {
        let spacing = Theme(index: 0).tokens.spacing

        XCTAssertEqual(spacing.screenHorizontal, 20)
        XCTAssertEqual(spacing.cardPadding, 20)
        XCTAssertEqual(spacing.sectionGap, 32)
        XCTAssertEqual(spacing.buttonHeight, 48)
    }

    func testCornerScaleValues() {
        let corner = Theme(index: 0).tokens.corner

        // DESIGN.md "Shapes": 14 fields, 16 rows, 20 raised, 24 hero.
        // These were 12 / 14 / 18 / 22 — a scale of its own, none of whose
        // values except 14 appear in the contract.
        XCTAssertEqual(corner.r1, 14)
        XCTAssertEqual(corner.r2, 16)
        XCTAssertEqual(corner.r3, 20)
        XCTAssertEqual(corner.r4, 24)
        XCTAssertEqual(corner.pill, 999)
    }

    func testElevationOrdering() {
        let elevation = Theme(index: 0).tokens.elevation

        XCTAssertLessThan(elevation.e1.shadowOffsetY, elevation.e2.shadowOffsetY)
        XCTAssertLessThan(elevation.e2.shadowOffsetY, elevation.e3.shadowOffsetY)
    }

    func testLayoutResolverClassifiesBreakpointsAsExpected() {
        let phoneMetrics = LayoutMetrics(width: 390, height: 844, idiom: .phone)
        XCTAssertEqual(LayoutResolver.classify(metrics: phoneMetrics), .phone)
        XCTAssertEqual(phoneMetrics.platform, .phone)

        let compactPad = LayoutMetrics(width: 699, height: 1024, idiom: .pad)
        XCTAssertEqual(LayoutResolver.classify(metrics: compactPad), .padCompact)
        XCTAssertEqual(compactPad.platform, .pad)

        let regularPad = LayoutMetrics(width: 700, height: 1024, idiom: .pad)
        XCTAssertEqual(LayoutResolver.classify(metrics: regularPad), .padRegular)

        let expandedPad = LayoutMetrics(width: 1024, height: 1366, idiom: .pad)
        XCTAssertEqual(LayoutResolver.classify(metrics: expandedPad), .padExpanded)
    }

    func testLayoutResolverClassifiesMacCatalystMetricsAsExpandedLayout() {
        let compactMac = LayoutMetrics(
            width: 640,
            height: 900,
            idiom: .pad,
            platform: .macCatalyst
        )
        XCTAssertEqual(LayoutResolver.classify(metrics: compactMac), .padCompact)

        let regularMac = LayoutMetrics(
            width: 900,
            height: 900,
            idiom: .pad,
            platform: .macCatalyst
        )
        XCTAssertEqual(LayoutResolver.classify(metrics: regularMac), .padRegular)

        let expandedMac = LayoutMetrics(
            width: 1280,
            height: 900,
            idiom: .pad,
            platform: .macCatalyst
        )
        XCTAssertEqual(LayoutResolver.classify(metrics: expandedMac), .padExpanded)
    }

    @MainActor
    func testLayoutResolverFallsBackToWindowMetricsWhenViewWidthIsZero() throws {
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: windowScene)
        let view = UIView(frame: .zero)
        window.addSubview(view)
        window.layoutIfNeeded()

        let metrics = LayoutResolver.metrics(for: view)
        let sceneSize = windowScene.effectiveGeometry.coordinateSpace.bounds.size
        XCTAssertEqual(metrics.width, sceneSize.width, accuracy: 0.1)
        XCTAssertEqual(metrics.height, sceneSize.height, accuracy: 0.1)
    }

    func testPhoneLayoutTokensMatchLegacyThemeTokens() {
        let theme = Theme(index: 0)
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
        let theme = Theme(index: 0)
        let phone = theme.tokens(for: .phone)
        let pad = theme.tokens(for: .padRegular)

        XCTAssertGreaterThan(pad.spacing.screenHorizontal, phone.spacing.screenHorizontal)
        XCTAssertGreaterThan(pad.typography.title1.pointSize, phone.typography.title1.pointSize)
        XCTAssertGreaterThanOrEqual(pad.elevation.e2.shadowBlur, phone.elevation.e2.shadowBlur)
    }

    /// Corner radius is the one token that must *not* scale with the window.
    ///
    /// This assertion used to read `pad.corner.card > phone.corner.card`, so a
    /// card was 18 points on a phone and 22 on an expanded iPad. `DESIGN.md` is
    /// explicit that an iPad composition grows "through spacing and
    /// composition, not oversized type or empty card area", and the 24-point
    /// hero radius is described as the continuity that lets a card and the hero
    /// it opens into read as one object — which cannot hold if the radius
    /// depends on the window it is in.
    func testCornerRadiusDoesNotScaleWithLayoutClass() {
        let theme = Theme(index: 0)
        for layout in [LayoutClass.phone, .padCompact, .padRegular, .padExpanded] {
            let corner = theme.tokens(for: layout).corner
            XCTAssertEqual(corner.card, 20, "card radius drifted on \(layout)")
            XCTAssertEqual(corner.input, 14, "input radius drifted on \(layout)")
            XCTAssertEqual(corner.modal, 28, "modal radius drifted on \(layout)")
            XCTAssertEqual(corner.bottomBar, 30, "dock radius drifted on \(layout)")
        }
    }

    @MainActor
    func testLifeBoardChipTintedSelectionUsesMutedBackground() {
        let chip = ChipView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        chip.selectedStyle = .tinted
        chip.isSelected = true

        let expected = ThemeStore.shared.currentTheme.tokens.color.accentWash
        XCTAssertEqualColor(chip.backgroundColor, expected)
    }

    @MainActor
    func testLifeBoardChipFilledSelectionUsesPrimaryBackground() {
        let chip = ChipView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        chip.selectedStyle = .filled
        chip.isSelected = true

        let expected = ThemeStore.shared.currentTheme.tokens.color.chipSelectedBackground
        XCTAssertEqualColor(chip.backgroundColor, expected)
    }

    @MainActor
    func testLifeBoardTextFieldFocusRingUsesActionFocus() {
        let textField = TokenTextField(kind: .singleLine)
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

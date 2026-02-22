import XCTest
import UIKit
@testable import To_Do_List

final class SpacingElevationCornerTests: XCTestCase {
    func testSpacingRecipeValues() {
        let spacing = TaskerTheme(index: 0).tokens.spacing

        XCTAssertEqual(spacing.screenHorizontal, 16)
        XCTAssertEqual(spacing.cardPadding, 16)
        XCTAssertEqual(spacing.sectionGap, 24)
        XCTAssertEqual(spacing.buttonHeight, 48)
    }

    func testCornerScaleValues() {
        let corner = TaskerTheme(index: 0).tokens.corner

        XCTAssertEqual(corner.r1, 8)
        XCTAssertEqual(corner.r2, 12)
        XCTAssertEqual(corner.r3, 16)
        XCTAssertEqual(corner.r4, 24)
        XCTAssertEqual(corner.pill, 999)
    }

    func testElevationOrdering() {
        let elevation = TaskerTheme(index: 0).tokens.elevation

        XCTAssertLessThan(elevation.e1.shadowOffsetY, elevation.e2.shadowOffsetY)
        XCTAssertLessThan(elevation.e2.shadowOffsetY, elevation.e3.shadowOffsetY)
    }

    @MainActor
    func testTaskerChipTintedSelectionUsesMutedBackground() {
        let chip = TaskerChipView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        chip.selectedStyle = .tinted
        chip.isSelected = true

        let expected = TaskerThemeManager.shared.currentTheme.tokens.color.accentMuted
        XCTAssertEqualColor(chip.backgroundColor, expected)
    }

    @MainActor
    func testTaskerChipFilledSelectionUsesPrimaryBackground() {
        let chip = TaskerChipView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        chip.selectedStyle = .filled
        chip.isSelected = true

        let expected = TaskerThemeManager.shared.currentTheme.tokens.color.chipSelectedBackground
        XCTAssertEqualColor(chip.backgroundColor, expected)
    }

    @MainActor
    func testTaskerTextFieldFocusRingUsesAccentRing() {
        let textField = TaskerTextField(kind: .singleLine)
        textField.sendActions(for: .editingDidBegin)

        XCTAssertEqual(textField.layer.borderWidth, TaskerThemeManager.shared.currentTheme.tokens.interaction.focusRingWidth)
        XCTAssertEqualColor(UIColor(cgColor: textField.layer.borderColor ?? UIColor.clear.cgColor), UIColor.tasker.accentRing)

        textField.sendActions(for: .editingDidEnd)
        XCTAssertEqual(textField.layer.borderWidth, 1)
        XCTAssertEqualColor(UIColor(cgColor: textField.layer.borderColor ?? UIColor.clear.cgColor), UIColor.tasker.strokeHairline)
    }

    func testInteractionAndIconTokenDefaults() {
        let tokens = TaskerTheme(index: 0).tokens
        XCTAssertEqual(tokens.interaction.minInteractiveSize, 44)
        XCTAssertEqual(tokens.interaction.focusRingWidth, 2)
        XCTAssertEqual(tokens.interaction.focusRingOffset, 2)
        XCTAssertEqual(tokens.interaction.pressScale, 0.97, accuracy: 0.001)
        XCTAssertEqual(tokens.interaction.pressOpacity, 0.92, accuracy: 0.001)
        XCTAssertEqual(tokens.interaction.reducedMotionPressScale, 1.0, accuracy: 0.001)

        XCTAssertEqual(tokens.iconSize.small, 16)
        XCTAssertEqual(tokens.iconSize.medium, 20)
        XCTAssertEqual(tokens.iconSize.large, 24)
        XCTAssertEqual(tokens.iconSize.hero, 32)
    }

    func testMotionAndTransitionTokenDefaults() {
        let tokens = TaskerTheme(index: 0).tokens
        XCTAssertEqual(tokens.motion.gradientCycleDuration, 15, accuracy: 0.001)
        XCTAssertEqual(tokens.motion.gradientCycleRandomness, 2, accuracy: 0.001)
        XCTAssertEqual(tokens.motion.gradientHueShiftDegrees, 8, accuracy: 0.001)
        XCTAssertEqual(tokens.motion.gradientSaturationShiftPercent, 5, accuracy: 0.001)
        XCTAssertEqual(tokens.motion.gradientOpacityDeltaMax, 0.08, accuracy: 0.001)
        XCTAssertEqual(tokens.motion.maxAnimatedGradientLayers, 2)
        XCTAssertEqual(tokens.motion.maxAnimatedElementsPerView, 2)
        XCTAssertEqual(tokens.motion.gradientCurve, .easeInOut)

        XCTAssertEqual(tokens.transition.pushPopDuration, 0.30, accuracy: 0.001)
        XCTAssertEqual(tokens.transition.modalDuration, 0.35, accuracy: 0.001)
        XCTAssertEqual(tokens.transition.sheetSpringDamping, 0.85, accuracy: 0.001)
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

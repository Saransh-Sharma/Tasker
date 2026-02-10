import XCTest
import UIKit
@testable import Tasker

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

        XCTAssertEqual(textField.layer.borderWidth, 2)
        XCTAssertEqualColor(UIColor(cgColor: textField.layer.borderColor ?? UIColor.clear.cgColor), UIColor.tasker.accentRing)

        textField.sendActions(for: .editingDidEnd)
        XCTAssertEqual(textField.layer.borderWidth, 1)
        XCTAssertEqualColor(UIColor(cgColor: textField.layer.borderColor ?? UIColor.clear.cgColor), UIColor.tasker.strokeHairline)
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

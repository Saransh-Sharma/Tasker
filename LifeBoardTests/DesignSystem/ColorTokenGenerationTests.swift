import XCTest
import UIKit
@testable import LifeBoard

@MainActor
final class ColorTokenGenerationTests: XCTestCase {
    func testSarvamPaletteMatchesSpec() {
        let palette = LifeBoardBrandPalette.sarvam

        assertEqualColor(palette.brandEmerald, UIColor(lifeboardHex: "#293A18"))
        assertEqualColor(palette.brandMagenta, UIColor(lifeboardHex: "#B1205F"))
        assertEqualColor(palette.brandMarigold, UIColor(lifeboardHex: "#FEBF2B"))
        assertEqualColor(palette.brandRed, UIColor(lifeboardHex: "#C11317"))
        assertEqualColor(palette.brandSandstone, UIColor(lifeboardHex: "#9E5F0A"))
        assertEqualColor(palette.neutralIvory, UIColor(lifeboardHex: "#FFF8EF"))
        assertEqualColor(palette.neutralDarkInk0, UIColor(lifeboardHex: "#0F0C0A"))
        assertEqualColor(palette.neutralDarkText1, UIColor(lifeboardHex: "#FFF3E6"))
    }

    func testSemanticNeutralsStayStableAcrossBrandTheme() {
        let colors = LifeBoardTheme(index: 0).tokens.color

        assertEqualColor(
            colors.bgCanvas.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(lifeboardHex: "#FFF8EF")
        )
        assertEqualColor(
            colors.bgCanvasSecondary.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(lifeboardHex: "#F7EFE4")
        )
        assertEqualColor(
            colors.bgCanvasSecondary.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            UIColor(lifeboardHex: "#15110E")
        )
        assertEqualColor(
            colors.surfacePrimary.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            UIColor(lifeboardHex: "#15110E")
        )
    }

    func testPrimaryAndAssistantAccentsMatchBrandRoles() {
        let colors = LifeBoardTheme(index: 0).tokens.color

        assertEqualColor(
            colors.primaryAction.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(lifeboardHex: "#293A18")
        )
        assertEqualColor(
            colors.primaryAction.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            UIColor(lifeboardHex: "#FEBF2B")
        )
        assertEqualColor(colors.assistantAccent, UIColor(lifeboardHex: "#B1205F"))
        assertEqualColor(colors.warningAccent, UIColor(lifeboardHex: "#FEBF2B"))
        assertEqualColor(colors.dangerAccent, UIColor(lifeboardHex: "#C11317"))
        assertEqualColor(colors.stateInfo, UIColor(lifeboardHex: "#9E5F0A"))
    }

    func testPriorityColorsUseBrandFamilies() {
        let colors = LifeBoardTheme(index: 0).tokens.color

        assertEqualColor(colors.priorityNone, UIColor(lifeboardHex: "#9E5F0A"))
        assertEqualColor(colors.priorityLow, UIColor(lifeboardHex: "#293A18"))
        assertEqualColor(colors.priorityHigh, UIColor(lifeboardHex: "#B1205F"))
        assertEqualColor(colors.priorityMax, UIColor(lifeboardHex: "#C11317"))
    }

    func testCompatibilityAliasesMapToSemanticRoles() {
        let colors = LifeBoardTheme(index: 0).tokens.color
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

        assertEqualColor(colors.accentPrimary.resolvedColor(with: darkTraits), colors.actionPrimary.resolvedColor(with: darkTraits))
        assertEqualColor(colors.accentPrimaryPressed.resolvedColor(with: darkTraits), colors.actionPrimaryPressed.resolvedColor(with: darkTraits))
        assertEqualColor(colors.accentRing.resolvedColor(with: darkTraits), colors.actionFocus.resolvedColor(with: darkTraits))
        assertEqualColor(colors.divider.resolvedColor(with: darkTraits), colors.borderSubtle.resolvedColor(with: darkTraits))
        assertEqualColor(colors.strokeHairline.resolvedColor(with: darkTraits), colors.borderDefault.resolvedColor(with: darkTraits))
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

final class ProjectEnumColorTests: XCTestCase {
    func testProjectColorsUseDistinctHexValues() {
        let uniqueHexes = Set(ProjectColor.allCases.map(\.hexString))
        XCTAssertEqual(uniqueHexes.count, ProjectColor.allCases.count)
    }

    func testUnknownProjectHealthUsesBlackIndicatorHex() {
        XCTAssertEqual(ProjectHealth.unknown.colorHex, "#000000")
    }
}

@MainActor
final class HeaderGradientTokenTests: XCTestCase {
    func testHeaderGradientLayerOrderAndNames() {
        let hostLayer = CALayer()
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        LifeBoardHeaderGradient.apply(to: hostLayer, bounds: bounds, traits: UITraitCollection(userInterfaceStyle: .light))

        let hostNames = hostLayer.sublayers?.compactMap(\.name) ?? []
        XCTAssertEqual(hostNames, ["lifeboardHeaderGradientContainer"])

        let container = hostLayer.sublayers?.first(where: { $0.name == "lifeboardHeaderGradientContainer" })
        let layerNames = container?.sublayers?.compactMap(\.name) ?? []
        XCTAssertEqual(
            layerNames,
            ["lifeboardHeaderGradient", "lifeboardHeaderScrim", "lifeboardHeaderBottomFade", "lifeboardHeaderRadialHighlight", "lifeboardHeaderNoise"]
        )
    }

    func testHeaderGradientUsesBrandPatternFamilies() {
        let lightLayer = CALayer()
        LifeBoardHeaderGradient.apply(
            to: lightLayer,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 180),
            traits: UITraitCollection(userInterfaceStyle: .light)
        )

        guard let lightContainer = lightLayer.sublayers?.first(where: { $0.name == "lifeboardHeaderGradientContainer" }),
              let lightGradient = lightContainer.sublayers?.first(where: { $0.name == "lifeboardHeaderGradient" }) as? CAGradientLayer,
              let lightColors = lightGradient.colors as? [CGColor],
              lightColors.count == 4 else {
            return XCTFail("Missing light gradient colors")
        }

        XCTAssertEqual(UIColor(cgColor: lightColors[1]).cgColor.alpha, 1, accuracy: 0.01)

        let darkLayer = CALayer()
        LifeBoardHeaderGradient.apply(
            to: darkLayer,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 180),
            traits: UITraitCollection(userInterfaceStyle: .dark)
        )

        guard let darkContainer = darkLayer.sublayers?.first(where: { $0.name == "lifeboardHeaderGradientContainer" }),
              let darkGradient = darkContainer.sublayers?.first(where: { $0.name == "lifeboardHeaderGradient" }) as? CAGradientLayer,
              let darkColors = darkGradient.colors as? [CGColor],
              darkColors.count == 4 else {
            return XCTFail("Missing dark gradient colors")
        }

        XCTAssertNotEqual(UIColor(cgColor: lightColors[0]), UIColor(cgColor: darkColors[0]))
    }
}

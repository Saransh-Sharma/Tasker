import XCTest
import UIKit
@testable import LifeBoard

@MainActor
final class ColorTokenGenerationTests: XCTestCase {
    func testSunrisePaletteMatchesSpec() {
        let palette = LifeBoardBrandPalette.sunrise

        assertEqualColor(palette.brandEmerald, UIColor(lifeboardHex: "#28B53F"))
        assertEqualColor(palette.brandMagenta, UIColor(lifeboardHex: "#6842FF"))
        assertEqualColor(palette.brandMarigold, UIColor(lifeboardHex: "#FFB300"))
        assertEqualColor(palette.brandRed, UIColor(lifeboardHex: "#FF7A3D"))
        assertEqualColor(palette.brandSandstone, UIColor(lifeboardHex: "#FF7A3D"))
        assertEqualColor(palette.neutralIvory, UIColor(lifeboardHex: "#FFFDFC"))
        assertEqualColor(palette.neutralDarkInk0, UIColor(lifeboardHex: "#080C17"))
        assertEqualColor(palette.neutralDarkText1, UIColor(lifeboardHex: "#F7F1E7"))
    }

    // These assert the canonical warm paper/cocoa palette (unified presentation
    // is the default in DEBUG, where these tests run). The legacy sunrise
    // values remain covered by `testSunrisePaletteMatchesSpec`, which checks
    // the brand palette struct directly.
    func testSemanticNeutralsStayStableAcrossBrandTheme() {
        let colors = LifeBoardTheme(index: 0).tokens.color

        assertEqualColor(
            colors.bgCanvas.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(lifeboardHex: "#FFF7D8")
        )
        assertEqualColor(
            colors.bgCanvasSecondary.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(lifeboardHex: "#FAF2DA")
        )
        assertEqualColor(
            colors.bgCanvasSecondary.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            UIColor(lifeboardHex: "#111624")
        )
        assertEqualColor(
            colors.surfacePrimary.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            UIColor(lifeboardHex: "#202741").withAlphaComponent(0.92)
        )
    }

    func testPrimaryAndAssistantAccentsMatchBrandRoles() {
        let colors = LifeBoardTheme(index: 0).tokens.color

        // Primary action is cocoa ink on paper; the dark treatment flips to
        // warm sun so labels keep contrast.
        assertEqualColor(
            colors.primaryAction.resolvedColor(with: .init(userInterfaceStyle: .light)),
            UIColor(lifeboardHex: "#2B2118")
        )
        assertEqualColor(
            colors.primaryAction.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            UIColor(lifeboardHex: "#F0CD87")
        )
        // Assistant accent retains warm sun; status colors move to clay tones.
        assertEqualColor(colors.assistantAccent.resolvedColor(with: .init(userInterfaceStyle: .light)), UIColor(lifeboardHex: "#F0CD87"))
        assertEqualColor(colors.warningAccent.resolvedColor(with: .init(userInterfaceStyle: .light)), UIColor(lifeboardHex: "#8A6A2F"))
        assertEqualColor(colors.dangerAccent.resolvedColor(with: .init(userInterfaceStyle: .light)), UIColor(lifeboardHex: "#A14E41"))
        assertEqualColor(colors.stateInfo.resolvedColor(with: .init(userInterfaceStyle: .light)), UIColor(lifeboardHex: "#68727E"))
    }

    func testPriorityColorsUseBrandFamilies() {
        let colors = LifeBoardTheme(index: 0).tokens.color

        let traits = UITraitCollection(userInterfaceStyle: .light)
        assertEqualColor(colors.priorityNone.resolvedColor(with: traits), UIColor(lifeboardHex: "#877B68"))
        assertEqualColor(colors.priorityLow.resolvedColor(with: traits), UIColor(lifeboardHex: "#5D6A4D"))
        assertEqualColor(colors.priorityHigh.resolvedColor(with: traits), UIColor(lifeboardHex: "#B5654F"))
        assertEqualColor(colors.priorityMax.resolvedColor(with: traits), UIColor(lifeboardHex: "#A14E41"))
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

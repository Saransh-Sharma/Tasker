import XCTest
import UIKit
@testable import To_Do_List

final class ColorTokenGenerationTests: XCTestCase {
    func testDefaultAccentMatchesSpec() {
        XCTAssertEqual(TaskerTheme.accentThemes.first?.accentBaseHex.uppercased(), "#0D9488")
    }

    func testNeutralsAreStableAcrossThemes() {
        let first = TaskerTheme(index: 0).tokens.color
        let second = TaskerTheme(index: 2).tokens.color

        assertEqualColor(
            first.bgCanvas.resolvedColor(with: .init(userInterfaceStyle: .light)),
            second.bgCanvas.resolvedColor(with: .init(userInterfaceStyle: .light))
        )
        assertEqualColor(
            first.surfacePrimary.resolvedColor(with: .init(userInterfaceStyle: .dark)),
            second.surfacePrimary.resolvedColor(with: .init(userInterfaceStyle: .dark))
        )
    }

    func testAccentRampChangesWithTheme() {
        let first = TaskerTheme(index: 0).tokens.color
        let second = TaskerTheme(index: 1).tokens.color

        assertNotEqualColor(first.accentPrimary, second.accentPrimary)
        assertNotEqualColor(first.accentMuted, second.accentMuted)
    }

    func testThemePaletteReducedToThreeCuratedBases() {
        XCTAssertEqual(TaskerTheme.accentThemes.count, 3)
        let uniqueBases = Set(TaskerTheme.accentThemes.map { $0.accentBaseHex.uppercased() })
        XCTAssertEqual(uniqueBases.count, 3)
        XCTAssertTrue(uniqueBases.contains("#0D9488"))
        XCTAssertTrue(uniqueBases.contains("#3B82F6"))
        XCTAssertTrue(uniqueBases.contains("#16A34A"))
    }

    func testStatusColorsMatchSpec() {
        let colors = TaskerTheme(index: 0).tokens.color

        assertEqualColor(colors.statusSuccess, UIColor(taskerHex: "#16A34A"))
        assertEqualColor(colors.statusWarning, UIColor(taskerHex: "#D97706"))
        assertEqualColor(colors.statusDanger, UIColor(taskerHex: "#DC2626"))
    }

    func testThemePressedAndWashColorsMatchLockedSpec() {
        let harbor = TaskerTheme(index: 0).tokens.color
        let horizon = TaskerTheme(index: 1).tokens.color
        let canopy = TaskerTheme(index: 2).tokens.color

        assertEqualColor(harbor.accentPrimaryPressed, UIColor(taskerHex: "#0F766E"))
        assertEqualColor(harbor.accentWash, UIColor(taskerHex: "#CCFBF1"))

        assertEqualColor(horizon.accentPrimaryPressed, UIColor(taskerHex: "#2563EB"))
        assertEqualColor(horizon.accentWash, UIColor(taskerHex: "#DBEAFE"))

        assertEqualColor(canopy.accentPrimaryPressed, UIColor(taskerHex: "#15803D"))
        assertEqualColor(canopy.accentWash, UIColor(taskerHex: "#DCFCE7"))
    }

    func testAccentRampUsesSpecifiedHSLTransformAndClampRules() {
        let base = UIColor(taskerHex: "#F08A2B")
        let baseHSL = hsl(from: base)
        let ramp = TaskerAccentRamp(base: base)

        let expected600 = expectedRampColor(baseHSL: baseHSL, sDelta: 0.05, lDelta: -0.10)
        let expected400 = expectedRampColor(baseHSL: baseHSL, sDelta: -0.05, lDelta: 0.08)
        let expected100 = expectedRampColor(baseHSL: baseHSL, sDelta: -0.25, lDelta: 0.35)
        let expected050 = expectedRampColor(baseHSL: baseHSL, sDelta: -0.35, lDelta: 0.45)

        assertEqualColor(ramp.accent600, expected600)
        assertEqualColor(ramp.accent400, expected400)
        assertEqualColor(ramp.accent100, expected100)
        assertEqualColor(ramp.accent050, expected050)

        assertHSLInBounds(ramp.accent600)
        assertHSLInBounds(ramp.accent400)
        assertHSLInBounds(ramp.accent100)
        assertHSLInBounds(ramp.accent050)
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

    private func assertNotEqualColor(_ lhs: UIColor, _ rhs: UIColor, file: StaticString = #filePath, line: UInt = #line) {
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
        let isEqual = abs(lR - rR) < 0.001 && abs(lG - rG) < 0.001 && abs(lB - rB) < 0.001 && abs(lA - rA) < 0.001
        XCTAssertFalse(isEqual, file: file, line: line)
    }

    private func assertHSLInBounds(_ color: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        let values = hsl(from: color)
        XCTAssertGreaterThanOrEqual(values.s, 0.35 - 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(values.s, 0.95 + 0.001, file: file, line: line)
        XCTAssertGreaterThanOrEqual(values.l, 0.10 - 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(values.l, 0.92 + 0.001, file: file, line: line)
    }

    private func expectedRampColor(baseHSL: (h: CGFloat, s: CGFloat, l: CGFloat), sDelta: CGFloat, lDelta: CGFloat) -> UIColor {
        let saturation = clamp(baseHSL.s + sDelta, min: 0.35, max: 0.95)
        let lightness = clamp(baseHSL.l + lDelta, min: 0.10, max: 0.92)
        return UIColor(taskerHue: baseHSL.h, saturation: saturation, lightness: lightness, alpha: 1.0)
    }

    private func hsl(from color: UIColor) -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))

        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2

        let saturation: CGFloat
        if delta == 0 {
            saturation = 0
        } else {
            saturation = delta / (1 - abs(2 * lightness - 1))
        }

        let hue: CGFloat
        if delta == 0 {
            hue = 0
        } else if maxValue == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = ((blue - red) / delta) + 2
        } else {
            hue = ((red - green) / delta) + 4
        }

        let normalizedHue = ((hue * 60).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        return (normalizedHue, saturation, lightness)
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

@MainActor
final class HeaderGradientTokenTests: XCTestCase {
    func testHeaderGradientLayerOrderAndNames() {
        let hostLayer = CALayer()
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        TaskerHeaderGradient.apply(to: hostLayer, bounds: bounds, traits: UITraitCollection(userInterfaceStyle: .light))

        let hostNames = hostLayer.sublayers?.compactMap(\.name) ?? []
        XCTAssertEqual(hostNames, ["taskerHeaderGradientContainer"])

        let container = hostLayer.sublayers?.first(where: { $0.name == "taskerHeaderGradientContainer" })
        let layerNames = container?.sublayers?.compactMap(\.name) ?? []
        XCTAssertEqual(
            layerNames,
            ["taskerHeaderGradient", "taskerHeaderScrim", "taskerHeaderBottomFade", "taskerHeaderRadialHighlight", "taskerHeaderNoise"]
        )
    }

    func testHeaderScrimAlphaConstantsMatchSpec() {
        let lightLayer = CALayer()
        TaskerHeaderGradient.apply(
            to: lightLayer,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 180),
            traits: UITraitCollection(userInterfaceStyle: .light)
        )

        guard let lightContainer = lightLayer.sublayers?.first(where: { $0.name == "taskerHeaderGradientContainer" }),
              let lightScrim = lightContainer.sublayers?.first(where: { $0.name == "taskerHeaderScrim" }) as? CAGradientLayer,
              let lightColors = lightScrim.colors as? [CGColor],
              lightColors.count >= 2 else {
            return XCTFail("Missing light scrim colors")
        }

        XCTAssertEqual(UIColor(cgColor: lightColors[0]).cgColor.alpha, 0.18, accuracy: 0.01)
        XCTAssertEqual(UIColor(cgColor: lightColors[1]).cgColor.alpha, 0.10, accuracy: 0.01)

        let darkLayer = CALayer()
        TaskerHeaderGradient.apply(
            to: darkLayer,
            bounds: CGRect(x: 0, y: 0, width: 320, height: 180),
            traits: UITraitCollection(userInterfaceStyle: .dark)
        )

        guard let darkContainer = darkLayer.sublayers?.first(where: { $0.name == "taskerHeaderGradientContainer" }),
              let darkScrim = darkContainer.sublayers?.first(where: { $0.name == "taskerHeaderScrim" }) as? CAGradientLayer,
              let darkColors = darkScrim.colors as? [CGColor],
              darkColors.count >= 2 else {
            return XCTFail("Missing dark scrim colors")
        }

        XCTAssertEqual(UIColor(cgColor: darkColors[0]).cgColor.alpha, 0.26, accuracy: 0.01)
        XCTAssertEqual(UIColor(cgColor: darkColors[1]).cgColor.alpha, 0.14, accuracy: 0.01)
    }
}

import SwiftUI
import UIKit
import XCTest
@testable import LifeBoard

/// Every ink the app reads from, measured against every surface it can sit on,
/// in light, dark and both Increased Contrast variants.
///
/// The older contrast tests pin a handful of pairs (`inkPrimary`/`inkSecondary`
/// on the foundation planes, `LegibilityRole.primary`/`.secondary` on each
/// `SurfaceContext`). The appearance audit of 2026-09-18 found the failures in
/// the pairs nobody listed: metadata and status inks, the Sunrise-era clay inks
/// that ~345 call sites still use, and the per-role `deep` inks drawn on their
/// own `softSurface`. Each test collects every failing pair before asserting so
/// one run reports the whole defect list rather than the first hit.
@MainActor
final class AppearanceContrastMatrixTests: XCTestCase {

    private struct Cell: CustomStringConvertible {
        let style: UIUserInterfaceStyle
        let contrast: UIAccessibilityContrast
        var traits: UITraitCollection {
            UITraitCollection { traits in
                traits.userInterfaceStyle = style
                traits.accessibilityContrast = contrast
            }
        }
        var description: String {
            "\(style == .dark ? "dark" : "light")\(contrast == .high ? "+HC" : "")"
        }
    }

    private let cells: [Cell] = [
        Cell(style: .light, contrast: .normal), Cell(style: .light, contrast: .high),
        Cell(style: .dark, contrast: .normal), Cell(style: .dark, contrast: .high)
    ]

    /// Text floor for reading roles, 3:1 for non-text and large-text roles
    /// (WCAG 1.4.3 / 1.4.11). `disabled` is exempt by WCAG and `inverse` /
    /// `onImage` only apply on image or scrim contexts, which are measured by the
    /// image-policy tests rather than against a flat fallback surface.
    private func floor(for role: LegibilityRole) -> CGFloat? {
        switch role {
        case .primary, .secondary, .action, .link, .destructive, .onAccent:
            return 4.5
        case .metadata, .tertiary, .success, .warning, .focusRing:
            return 3.0
        case .disabled, .inverse, .onImage:
            return nil
        }
    }

    private func opaque(_ color: UIColor, over canvas: UIColor) -> UIColor {
        alphaComponent(color) < 1 ? composited(color, over: canvas) : color
    }

    private func report(_ failures: [String], _ what: String) {
        guard !failures.isEmpty else { return }
        XCTFail("\(failures.count) \(what) pairs below their floor:\n" + failures.joined(separator: "\n"))
    }

    func testEveryLegibilityRoleClearsEveryFlatSurfaceContext() {
        let colors = Theme(index: 0).tokens.color
        var failures: [String] = []
        for cell in cells {
            let canvas = colors.bgCanvas.resolvedColor(with: cell.traits)
            for context in SurfaceContext.allCases where context != .image && context != .modalScrim {
                guard let backgroundRole = context.fallbackBackgroundRole else { continue }
                let background = opaque(colors.color(for: backgroundRole).resolvedColor(with: cell.traits), over: canvas)
                for role in LegibilityRole.allCases {
                    // On an accent fill only the on-accent family is meaningful;
                    // status inks are never drawn on the accent itself.
                    if context == .accent, [.success, .warning, .destructive, .focusRing].contains(role) { continue }
                    // And the on-accent ink only ever sits on the accent fill.
                    if context != .accent, role == .onAccent { continue }
                    guard let minimum = floor(for: role) else { continue }
                    let ink = opaque(colors.color(for: role, on: context).resolvedColor(with: cell.traits), over: background)
                    let ratio = contrastRatio(ink, background)
                    if ratio < minimum {
                        failures.append(String(format: "%@ on %@ [%@] %.2f < %.1f",
                            role.rawValue, context.rawValue, cell.description, ratio, minimum))
                    }
                }
            }
        }
        report(failures, "role × surface")
    }

    /// The Sunrise-era inks are still drawn by ~345 call sites; nothing measured
    /// them against the clay canvases and glass they sit on.
    func testClayInksClearClaySurfaces() {
        let inks: [(String, Color, CGFloat)] = [
            ("navy", ClayColorTokens.navy, 4.5),
            ("navySoft", ClayColorTokens.navySoft, 4.5),
            ("navyMuted", ClayColorTokens.navyMuted, 4.5),
            ("textTertiary", ClayColorTokens.textTertiary, 3.0)
        ]
        let surfaces: [(String, Color)] = [
            ("canvas", ClayColorTokens.canvas), ("warmCanvas", ClayColorTokens.warmCanvas),
            ("coolCanvas", ClayColorTokens.coolCanvas), ("surfaceSolid", ClayColorTokens.surfaceSolid),
            ("glass", ClayColorTokens.glass), ("glassStrong", ClayColorTokens.glassStrong)
        ]
        var failures: [String] = []
        for cell in cells {
            let canvas = resolvedColor(ClayColorTokens.canvas, style: cell.style, contrast: cell.contrast)
            for (surfaceName, surface) in surfaces {
                let background = opaque(resolvedColor(surface, style: cell.style, contrast: cell.contrast), over: canvas)
                for (inkName, ink, minimum) in inks {
                    let ratio = contrastRatio(resolvedColor(ink, style: cell.style, contrast: cell.contrast), background)
                    if ratio < minimum {
                        failures.append(String(format: "%@ on %@ [%@] %.2f < %.1f",
                            inkName, surfaceName, cell.description, ratio, minimum))
                    }
                }
            }
        }
        report(failures, "clay ink × clay surface")
    }

    /// Role chips and badges draw `deep` — label and glyph alike — on the role's
    /// own `softSurface`. `base` is a fill; drawn as a glyph it sat at 1.4–2.7:1,
    /// so `IconBadge` and the Eva guide now draw `deep`.
    func testClayRoleInksClearTheirOwnSoftSurface() {
        let roles: [ClayRole] = [.routine, .windDown, .task, .meeting, .personal, .focus, .meal,
                                 .assistant, .warning, .error, .neutral]
        var failures: [String] = []
        for cell in cells {
            let canvas = resolvedColor(ClayColorTokens.canvas, style: cell.style, contrast: cell.contrast)
            for role in roles {
                let style = ClayColorTokens.role(role)
                let background = opaque(resolvedColor(style.softSurface, style: cell.style, contrast: cell.contrast), over: canvas)
                let deep = contrastRatio(resolvedColor(style.deep, style: cell.style, contrast: cell.contrast), background)
                if deep < 4.5 {
                    failures.append(String(format: "%@.deep text [%@] %.2f < 4.5", "\(role)", cell.description, deep))
                }
            }
        }
        report(failures, "role ink × soft surface")
    }

    /// Warm foundation accents are fills. Where a view draws one as ink — a
    /// label, a meaningful glyph, a chart stroke, a completion or toggle-on
    /// state — it must use the matching ink token, which has to clear the
    /// non-text floor on every foundation plane it can sit on.
    func testFoundationAccentInksClearFoundationPlanes() {
        let inks: [(String, UIColor, CGFloat)] = [
            ("foundationApricotInk", SemanticColorTokens.foundationApricotInk, 3.0),
            ("foundationSageInk", SemanticColorTokens.foundationSageInk, 3.0),
            ("foundationSunInk", SemanticColorTokens.foundationSunInk, 3.0)
        ]
        let planes: [(String, UIColor)] = [
            ("canvas", SemanticColorTokens.foundationCanvas),
            ("canvasSoft", SemanticColorTokens.foundationCanvasSoft),
            ("canvasMuted", SemanticColorTokens.foundationCanvasMuted),
            ("surfaceSolid", SemanticColorTokens.foundationSurfaceSolid),
            ("surfaceRecessed", SemanticColorTokens.foundationSurfaceRecessed),
            ("surfaceSelected", SemanticColorTokens.foundationSurfaceSelected)
        ]
        var failures: [String] = []
        for cell in cells {
            for (planeName, plane) in planes {
                let background = plane.resolvedColor(with: cell.traits)
                for (inkName, ink, minimum) in inks {
                    let ratio = contrastRatio(ink.resolvedColor(with: cell.traits), background)
                    if ratio < minimum {
                        failures.append(String(format: "%@ on %@ [%@] %.2f < %.1f",
                            inkName, planeName, cell.description, ratio, minimum))
                    }
                }
            }
        }
        report(failures, "foundation accent ink × plane")
    }
}

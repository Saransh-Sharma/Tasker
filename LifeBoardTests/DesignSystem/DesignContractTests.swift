import XCTest
import UIKit
@testable import LifeBoard

/// `DESIGN.md` is the contract. This asserts the code implements it.
///
/// The document opens with a YAML front-matter block naming every colour,
/// radius, spacing step and type style. Nothing read it. The result was three
/// scales drifting independently for months while every existing token test
/// passed — because those tests compare a token to a hex literal copied from
/// the same place the token came from, which proves the code is
/// self-consistent and says nothing about whether it matches the brief.
///
/// The drift found when this was written:
///   - the contract's 20pt raised-card radius existed nowhere in the token
///     layer, so 136 call sites hardcoded 18 or 22 instead;
///   - the entire body/button type tier shipped a point short of 17;
///   - the metric numeral was 24 against a specified 28;
///   - twelve colours disagreed, and `surface-raised` had no token at all;
///   - and the document contained a paragraph asserting that the colour table
///     had already been reconciled with the code, which was false.
///
/// So the failure mode is not "someone edited a token carelessly". It is that
/// the contract and the implementation had no mechanical relationship at all.
/// This test is that relationship.
@MainActor
final class DesignContractTests: XCTestCase {

    // MARK: - Front-matter parsing

    /// The `key: "value"` pairs from a named section of the YAML front matter.
    private func frontMatterSection(_ section: String) throws -> [String: String] {
        let document = try loadWorkspaceFile("DESIGN.md")
        guard document.hasPrefix("---") else {
            throw XCTSkip("DESIGN.md has no front matter")
        }
        // Front matter is delimited by the first two `---` lines.
        let lines = document.components(separatedBy: "\n")
        guard let closing = lines.dropFirst().firstIndex(of: "---") else {
            throw XCTSkip("DESIGN.md front matter is unterminated")
        }
        let frontMatter = Array(lines[1..<closing])

        var values: [String: String] = [:]
        var inSection = false
        for line in frontMatter {
            if line.hasPrefix("\(section):") { inSection = true; continue }
            // Any other top-level key ends the section.
            if inSection, line.first?.isWhitespace == false, line.contains(":") { break }
            guard inSection else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<colon])
            var value = String(trimmed[trimmed.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard key.isEmpty == false, value.isEmpty == false else { continue }
            values[key] = value
        }
        XCTAssertFalse(values.isEmpty, "No `\(section):` entries parsed out of DESIGN.md")
        return values
    }

    private func hex(_ color: UIColor, _ style: UIUserInterfaceStyle) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: .init(userInterfaceStyle: style)).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }

    private func points(_ value: String) -> CGFloat? {
        CGFloat(Double(value.replacingOccurrences(of: "px", with: "")) ?? .nan).isNaN
            ? nil
            : CGFloat(Double(value.replacingOccurrences(of: "px", with: ""))!)
    }

    // MARK: - Shapes

    func testRoundedVocabularyMatchesTheContract() throws {
        let rounded = try frontMatterSection("rounded")
        let expected: [(String, CGFloat)] = [
            ("field", Radius.field),
            ("row", Radius.row),
            ("card", Radius.card),
            ("hero", Radius.hero),
            ("modal", Radius.modal),
            ("dock", Radius.dock)
        ]
        for (key, actual) in expected {
            guard let specified = rounded[key].flatMap(points) else {
                XCTFail("DESIGN.md rounded.\(key) is missing")
                continue
            }
            XCTAssertEqual(actual, specified, "Radius.\(key) is \(actual), DESIGN.md says \(specified)")
        }
        XCTAssertEqual(Radius.pill, 999)
    }

    /// The clay depth scale draws from the same vocabulary.
    func testClayDepthRadiiComeFromTheContractVocabulary() throws {
        let rounded = try frontMatterSection("rounded")
        XCTAssertEqual(ClayDepth.well.cornerRadius, rounded["field"].flatMap(points))
        XCTAssertEqual(ClayDepth.resting.cornerRadius, rounded["row"].flatMap(points))
        XCTAssertEqual(ClayDepth.raised.cornerRadius, rounded["card"].flatMap(points))

        // The hero radius is exclusive. DESIGN.md calls 24 "the continuity"
        // between the card that represents a surface, the hero it opens into
        // and the opaque fallback that replaces it — which only works if no
        // content plane also uses it.
        let hero = rounded["hero"].flatMap(points)
        XCTAssertEqual(Radius.hero, hero)
        for depth in ClayDepth.allCases {
            XCTAssertNotEqual(
                depth.cornerRadius, hero,
                "ClayDepth.\(depth.rawValue) shares the hero radius, so the hero silhouette is no longer unique"
            )
        }
    }

    // MARK: - Spacing

    func testSpacingRhythmMatchesTheContract() throws {
        let spacing = try frontMatterSection("spacing")
        let tokens = Theme(index: 0).tokens.spacing
        XCTAssertEqual(tokens.screenHorizontal, spacing["phone-margin"].flatMap(points))
        XCTAssertEqual(tokens.buttonHeight, spacing["action-height"].flatMap(points))
        XCTAssertEqual(tokens.sectionGap, spacing["xxl"].flatMap(points))
        XCTAssertEqual(ClayLayoutMetrics.screenMargin, spacing["phone-margin"].flatMap(points))
        XCTAssertEqual(ClayLayoutMetrics.bottomDockClearance, spacing["compact-chrome-clearance"].flatMap(points))
    }

    // MARK: - Typography

    func testTypeScaleMatchesTheContract() throws {
        let typography = try loadWorkspaceFile("DESIGN.md")
        // The typography section is nested (style -> fontSize), so pull the
        // sizes positionally rather than with the flat parser.
        func size(of style: String) -> CGFloat? {
            guard let range = typography.range(of: "  \(style):\n") else { return nil }
            let tail = typography[range.upperBound...].prefix(220)
            guard let line = tail.components(separatedBy: "\n").first(where: { $0.contains("fontSize:") }) else { return nil }
            let digits = line.filter { $0.isNumber }
            return CGFloat(Double(digits) ?? .nan).isNaN ? nil : CGFloat(Double(digits)!)
        }

        let tokens = SemanticTypographyTokens.makeDefault()
        let expected: [(String, UIFont)] = [
            ("display", tokens.heroDisplay),
            ("screen-title", tokens.screenTitle),
            ("section-title", tokens.sectionTitle),
            ("body", tokens.body),
            ("body-strong", tokens.bodyStrong),
            ("support", tokens.support),
            ("metadata", tokens.meta),
            ("button", tokens.button),
            ("metric", tokens.metric),
            ("metric-meta", tokens.monoMeta)
        ]
        for (key, font) in expected {
            guard let specified = size(of: key) else {
                XCTFail("DESIGN.md typography.\(key).fontSize is missing")
                continue
            }
            XCTAssertEqual(
                font.pointSize, specified, accuracy: 0.01,
                "typography.\(key) is \(font.pointSize)pt, DESIGN.md says \(specified)pt"
            )
        }
    }

    // MARK: - Colour

    func testColourTableMatchesTheContract() throws {
        let colors = try frontMatterSection("colors")
        let light: [(String, UIColor)] = [
            ("canvas", SemanticColorTokens.foundationCanvas),
            ("canvas-muted", SemanticColorTokens.foundationCanvasSoft),
            ("surface", SemanticColorTokens.foundationSurfaceSolid),
            ("surface-raised", SemanticColorTokens.foundationSurfaceRaised),
            ("surface-recessed", SemanticColorTokens.foundationSurfaceRecessed),
            ("selected", SemanticColorTokens.foundationSurfaceSelected),
            ("text-primary", SemanticColorTokens.inkPrimary),
            ("text-secondary", SemanticColorTokens.inkSecondary),
            ("text-tertiary", SemanticColorTokens.inkTertiary),
            ("border", SemanticColorTokens.foundationHairline),
            ("focus", SemanticColorTokens.foundationFocusRing),
            ("error", SemanticColorTokens.foundationDanger)
        ]
        for (key, token) in light {
            guard let specified = colors[key] else {
                XCTFail("DESIGN.md colors.\(key) is missing")
                continue
            }
            XCTAssertEqual(
                hex(token, .light), specified.uppercased(),
                "colors.\(key): code resolves \(hex(token, .light)), DESIGN.md says \(specified)"
            )
        }

        let dark: [(String, UIColor)] = [
            ("dark-canvas", SemanticColorTokens.foundationCanvas),
            ("dark-surface", SemanticColorTokens.foundationSurfaceSolid),
            ("dark-surface-raised", SemanticColorTokens.foundationSurfaceRaised),
            ("dark-surface-recessed", SemanticColorTokens.foundationSurfaceRecessed),
            ("dark-text-primary", SemanticColorTokens.inkPrimary),
            ("dark-text-secondary", SemanticColorTokens.inkSecondary),
            ("dark-text-tertiary", SemanticColorTokens.inkTertiary),
            ("dark-border", SemanticColorTokens.foundationHairline)
        ]
        for (key, token) in dark {
            guard let specified = colors[key] else {
                XCTFail("DESIGN.md colors.\(key) is missing")
                continue
            }
            XCTAssertEqual(
                hex(token, .dark), specified.uppercased(),
                "colors.\(key): code resolves \(hex(token, .dark)), DESIGN.md says \(specified)"
            )
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: workspaceRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

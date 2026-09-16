import SwiftUI
#if DEBUG
@_spi(DesignEvidence) import LifeBoardUI
#endif

/// Optional evidence hook. Production never installs a recorder.
final class HomeCardGeometryRecorder {
    var content: CGRect = .zero
    var scene: CGRect = .zero
    // An explicit offscreen capture retains its already prepared image. NSCache
    // may evict between preload and ImageRenderer, whose view tasks do not run.
    var preparedScene: UIImage?
    var elements: [String: Element] = [:]

    struct Element: Codable {
        let id: String
        let role: String
        let copy: String
        let rect: [Double]
        let typography: Typography?
        var fraction: Double? = nil
    }

    struct Typography: Codable {
        let role: String
        let points: Double
        let weight: String
        var design = "default"
        var alignment = "leading"
    }
}

extension EnvironmentValues {
    @Entry var homeCardGeometryRecorder: HomeCardGeometryRecorder? = nil
}

private struct HomeCardEvidenceElement: ViewModifier {
    @Environment(\.homeCardGeometryRecorder) private var recorder
    let id: String
    let role: String
    let copy: String
    let typography: HomeCardGeometryRecorder.Typography?
    let fraction: Double?

    func body(content: Content) -> some View {
        if let recorder {
            content.background {
                GeometryReader { geometry in
                    let rect = geometry.frame(in: .named("home.card.evidence"))
                    let _ = record(recorder, rect)
                    Color.clear
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        } else {
            content
        }
    }

    private func record(_ recorder: HomeCardGeometryRecorder, _ rect: CGRect) {
        recorder.elements[id] = .init(id: id, role: role, copy: copy,
            rect: [rect.minX, rect.minY, rect.width, rect.height], typography: typography, fraction: fraction)
    }
}

extension View {
    /// Installed only by explicit evidence captures. No production geometry observers.
    func homeCardEvidence(_ id: String, role: String, copy: String = "",
                          typography: HomeCardGeometryRecorder.Typography? = nil, fraction: Double? = nil) -> some View {
        modifier(HomeCardEvidenceElement(id: id, role: role, copy: copy, typography: typography, fraction: fraction))
    }
}

/// Resolves the package readout's actual value/unit views into capture metadata.
struct HomeNumericRollEvidenceAdapter: ViewModifier {
    @Environment(\.homeCardGeometryRecorder) private var recorder
    func body(content: Content) -> some View {
        #if DEBUG
        if let recorder {
            content.environment(\.numericRollEvidenceSink, NumericRollEvidenceSink { id, copy, rect, style in
                let font = SemanticTypographyTokens.makeDefault().dynamicFont(for: style,
                    compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
                recorder.elements["metric." + id] = .init(id: "metric." + id,
                    role: id == "value" ? "value" : "unit", copy: copy,
                    rect: [rect.minX, rect.minY, rect.width, rect.height],
                    typography: .init(role: String(describing: style), points: font.pointSize,
                        weight: style == .caption1 ? "regular" : "bold",
                        design: style == .metric ? "rounded" : "default"))
            })
        } else { content }
        #else
        content
        #endif
    }
}

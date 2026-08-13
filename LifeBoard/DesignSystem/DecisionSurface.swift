import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// Truthful status, or measured progress. Never both.
public enum DecisionProgress: Equatable, Sendable {
    case fraction(Double, label: String)
    case status(String)
}

/// The single quiet alternative a decision may offer.
public struct DecisionAlternative {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

/// The one dominant object on a screen.
///
/// `DESIGN.md:434`: "one short title, one line of useful context, one primary
/// action, and at most one quiet alternative. It may show progress or a truthful
/// status, but never a dashboard of metrics."
///
/// That contract is enforced by the *shape of this type*, which is the point.
/// There is no slot for a second alternative, no array of metrics, and
/// `DecisionProgress` is an enum rather than two optional properties so a caller
/// cannot show a ring and a status line at once. A convention in a style guide
/// drifts; a type that cannot express the violation does not.
///
/// Lives in `LifeBoard/DesignSystem/` rather than `LifeBoardUI` because it
/// reaches for `clayPressBloom`, and the signature effects are app-target.
public struct DecisionSurface<Primary: View>: View {
    private let title: String
    private let context: String?
    private let progress: DecisionProgress?
    private let alternative: DecisionAlternative?
    private let accessibilityID: String?
    private let primary: Primary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pressTrigger = 0

    public init(
        title: String,
        context: String? = nil,
        progress: DecisionProgress? = nil,
        alternative: DecisionAlternative? = nil,
        accessibilityID: String? = nil,
        @ViewBuilder primary: () -> Primary
    ) {
        self.title = title
        self.context = context
        self.progress = progress
        self.alternative = alternative
        self.accessibilityID = accessibilityID
        self.primary = primary()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DecisionSurfaceHeader(title: title, context: context, progress: progress)
            DecisionSurfaceActions(
                alternative: alternative,
                usesStackedLayout: dynamicTypeSize.isAccessibilitySize,
                primary: primary
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Raised clay, not glass. DESIGN.md reserves Liquid Glass for the
        // navigation and control layer; a decision is content.
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .lifeboardClayPressBloom(trigger: pressTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID ?? "lifeboard.decision")
    }
}

/// Title, context, and the single progress reading.
private struct DecisionSurfaceHeader: View {
    let title: String
    let context: String?
    let progress: DecisionProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .fixedSize(horizontal: false, vertical: true)

            if let context {
                Text(context)
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progress {
                DecisionSurfaceProgress(progress: progress)
                    .padding(.top, 2)
            }
        }
    }
}

private struct DecisionSurfaceProgress: View {
    let progress: DecisionProgress

    var body: some View {
        switch progress {
        case let .fraction(value, label):
            VStack(alignment: .leading, spacing: 5) {
                // A recessed well, per DESIGN.md's plane vocabulary: progress
                // tracks are inset, not raised.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(SemanticColorTokens.foundationSurfaceRecessed))
                        Capsule()
                            .fill(Color(SemanticColorTokens.foundationApricotAccent))
                            .frame(width: proxy.size.width * min(1, max(0, value)))
                    }
                }
                .frame(height: 6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(min(1, max(0, value)) * 100)) percent")
        case let .status(text):
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }
}

/// The primary action, and at most one quiet alternative.
private struct DecisionSurfaceActions<Primary: View>: View {
    let alternative: DecisionAlternative?
    let usesStackedLayout: Bool
    let primary: Primary

    var body: some View {
        let layout = usesStackedLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        layout {
            primary
                .frame(maxWidth: usesStackedLayout ? .infinity : nil)
            if let alternative {
                Button(alternative.title, action: alternative.action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .lifeBoardPressResponse(.control, haptic: nil)
                    .accessibilityIdentifier("lifeboard.decision.alternative")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

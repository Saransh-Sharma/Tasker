import UIKit

public struct TaskerTypographyTokens: TaskerTokenGroup {
    private struct Spec {
        let textStyle: UIFont.TextStyle
        let pointSize: CGFloat
        let weight: UIFont.Weight
        let maximumPointSize: CGFloat?
    }

    public let display: UIFont
    public let title1: UIFont
    public let title2: UIFont
    public let title3: UIFont
    public let headline: UIFont
    public let body: UIFont
    public let bodyEmphasis: UIFont
    public let callout: UIFont
    public let caption1: UIFont
    public let caption2: UIFont
    public let button: UIFont
    public let buttonSmall: UIFont

    public func font(for style: TaskerTextStyle) -> UIFont {
        switch style {
        case .display: return display
        case .title1: return title1
        case .title2: return title2
        case .title3: return title3
        case .headline: return headline
        case .body: return body
        case .bodyEmphasis: return bodyEmphasis
        case .callout: return callout
        case .caption1: return caption1
        case .caption2: return caption2
        case .button: return button
        case .buttonSmall: return buttonSmall
        }
    }

    public func dynamicFont(for style: TaskerTextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        Self.font(for: Self.spec(for: style), compatibleWith: traitCollection)
    }

    public static func makeDefault() -> TaskerTypographyTokens {
        TaskerTypographyTokens(
            display: font(for: spec(for: .display), compatibleWith: nil),
            title1: font(for: spec(for: .title1), compatibleWith: nil),
            title2: font(for: spec(for: .title2), compatibleWith: nil),
            title3: font(for: spec(for: .title3), compatibleWith: nil),
            headline: font(for: spec(for: .headline), compatibleWith: nil),
            body: font(for: spec(for: .body), compatibleWith: nil),
            bodyEmphasis: font(for: spec(for: .bodyEmphasis), compatibleWith: nil),
            callout: font(for: spec(for: .callout), compatibleWith: nil),
            caption1: font(for: spec(for: .caption1), compatibleWith: nil),
            caption2: font(for: spec(for: .caption2), compatibleWith: nil),
            button: font(for: spec(for: .button), compatibleWith: nil),
            buttonSmall: font(for: spec(for: .buttonSmall), compatibleWith: nil)
        )
    }

    private static func spec(for style: TaskerTextStyle) -> Spec {
        switch style {
        case .display:
            return Spec(textStyle: .largeTitle, pointSize: 30, weight: .semibold, maximumPointSize: 40)
        case .title1:
            return Spec(textStyle: .title1, pointSize: 22, weight: .semibold, maximumPointSize: nil)
        case .title2:
            return Spec(textStyle: .title2, pointSize: 18, weight: .semibold, maximumPointSize: nil)
        case .title3:
            return Spec(textStyle: .headline, pointSize: 16, weight: .semibold, maximumPointSize: nil)
        case .headline:
            return Spec(textStyle: .headline, pointSize: 16, weight: .semibold, maximumPointSize: nil)
        case .body:
            return Spec(textStyle: .body, pointSize: 16, weight: .regular, maximumPointSize: nil)
        case .bodyEmphasis:
            return Spec(textStyle: .body, pointSize: 16, weight: .medium, maximumPointSize: nil)
        case .callout:
            return Spec(textStyle: .callout, pointSize: 14, weight: .regular, maximumPointSize: nil)
        case .caption1:
            return Spec(textStyle: .caption1, pointSize: 13, weight: .regular, maximumPointSize: nil)
        case .caption2:
            return Spec(textStyle: .caption2, pointSize: 12, weight: .regular, maximumPointSize: nil)
        case .button:
            return Spec(textStyle: .body, pointSize: 16, weight: .semibold, maximumPointSize: nil)
        case .buttonSmall:
            return Spec(textStyle: .callout, pointSize: 14, weight: .semibold, maximumPointSize: nil)
        }
    }

    private static func font(for spec: Spec, compatibleWith traitCollection: UITraitCollection?) -> UIFont {
        let baseFont = UIFont.systemFont(ofSize: spec.pointSize, weight: spec.weight)
        let metrics = UIFontMetrics(forTextStyle: spec.textStyle)
        if let maximumPointSize = spec.maximumPointSize {
            return metrics.scaledFont(for: baseFont, maximumPointSize: maximumPointSize, compatibleWith: traitCollection)
        }
        return metrics.scaledFont(for: baseFont, compatibleWith: traitCollection)
    }
}

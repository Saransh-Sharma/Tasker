import UIKit

public struct TaskerTypographyTokens: TaskerTokenGroup {
    private struct Spec {
        let textStyle: UIFont.TextStyle
        let pointSize: CGFloat
        let weight: UIFont.Weight
        let maximumPointSize: CGFloat?
        let rounded: Bool
        let monospaced: Bool
    }

    public let heroDisplay: UIFont
    public let screenTitle: UIFont
    public let sectionTitle: UIFont
    public let eyebrow: UIFont
    public let display: UIFont
    public let title1: UIFont
    public let title2: UIFont
    public let title3: UIFont
    public let headline: UIFont
    public let body: UIFont
    public let bodyStrong: UIFont
    public let bodyEmphasis: UIFont
    public let support: UIFont
    public let meta: UIFont
    public let callout: UIFont
    public let metric: UIFont
    public let monoMeta: UIFont
    public let caption1: UIFont
    public let caption2: UIFont
    public let button: UIFont
    public let buttonSmall: UIFont

    private static let cacheLock = NSLock()
    private static var cacheByLayoutClass: [TaskerLayoutClass: TaskerTypographyTokens] = [:]

    /// Executes font.
    public func font(for style: TaskerTextStyle) -> UIFont {
        switch style {
        case .heroDisplay: return heroDisplay
        case .screenTitle: return screenTitle
        case .sectionTitle: return sectionTitle
        case .eyebrow: return eyebrow
        case .display: return display
        case .title1: return title1
        case .title2: return title2
        case .title3: return title3
        case .headline: return headline
        case .body: return body
        case .bodyStrong: return bodyStrong
        case .bodyEmphasis: return bodyEmphasis
        case .support: return support
        case .meta: return meta
        case .callout: return callout
        case .metric: return metric
        case .monoMeta: return monoMeta
        case .caption1: return caption1
        case .caption2: return caption2
        case .button: return button
        case .buttonSmall: return buttonSmall
        }
    }

    /// Executes dynamicFont.
    public func dynamicFont(for style: TaskerTextStyle, compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        Self.font(for: Self.spec(for: style, scale: 1.0), compatibleWith: traitCollection)
    }

    /// Executes makeDefault.
    public static func makeDefault() -> TaskerTypographyTokens {
        make(for: .phone)
    }

    /// Executes make.
    public static func make(for layoutClass: TaskerLayoutClass) -> TaskerTypographyTokens {
        cacheLock.lock()
        if let cached = cacheByLayoutClass[layoutClass] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let scale = scaleFactor(for: layoutClass)
        let tokens = TaskerTypographyTokens(
            heroDisplay: font(for: spec(for: .heroDisplay, scale: scale), compatibleWith: nil),
            screenTitle: font(for: spec(for: .screenTitle, scale: scale), compatibleWith: nil),
            sectionTitle: font(for: spec(for: .sectionTitle, scale: scale), compatibleWith: nil),
            eyebrow: font(for: spec(for: .eyebrow, scale: scale), compatibleWith: nil),
            display: font(for: spec(for: .display, scale: scale), compatibleWith: nil),
            title1: font(for: spec(for: .title1, scale: scale), compatibleWith: nil),
            title2: font(for: spec(for: .title2, scale: scale), compatibleWith: nil),
            title3: font(for: spec(for: .title3, scale: scale), compatibleWith: nil),
            headline: font(for: spec(for: .headline, scale: scale), compatibleWith: nil),
            body: font(for: spec(for: .body, scale: scale), compatibleWith: nil),
            bodyStrong: font(for: spec(for: .bodyStrong, scale: scale), compatibleWith: nil),
            bodyEmphasis: font(for: spec(for: .bodyEmphasis, scale: scale), compatibleWith: nil),
            support: font(for: spec(for: .support, scale: scale), compatibleWith: nil),
            meta: font(for: spec(for: .meta, scale: scale), compatibleWith: nil),
            callout: font(for: spec(for: .callout, scale: scale), compatibleWith: nil),
            metric: font(for: spec(for: .metric, scale: scale), compatibleWith: nil),
            monoMeta: font(for: spec(for: .monoMeta, scale: scale), compatibleWith: nil),
            caption1: font(for: spec(for: .caption1, scale: scale), compatibleWith: nil),
            caption2: font(for: spec(for: .caption2, scale: scale), compatibleWith: nil),
            button: font(for: spec(for: .button, scale: scale), compatibleWith: nil),
            buttonSmall: font(for: spec(for: .buttonSmall, scale: scale), compatibleWith: nil)
        )

        cacheLock.lock()
        cacheByLayoutClass[layoutClass] = tokens
        cacheLock.unlock()
        return tokens
    }

    static func resetCache() {
        cacheLock.lock()
        cacheByLayoutClass.removeAll(keepingCapacity: true)
        cacheLock.unlock()
    }

    /// Executes spec.
    private static func spec(for style: TaskerTextStyle, scale: CGFloat) -> Spec {
        func scaled(_ base: CGFloat) -> CGFloat {
            max(11, base * scale)
        }

        switch style {
        case .heroDisplay:
            return Spec(textStyle: .largeTitle, pointSize: scaled(32), weight: .bold, maximumPointSize: scaled(42), rounded: false, monospaced: false)
        case .screenTitle:
            return Spec(textStyle: .title1, pointSize: scaled(28), weight: .semibold, maximumPointSize: scaled(34), rounded: false, monospaced: false)
        case .sectionTitle:
            return Spec(textStyle: .title3, pointSize: scaled(20), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .eyebrow:
            return Spec(textStyle: .caption1, pointSize: scaled(12), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .display:
            return Spec(textStyle: .largeTitle, pointSize: scaled(28), weight: .semibold, maximumPointSize: scaled(38), rounded: false, monospaced: false)
        case .title1:
            return Spec(textStyle: .title1, pointSize: scaled(22), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .title2:
            return Spec(textStyle: .title2, pointSize: scaled(18), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .title3:
            return Spec(textStyle: .headline, pointSize: scaled(16), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .headline:
            return Spec(textStyle: .headline, pointSize: scaled(16), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .body:
            return Spec(textStyle: .body, pointSize: scaled(16), weight: .regular, maximumPointSize: nil, rounded: false, monospaced: false)
        case .bodyStrong:
            return Spec(textStyle: .body, pointSize: scaled(16), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .bodyEmphasis:
            return Spec(textStyle: .body, pointSize: scaled(16), weight: .medium, maximumPointSize: nil, rounded: false, monospaced: false)
        case .support:
            return Spec(textStyle: .subheadline, pointSize: scaled(15), weight: .regular, maximumPointSize: nil, rounded: false, monospaced: false)
        case .meta:
            return Spec(textStyle: .footnote, pointSize: scaled(13), weight: .medium, maximumPointSize: nil, rounded: false, monospaced: false)
        case .callout:
            return Spec(textStyle: .callout, pointSize: scaled(14), weight: .regular, maximumPointSize: nil, rounded: false, monospaced: false)
        case .metric:
            return Spec(textStyle: .title2, pointSize: scaled(24), weight: .bold, maximumPointSize: scaled(32), rounded: true, monospaced: false)
        case .monoMeta:
            return Spec(textStyle: .caption1, pointSize: scaled(12), weight: .medium, maximumPointSize: nil, rounded: false, monospaced: true)
        case .caption1:
            return Spec(textStyle: .caption1, pointSize: scaled(13), weight: .regular, maximumPointSize: nil, rounded: false, monospaced: false)
        case .caption2:
            return Spec(textStyle: .caption2, pointSize: scaled(12), weight: .regular, maximumPointSize: nil, rounded: false, monospaced: false)
        case .button:
            return Spec(textStyle: .body, pointSize: scaled(16), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        case .buttonSmall:
            return Spec(textStyle: .callout, pointSize: scaled(14), weight: .semibold, maximumPointSize: nil, rounded: false, monospaced: false)
        }
    }

    /// Executes scaleFactor.
    private static func scaleFactor(for layoutClass: TaskerLayoutClass) -> CGFloat {
        switch layoutClass {
        case .phone:
            return 1.0
        case .padCompact:
            return 1.04
        case .padRegular:
            return 1.1
        case .padExpanded:
            return 1.14
        }
    }

    /// Executes font.
    private static func font(for spec: Spec, compatibleWith traitCollection: UITraitCollection?) -> UIFont {
        let baseFont: UIFont
        if spec.monospaced {
            baseFont = UIFont.monospacedSystemFont(ofSize: spec.pointSize, weight: spec.weight)
        } else if spec.rounded {
            let descriptor = UIFont.systemFont(ofSize: spec.pointSize, weight: spec.weight).fontDescriptor
            let roundedDescriptor = descriptor.withDesign(.rounded) ?? descriptor
            baseFont = UIFont(descriptor: roundedDescriptor, size: spec.pointSize)
        } else {
            baseFont = UIFont.systemFont(ofSize: spec.pointSize, weight: spec.weight)
        }
        let metrics = UIFontMetrics(forTextStyle: spec.textStyle)
        if let maximumPointSize = spec.maximumPointSize {
            return metrics.scaledFont(for: baseFont, maximumPointSize: maximumPointSize, compatibleWith: traitCollection)
        }
        return metrics.scaledFont(for: baseFont, compatibleWith: traitCollection)
    }
}

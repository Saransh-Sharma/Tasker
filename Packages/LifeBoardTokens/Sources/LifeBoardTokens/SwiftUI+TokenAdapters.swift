@preconcurrency import SwiftUI
import UIKit

public struct SwiftUIColorTokens {
    public let bgCanvas: Color
    public let bgCanvasSecondary: Color
    public let bgElevated: Color
    public let surfacePrimary: Color
    public let surfaceSecondary: Color
    public let surfaceTertiary: Color
    public let brandPrimary: Color
    public let brandSecondary: Color
    public let brandHighlight: Color
    public let actionPrimary: Color
    public let actionPrimaryPressed: Color
    public let actionFocus: Color
    public let borderSubtle: Color
    public let borderDefault: Color
    public let borderStrong: Color
    public let divider: Color
    public let strokeHairline: Color
    public let strokeStrong: Color

    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let textQuaternary: Color
    public let textInverse: Color
    public let textDisabled: Color

    public let accentPrimary: Color
    public let accentPrimaryPressed: Color
    public let accentMuted: Color
    public let accentWash: Color
    public let accentOnPrimary: Color
    public let accentRing: Color

    public let accentSecondary: Color
    public let accentSecondaryMuted: Color
    public let accentSecondaryWash: Color

    public let statusSuccess: Color
    public let statusWarning: Color
    public let statusDanger: Color
    public let stateInfo: Color

    public let priorityMax: Color
    public let priorityHigh: Color
    public let priorityLow: Color
    public let priorityNone: Color

    /// Initializes a new instance.
    public init(_ ui: SemanticColorTokens) {
        self.bgCanvas = Color(uiColor: ui.bgCanvas)
        self.bgCanvasSecondary = Color(uiColor: ui.bgCanvasSecondary)
        self.bgElevated = Color(uiColor: ui.bgElevated)
        self.surfacePrimary = Color(uiColor: ui.surfacePrimary)
        self.surfaceSecondary = Color(uiColor: ui.surfaceSecondary)
        self.surfaceTertiary = Color(uiColor: ui.surfaceTertiary)
        self.brandPrimary = Color(uiColor: ui.brandPrimary)
        self.brandSecondary = Color(uiColor: ui.brandSecondary)
        self.brandHighlight = Color(uiColor: ui.brandHighlight)
        self.actionPrimary = Color(uiColor: ui.actionPrimary)
        self.actionPrimaryPressed = Color(uiColor: ui.actionPrimaryPressed)
        self.actionFocus = Color(uiColor: ui.actionFocus)
        self.borderSubtle = Color(uiColor: ui.borderSubtle)
        self.borderDefault = Color(uiColor: ui.borderDefault)
        self.borderStrong = Color(uiColor: ui.borderStrong)
        self.divider = Color(uiColor: ui.divider)
        self.strokeHairline = Color(uiColor: ui.strokeHairline)
        self.strokeStrong = Color(uiColor: ui.strokeStrong)
        self.textPrimary = Color(uiColor: ui.textPrimary)
        self.textSecondary = Color(uiColor: ui.textSecondary)
        self.textTertiary = Color(uiColor: ui.textTertiary)
        self.textQuaternary = Color(uiColor: ui.textQuaternary)
        self.textInverse = Color(uiColor: ui.textInverse)
        self.textDisabled = Color(uiColor: ui.textDisabled)
        self.accentPrimary = Color(uiColor: ui.accentPrimary)
        self.accentPrimaryPressed = Color(uiColor: ui.accentPrimaryPressed)
        self.accentMuted = Color(uiColor: ui.accentMuted)
        self.accentWash = Color(uiColor: ui.accentWash)
        self.accentOnPrimary = Color(uiColor: ui.accentOnPrimary)
        self.accentRing = Color(uiColor: ui.accentRing)
        self.accentSecondary = Color(uiColor: ui.accentSecondary)
        self.accentSecondaryMuted = Color(uiColor: ui.accentSecondaryMuted)
        self.accentSecondaryWash = Color(uiColor: ui.accentSecondaryWash)
        self.statusSuccess = Color(uiColor: ui.statusSuccess)
        self.statusWarning = Color(uiColor: ui.statusWarning)
        self.statusDanger = Color(uiColor: ui.statusDanger)
        self.stateInfo = Color(uiColor: ui.stateInfo)
        self.priorityMax = Color(uiColor: ui.priorityMax)
        self.priorityHigh = Color(uiColor: ui.priorityHigh)
        self.priorityLow = Color(uiColor: ui.priorityLow)
        self.priorityNone = Color(uiColor: ui.priorityNone)
    }
}

@MainActor
public enum SwiftUITokens {
    private struct SwiftUIColorCacheKey: Hashable {
        let layoutClass: LayoutClass
        let traits: TokenTraitContext
    }

    private static var swiftUIColorCache: [SwiftUIColorCacheKey: SwiftUIColorTokens] = [:]

    public static var color: SwiftUIColorTokens {
        color(for: .phone, traits: .unspecified)
    }

    public static var spacing: SemanticSpacingTokens {
        ThemeStore.shared.tokens(for: .phone, traits: .unspecified).spacing
    }

    public static var corner: CornerTokens {
        ThemeStore.shared.tokens(for: .phone, traits: .unspecified).corner
    }

    public static var typography: SemanticTypographyTokens {
        ThemeStore.shared.tokens(for: .phone, traits: .unspecified).typography
    }

    public static var elevation: ElevationTokens {
        ThemeStore.shared.tokens(for: .phone, traits: .unspecified).elevation
    }

    public static func color(for layoutClass: LayoutClass) -> SwiftUIColorTokens {
        color(for: layoutClass, traits: .unspecified)
    }

    public static func color(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> SwiftUIColorTokens {
        let cacheKey = SwiftUIColorCacheKey(
            layoutClass: layoutClass,
            traits: traits
        )
        if let cached = swiftUIColorCache[cacheKey] {
            return cached
        }

        let resolved = SwiftUIColorTokens(
            ThemeStore.tokens(for: layoutClass, traits: traits).color
        )
        swiftUIColorCache[cacheKey] = resolved
        return resolved
    }

    public static func spacing(for layoutClass: LayoutClass) -> SemanticSpacingTokens {
        spacing(for: layoutClass, traits: .unspecified)
    }

    public static func spacing(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> SemanticSpacingTokens {
        ThemeStore.tokens(for: layoutClass, traits: traits).spacing
    }

    public static func corner(for layoutClass: LayoutClass) -> CornerTokens {
        corner(for: layoutClass, traits: .unspecified)
    }

    public static func corner(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> CornerTokens {
        ThemeStore.tokens(for: layoutClass, traits: traits).corner
    }

    public static func typography(for layoutClass: LayoutClass) -> SemanticTypographyTokens {
        typography(for: layoutClass, traits: .unspecified)
    }

    public static func typography(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> SemanticTypographyTokens {
        ThemeStore.tokens(for: layoutClass, traits: traits).typography
    }

    public static func elevation(for layoutClass: LayoutClass) -> ElevationTokens {
        elevation(for: layoutClass, traits: .unspecified)
    }

    public static func elevation(
        for layoutClass: LayoutClass,
        traits: TokenTraitContext
    ) -> ElevationTokens {
        ThemeStore.tokens(for: layoutClass, traits: traits).elevation
    }
}

private struct LayoutClassKey: EnvironmentKey {
    static let defaultValue: LayoutClass = .phone
}

private struct ScrollOptimizedRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

/// Set by the root; `nil` until it is.
private struct LifeBoardTokensKey: EnvironmentKey {
    static let defaultValue: Tokens? = nil
}

public extension EnvironmentValues {
    var lifeboardLayoutClass: LayoutClass {
        get { self[LayoutClassKey.self] }
        set { self[LayoutClassKey.self] = newValue }
    }

    /// The resolved token set for the current layout class.
    ///
    /// Views used to spell this `tokens`,
    /// which reached past the environment for a value the environment already
    /// had the inputs for. Reading it here means a view is themed by where it
    /// sits in the hierarchy rather than by a singleton, and a preview or test
    /// can theme a subtree by setting one value.
    ///
    /// The fallback resolves exactly what the singleton call resolved, from the
    /// same layout class, so a subtree with no provider behaves as before.
    var lifeboardTokens: Tokens {
        get {
            if let provided = self[LifeBoardTokensKey.self] { return provided }
            let layoutClass = lifeboardLayoutClass
            return MainActor.assumeIsolated { ThemeStore.tokens(for: layoutClass) }
        }
        set { self[LifeBoardTokensKey.self] = newValue }
    }
    var lifeboardScrollOptimizedRendering: Bool {
        get { self[ScrollOptimizedRenderingKey.self] }
        set { self[ScrollOptimizedRenderingKey.self] = newValue }
    }
}

private func lifeboardTokenTraits(
    colorScheme: ColorScheme,
    dynamicTypeSize: DynamicTypeSize,
    colorSchemeContrast: ColorSchemeContrast
) -> TokenTraitContext {
    TokenTraitContext(
        colorScheme: colorScheme == .dark ? .dark : .light,
        contentSizeCategory: dynamicTypeSize.uiContentSizeCategory,
        accessibilityContrast: colorSchemeContrast.uiAccessibilityContrast
    )
}

private extension UITraitCollection {
    var lifeboardTokenTraits: TokenTraitContext {
        TokenTraitContext(
            colorScheme: userInterfaceStyle,
            contentSizeCategory: preferredContentSizeCategory,
            accessibilityContrast: accessibilityContrast
        )
    }
}

@MainActor
public extension Color {
    static var lifeboard: SwiftUIColorTokens {
        SwiftUITokens.color
    }
}

public extension Color {
    static func lifeboard(_ role: ColorRole) -> Color {
        Color(uiColor: UIColor { traits in
            ThreadSafeTokenResolver.color(for: role, traits: traits.lifeboardTokenTraits)
        })
    }


    /// Semantic foreground resolved against the surface that actually sits
    /// beneath it. Feature views no longer need opacity guesses for readable
    /// dock, sidebar, toolbar, card, sheet, or image copy.
    static func lifeboard(
        _ role: LegibilityRole,
        on surface: SurfaceContext,
        imageLuminance: CGFloat? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            ThreadSafeTokenResolver.color(
                for: role,
                on: surface,
                imageLuminance: imageLuminance,
                traits: traits.lifeboardTokenTraits
            )
        })
    }
}

public enum SystemGlassVariant: Sendable {
    case regular
    case clear
}

/// The only feature-facing entry point for system Liquid Glass. It owns the
/// comfort fallback and OS fallback so callers choose a semantic variant and
/// shape without duplicating availability or accessibility policy.
public struct SystemGlassModifier<GlassShape: Shape>: ViewModifier {
    public let variant: SystemGlassVariant
    public let shape: GlassShape
    public let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public func body(content: Content) -> some View {
        if effectiveReduceTransparency {
            content.background(Color.lifeboard(.bgElevated), in: shape)
        } else if #available(iOS 26.0, *) {
            switch variant {
            case .regular where interactive:
                content.glassEffect(.regular.interactive(), in: shape)
            case .regular:
                content.glassEffect(.regular, in: shape)
            case .clear:
                content.glassEffect(.clear, in: shape)
            }
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency || ProcessInfo.processInfo.arguments.contains(
            "-LIFEBOARD_VISUAL_APPEARANCE=reduced-transparency"
        )
    }
}

// The premium / chrome / dense / analytics surface modifiers used to live here.
// They drew their own backgrounds — and `lifeboardPremiumSurface` drew real
// Liquid Glass by default, which `lifeboardChromeSurface` inherited, so 44 call
// sites had glass on ordinary content. They now resolve to clay and live in
// `LifeBoardUI/LegacySurfaceCompatibility.swift`, next to the primitive they
// delegate to. This layer defines tokens; it should not have been drawing
// surfaces.

public extension View {
    func lifeBoardSystemGlass<GlassShape: Shape>(
        _ variant: SystemGlassVariant = .regular,
        in shape: GlassShape,
        interactive: Bool = false
    ) -> some View {
        modifier(
            SystemGlassModifier(
                variant: variant,
                shape: shape,
                interactive: interactive
            )
        )
    }
}

@MainActor
public extension Font {
    /// Executes lifeboard.
    static func lifeboard(_ style: TypographyStyle) -> Font {
        Font(SwiftUITokens.typography.font(for: style))
    }
}

private struct FontModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    let style: TypographyStyle

    @MainActor
    @ViewBuilder
    func body(content: Content) -> some View {
        let traits = lifeboardTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let traitCollection = UITraitCollection { traits in
            traits.userInterfaceStyle = colorScheme == .dark ? .dark : .light
            traits.preferredContentSizeCategory = dynamicTypeSize.uiContentSizeCategory
            traits.accessibilityContrast = colorSchemeContrast.uiAccessibilityContrast
        }
        let font = Font(
            SwiftUITokens.typography(
                for: layoutClass,
                traits: traits
            ).dynamicFont(for: style, compatibleWith: traitCollection)
        )

        if legibilityWeight == .bold {
            content
                .font(font)
                .fontWeight(.semibold)
        } else {
            content.font(font)
        }
    }
}

@MainActor
public extension View {
    func lifeboardFont(_ style: TypographyStyle) -> some View {
        modifier(FontModifier(style: style))
    }
}

private struct ElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    let level: ElevationLevel
    let cornerRadius: CGFloat
    let includesBorder: Bool

    /// Executes body.
    @MainActor
    func body(content: Content) -> some View {
        let traits = lifeboardTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let style = SwiftUITokens.elevation(for: layoutClass, traits: traits).style(for: level)
        let trait = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let shadowColor = Color(uiColor: style.shadowColor.resolvedColor(with: trait))

        return content
            .overlay {
                if includesBorder && style.borderWidth > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(uiColor: style.borderColor.resolvedColor(with: trait)), lineWidth: style.borderWidth)
                }
            }
            .shadow(color: shadowColor.opacity(Double(style.shadowOpacity)), radius: style.shadowBlur / 2, x: 0, y: style.shadowOffsetY)
    }
}




public extension View {
    /// Executes lifeboardElevation.
    @MainActor
    func lifeboardElevation(
        _ level: ElevationLevel,
        cornerRadius: CGFloat = 0,
        includesBorder: Bool = true
    ) -> some View {
        modifier(ElevationModifier(level: level, cornerRadius: cornerRadius, includesBorder: includesBorder))
    }

    @MainActor




    /// Executes lifeboardLayoutClass.
    func lifeboardLayoutClass(_ layoutClass: LayoutClass) -> some View {
        environment(\.lifeboardLayoutClass, layoutClass)
    }

    /// Provides both the layout class and the token set resolved from it.
    ///
    /// Applied once at the root. Setting the tokens alongside the class is what
    /// lets views stop calling `ThemeStore.shared` — and lets a preview theme a
    /// subtree by overriding one value.
    @MainActor
    func lifeBoardTokenEnvironment(for layoutClass: LayoutClass) -> some View {
        environment(\.lifeboardLayoutClass, layoutClass)
            .environment(\.lifeboardTokens, ThemeStore.tokens(for: layoutClass))
    }

    func lifeboardScrollOptimizedRendering(_ enabled: Bool = true) -> some View {
        environment(\.lifeboardScrollOptimizedRendering, enabled)
    }

    /// Keeps dense content readable on iPad and Designed for iPad on Mac.
    func lifeboardReadableContent(
        maxWidth: CGFloat = 920,
        alignment: Alignment = .center
    ) -> some View {
        modifier(
            ReadableContentModifier(
                maxWidth: maxWidth,
                alignment: alignment
            )
        )
    }
}

private struct ReadableContentModifier: ViewModifier {
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    let maxWidth: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: layoutClass.isPad ? maxWidth : .infinity,
                alignment: .leading
            )
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

public struct TokenTextFieldStyle: TextFieldStyle {
    public var isFocused: Bool

    /// Initializes a new instance.
    public init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    /// Executes _body.
    public func _body(configuration: TextField<_Label>) -> some View {
        TextFieldBody(configuration: configuration, isFocused: isFocused)
    }
}

private struct TextFieldBody<Label: View>: View {
    nonisolated(unsafe) let configuration: TextField<Label>
    let isFocused: Bool

    nonisolated init(configuration: TextField<Label>, isFocused: Bool) {
        self.configuration = configuration
        self.isFocused = isFocused
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    var body: some View {
        let traits = lifeboardTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let tokens = ThemeStore.shared.tokens(for: layoutClass, traits: traits)

        return configuration
            .font(.lifeboard(.body))
            .foregroundColor(Color(uiColor: tokens.color.textPrimary))
            .tint(Color(uiColor: tokens.color.actionPrimary))
            .padding(.horizontal, tokens.spacing.s12)
            .frame(height: TextFieldTokens.singleLineHeight)
            .background(Color(uiColor: tokens.color.surfaceSecondary))
            .overlay(
                RoundedRectangle(cornerRadius: tokens.corner.r2)
                    .stroke(
                        Color(uiColor: isFocused ? tokens.color.actionFocus : tokens.color.borderDefault),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.corner.r2))
    }
}

public struct Chip: View {
    public let title: String
    public var isSelected: Bool
    public var selectedStyle: ChipSelectionStyle
    public var action: (() -> Void)?

    /// Initializes a new instance.
    public init(
        title: String,
        isSelected: Bool,
        selectedStyle: ChipSelectionStyle = .tinted,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.selectedStyle = selectedStyle
        self.action = action
    }

    public var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.lifeboard(.callout))
                .foregroundColor(textColor)
                .padding(.horizontal, SwiftUITokens.spacing.s12)
                .padding(.vertical, SwiftUITokens.spacing.s8)
                .frame(minWidth: 44, minHeight: ControlMetrics.chipMinHeight)
                .background(background)
                .overlay(border)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if !isSelected { return .lifeboard(.textSecondary) }
        return selectedStyle == .filled ? .lifeboard(.accentOnPrimary) : .lifeboard(.actionPrimary)
    }

    @ViewBuilder
    private var background: some View {
        if !isSelected {
            Color.lifeboard.surfaceSecondary
        } else if selectedStyle == .filled {
            Color.lifeboard(.accentPrimary).opacity(0.94)
        } else {
            Color.lifeboard(.accentWash)
        }
    }

    @ViewBuilder
    private var border: some View {
        if isSelected && selectedStyle == .filled {
            Capsule().stroke(Color.lifeboard(.accentRing).opacity(0.78), lineWidth: 1)
        } else if isSelected && selectedStyle == .tinted {
            Capsule().stroke(Color.lifeboard(.actionFocus), lineWidth: 1)
        } else {
            Capsule().stroke(Color.clear, lineWidth: 0)
        }
    }
}

public struct SurfaceCard<Content: View>: View {
    public var active: Bool
    public var elevated: Bool
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    /// Initializes a new instance.
    public init(active: Bool = false, elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.active = active
        self.elevated = elevated
        self.content = content()
    }

    public var body: some View {
        let traits = lifeboardTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let tokens = ThemeStore.shared.tokens(for: layoutClass, traits: traits)
        return content
            .padding(tokens.spacing.cardPadding)
            .background(Color(uiColor: tokens.color.surfacePrimary))
            .overlay(
                RoundedRectangle(cornerRadius: tokens.corner.r3)
                    .stroke(
                        Color(uiColor: active ? tokens.color.borderStrong : tokens.color.borderDefault),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.corner.r3))
            .lifeboardElevation(elevated ? .e2 : .e1, cornerRadius: tokens.corner.r3, includesBorder: false)
    }
}

private extension DynamicTypeSize {
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default:
            return .large
        }
    }
}

private extension ColorSchemeContrast {
    var uiAccessibilityContrast: UIAccessibilityContrast {
        switch self {
        case .standard:
            return .normal
        case .increased:
            return .high
        @unknown default:
            return .normal
        }
    }
}

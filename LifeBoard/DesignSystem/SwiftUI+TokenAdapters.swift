@preconcurrency import SwiftUI
import UIKit

public struct LifeBoardSwiftUIColorTokens {
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
    public init(_ ui: LifeBoardColorTokens) {
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
public enum LifeBoardSwiftUITokens {
    private struct SwiftUIColorCacheKey: Hashable {
        let layoutClass: LifeBoardLayoutClass
        let traits: LifeBoardTokenTraitContext
    }

    private static var swiftUIColorCache: [SwiftUIColorCacheKey: LifeBoardSwiftUIColorTokens] = [:]

    public static var color: LifeBoardSwiftUIColorTokens {
        color(for: .phone, traits: .unspecified)
    }

    public static var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified).spacing
    }

    public static var corner: LifeBoardCornerTokens {
        LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified).corner
    }

    public static var typography: LifeBoardTypographyTokens {
        LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified).typography
    }

    public static var elevation: LifeBoardElevationTokens {
        LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified).elevation
    }

    public static func color(for layoutClass: LifeBoardLayoutClass) -> LifeBoardSwiftUIColorTokens {
        color(for: layoutClass, traits: .unspecified)
    }

    public static func color(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardSwiftUIColorTokens {
        let cacheKey = SwiftUIColorCacheKey(
            layoutClass: layoutClass,
            traits: traits
        )
        if let cached = swiftUIColorCache[cacheKey] {
            return cached
        }

        let resolved = LifeBoardSwiftUIColorTokens(
            LifeBoardThemeManager.tokens(for: layoutClass, traits: traits).color
        )
        swiftUIColorCache[cacheKey] = resolved
        return resolved
    }

    public static func spacing(for layoutClass: LifeBoardLayoutClass) -> LifeBoardSpacingTokens {
        spacing(for: layoutClass, traits: .unspecified)
    }

    public static func spacing(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardSpacingTokens {
        LifeBoardThemeManager.tokens(for: layoutClass, traits: traits).spacing
    }

    public static func corner(for layoutClass: LifeBoardLayoutClass) -> LifeBoardCornerTokens {
        corner(for: layoutClass, traits: .unspecified)
    }

    public static func corner(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardCornerTokens {
        LifeBoardThemeManager.tokens(for: layoutClass, traits: traits).corner
    }

    public static func typography(for layoutClass: LifeBoardLayoutClass) -> LifeBoardTypographyTokens {
        typography(for: layoutClass, traits: .unspecified)
    }

    public static func typography(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardTypographyTokens {
        LifeBoardThemeManager.tokens(for: layoutClass, traits: traits).typography
    }

    public static func elevation(for layoutClass: LifeBoardLayoutClass) -> LifeBoardElevationTokens {
        elevation(for: layoutClass, traits: .unspecified)
    }

    public static func elevation(
        for layoutClass: LifeBoardLayoutClass,
        traits: LifeBoardTokenTraitContext
    ) -> LifeBoardElevationTokens {
        LifeBoardThemeManager.tokens(for: layoutClass, traits: traits).elevation
    }
}

private struct LifeBoardLayoutClassKey: EnvironmentKey {
    static let defaultValue: LifeBoardLayoutClass = .phone
}

public extension EnvironmentValues {
    var lifeboardLayoutClass: LifeBoardLayoutClass {
        get { self[LifeBoardLayoutClassKey.self] }
        set { self[LifeBoardLayoutClassKey.self] = newValue }
    }
}

private func lifeboardTokenTraits(
    colorScheme: ColorScheme,
    dynamicTypeSize: DynamicTypeSize,
    colorSchemeContrast: ColorSchemeContrast
) -> LifeBoardTokenTraitContext {
    LifeBoardTokenTraitContext(
        colorScheme: colorScheme == .dark ? .dark : .light,
        contentSizeCategory: dynamicTypeSize.uiContentSizeCategory,
        accessibilityContrast: colorSchemeContrast.uiAccessibilityContrast
    )
}

private extension UITraitCollection {
    var lifeboardTokenTraits: LifeBoardTokenTraitContext {
        LifeBoardTokenTraitContext(
            colorScheme: userInterfaceStyle,
            contentSizeCategory: preferredContentSizeCategory,
            accessibilityContrast: accessibilityContrast
        )
    }
}

@MainActor
public extension Color {
    static var lifeboard: LifeBoardSwiftUIColorTokens {
        LifeBoardSwiftUITokens.color
    }

    /// Executes lifeboard.
    static func lifeboard(_ role: LifeBoardColorRole) -> Color {
        Color(uiColor: UIColor { traits in
            LifeBoardThemeManager.shared.tokens(for: .phone, traits: traits.lifeboardTokenTraits).color.color(for: role)
        })
    }
}

@MainActor
public extension Font {
    /// Executes lifeboard.
    static func lifeboard(_ style: LifeBoardTextStyle) -> Font {
        Font(LifeBoardSwiftUITokens.typography.font(for: style))
    }
}

private struct LifeBoardFontModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    let style: LifeBoardTextStyle

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
            LifeBoardSwiftUITokens.typography(
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
    func lifeboardFont(_ style: LifeBoardTextStyle) -> some View {
        modifier(LifeBoardFontModifier(style: style))
    }
}

private struct LifeBoardElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    let level: LifeBoardElevationLevel
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
        let style = LifeBoardSwiftUITokens.elevation(for: layoutClass, traits: traits).style(for: level)
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

private struct LifeBoardDenseSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)
            )
    }
}

private struct LifeBoardPremiumSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let accentColor: Color
    let level: LifeBoardElevationLevel
    let useNativeGlass: Bool

    @ViewBuilder
    private var fallbackSurface: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(
                LinearGradient(
                    colors: [
                        fillColor.opacity(0.98),
                        fillColor.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.14),
                                .clear,
                                fillColor.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                shape
                    .stroke(strokeColor.opacity(0.88), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.34),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(16, cornerRadius * 0.9))
                    .padding(.horizontal, cornerRadius * 0.85)
                    .blur(radius: 1.5)
                    .opacity(0.8)
            }
    }

    @ViewBuilder
    private var nativeGlassSurface: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *), useNativeGlass {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: shape)
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    fillColor.opacity(0.16),
                                    accentColor.opacity(0.08),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    shape
                        .stroke(strokeColor.opacity(0.72), lineWidth: 1)
                )
        } else {
            fallbackSurface
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(nativeGlassSurface)
            .lifeboardElevation(level, cornerRadius: cornerRadius, includesBorder: false)
    }
}

private struct LifeBoardAnalyticsSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillColor: Color
    let strokeColor: Color
    let accentColor: Color
    let level: LifeBoardElevationLevel

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background(
                shape
                    .fill(fillColor)
                    .overlay(
                        shape
                            .stroke(strokeColor.opacity(0.7), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Capsule(style: .continuous)
                            .fill(accentColor.opacity(0.08))
                            .frame(width: max(22, cornerRadius * 1.4), height: 8)
                            .padding(.top, 10)
                            .padding(.leading, 12)
                    }
            )
            .lifeboardElevation(level, cornerRadius: cornerRadius, includesBorder: false)
    }
}

public extension View {
    /// Executes lifeboardElevation.
    @MainActor
    func lifeboardElevation(
        _ level: LifeBoardElevationLevel,
        cornerRadius: CGFloat = 0,
        includesBorder: Bool = true
    ) -> some View {
        modifier(LifeBoardElevationModifier(level: level, cornerRadius: cornerRadius, includesBorder: includesBorder))
    }

    @MainActor
    func lifeboardDenseSurface(
        cornerRadius: CGFloat,
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        lineWidth: CGFloat = 1
    ) -> some View {
        let resolvedFillColor = fillColor ?? Color.lifeboard.surfacePrimary
        let resolvedStrokeColor = strokeColor ?? Color.lifeboard.strokeHairline
        return modifier(
            LifeBoardDenseSurfaceModifier(
                cornerRadius: cornerRadius,
                fillColor: resolvedFillColor,
                strokeColor: resolvedStrokeColor,
                lineWidth: lineWidth
            )
        )
    }

    @MainActor
    func lifeboardPremiumSurface(
        cornerRadius: CGFloat,
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        accentColor: Color? = nil,
        level: LifeBoardElevationLevel = .e2,
        useNativeGlass: Bool = true
    ) -> some View {
        modifier(
            LifeBoardPremiumSurfaceModifier(
                cornerRadius: cornerRadius,
                fillColor: fillColor ?? Color.lifeboard.surfacePrimary,
                strokeColor: strokeColor ?? Color.lifeboard.strokeHairline,
                accentColor: accentColor ?? Color.lifeboard.accentSecondary,
                level: level,
                useNativeGlass: useNativeGlass
            )
        )
    }

    @MainActor
    func lifeboardAnalyticsSurface(
        cornerRadius: CGFloat,
        fillColor: Color? = nil,
        strokeColor: Color? = nil,
        accentColor: Color? = nil,
        level: LifeBoardElevationLevel = .e1
    ) -> some View {
        modifier(
            LifeBoardAnalyticsSurfaceModifier(
                cornerRadius: cornerRadius,
                fillColor: fillColor ?? Color.lifeboard.surfacePrimary,
                strokeColor: strokeColor ?? Color.lifeboard.strokeHairline,
                accentColor: accentColor ?? Color.lifeboard.accentSecondary,
                level: level
            )
        )
    }

    @MainActor
    func lifeboardChromeSurface(
        cornerRadius: CGFloat,
        accentColor: Color? = nil,
        level: LifeBoardElevationLevel = .e1,
        useNativeGlass: Bool = true
    ) -> some View {
        modifier(
            LifeBoardPremiumSurfaceModifier(
                cornerRadius: cornerRadius,
                fillColor: Color.lifeboard.surfaceSecondary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.78),
                accentColor: accentColor ?? Color.lifeboard.accentSecondary,
                level: level,
                useNativeGlass: useNativeGlass
            )
        )
    }

    /// Executes lifeboardLayoutClass.
    func lifeboardLayoutClass(_ layoutClass: LifeBoardLayoutClass) -> some View {
        environment(\.lifeboardLayoutClass, layoutClass)
    }

    /// Keeps dense content readable on iPad and Designed for iPad on Mac.
    func lifeboardReadableContent(
        maxWidth: CGFloat = 920,
        alignment: Alignment = .center
    ) -> some View {
        modifier(
            LifeBoardReadableContentModifier(
                maxWidth: maxWidth,
                alignment: alignment
            )
        )
    }
}

private struct LifeBoardReadableContentModifier: ViewModifier {
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

public struct LifeBoardTextFieldStyle: TextFieldStyle {
    public var isFocused: Bool

    /// Initializes a new instance.
    public init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    /// Executes _body.
    public func _body(configuration: TextField<_Label>) -> some View {
        LifeBoardTextFieldBody(configuration: configuration, isFocused: isFocused)
    }
}

private struct LifeBoardTextFieldBody<Label: View>: View {
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

    var body: some View {
        let traits = lifeboardTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let tokens = LifeBoardThemeManager.shared.tokens(for: layoutClass, traits: traits)

        return configuration
            .font(.lifeboard(.body))
            .foregroundColor(Color(uiColor: tokens.color.textPrimary))
            .tint(Color(uiColor: tokens.color.actionPrimary))
            .padding(.horizontal, tokens.spacing.s12)
            .frame(height: LifeBoardTextFieldTokens.singleLineHeight)
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

public struct LifeBoardChip: View {
    public let title: String
    public var isSelected: Bool
    public var selectedStyle: LifeBoardChipSelectionStyle
    public var action: (() -> Void)?

    /// Initializes a new instance.
    public init(
        title: String,
        isSelected: Bool,
        selectedStyle: LifeBoardChipSelectionStyle = .tinted,
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
                .padding(.horizontal, LifeBoardSwiftUITokens.spacing.s12)
                .padding(.vertical, LifeBoardSwiftUITokens.spacing.s8)
                .frame(minWidth: 44, minHeight: LifeBoardSettingsMetrics.chipMinHeight)
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

public struct LifeBoardCard<Content: View>: View {
    public var active: Bool
    public var elevated: Bool
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.lifeboardLayoutClass) private var layoutClass

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
        let tokens = LifeBoardThemeManager.shared.tokens(for: layoutClass, traits: traits)
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

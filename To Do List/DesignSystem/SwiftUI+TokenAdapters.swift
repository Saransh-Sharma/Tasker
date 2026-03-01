import SwiftUI
import UIKit

public struct TaskerSwiftUIColorTokens {
    public let bgCanvas: Color
    public let bgElevated: Color
    public let surfacePrimary: Color
    public let surfaceSecondary: Color
    public let surfaceTertiary: Color
    public let divider: Color
    public let strokeHairline: Color
    public let strokeStrong: Color

    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let textQuaternary: Color
    public let textInverse: Color

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

    public let priorityMax: Color
    public let priorityHigh: Color
    public let priorityLow: Color
    public let priorityNone: Color

    /// Initializes a new instance.
    public init(_ ui: TaskerColorTokens) {
        self.bgCanvas = Color(uiColor: ui.bgCanvas)
        self.bgElevated = Color(uiColor: ui.bgElevated)
        self.surfacePrimary = Color(uiColor: ui.surfacePrimary)
        self.surfaceSecondary = Color(uiColor: ui.surfaceSecondary)
        self.surfaceTertiary = Color(uiColor: ui.surfaceTertiary)
        self.divider = Color(uiColor: ui.divider)
        self.strokeHairline = Color(uiColor: ui.strokeHairline)
        self.strokeStrong = Color(uiColor: ui.strokeStrong)
        self.textPrimary = Color(uiColor: ui.textPrimary)
        self.textSecondary = Color(uiColor: ui.textSecondary)
        self.textTertiary = Color(uiColor: ui.textTertiary)
        self.textQuaternary = Color(uiColor: ui.textQuaternary)
        self.textInverse = Color(uiColor: ui.textInverse)
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
        self.priorityMax = Color(uiColor: ui.priorityMax)
        self.priorityHigh = Color(uiColor: ui.priorityHigh)
        self.priorityLow = Color(uiColor: ui.priorityLow)
        self.priorityNone = Color(uiColor: ui.priorityNone)
    }
}

@MainActor
public enum TaskerSwiftUITokens {
    private struct SwiftUIColorCacheKey: Hashable {
        let themeIndex: Int
        let layoutClass: TaskerLayoutClass
        let traits: TaskerTokenTraitContext
    }

    private static var swiftUIColorCache: [SwiftUIColorCacheKey: TaskerSwiftUIColorTokens] = [:]

    public static var color: TaskerSwiftUIColorTokens {
        color(for: .phone, traits: .unspecified)
    }

    public static var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: .phone, traits: .unspecified).spacing
    }

    public static var corner: TaskerCornerTokens {
        TaskerThemeManager.shared.tokens(for: .phone, traits: .unspecified).corner
    }

    public static var typography: TaskerTypographyTokens {
        TaskerThemeManager.shared.tokens(for: .phone, traits: .unspecified).typography
    }

    public static var elevation: TaskerElevationTokens {
        TaskerThemeManager.shared.tokens(for: .phone, traits: .unspecified).elevation
    }

    public static func color(for layoutClass: TaskerLayoutClass) -> TaskerSwiftUIColorTokens {
        color(for: layoutClass, traits: .unspecified)
    }

    public static func color(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerSwiftUIColorTokens {
        let cacheKey = SwiftUIColorCacheKey(
            themeIndex: TaskerThemeManager.shared.selectedThemeIndex,
            layoutClass: layoutClass,
            traits: traits
        )
        if let cached = swiftUIColorCache[cacheKey] {
            return cached
        }

        let resolved = TaskerSwiftUIColorTokens(
            TaskerThemeManager.tokens(for: layoutClass, traits: traits).color
        )
        swiftUIColorCache[cacheKey] = resolved
        return resolved
    }

    public static func spacing(for layoutClass: TaskerLayoutClass) -> TaskerSpacingTokens {
        spacing(for: layoutClass, traits: .unspecified)
    }

    public static func spacing(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerSpacingTokens {
        TaskerThemeManager.tokens(for: layoutClass, traits: traits).spacing
    }

    public static func corner(for layoutClass: TaskerLayoutClass) -> TaskerCornerTokens {
        corner(for: layoutClass, traits: .unspecified)
    }

    public static func corner(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerCornerTokens {
        TaskerThemeManager.tokens(for: layoutClass, traits: traits).corner
    }

    public static func typography(for layoutClass: TaskerLayoutClass) -> TaskerTypographyTokens {
        typography(for: layoutClass, traits: .unspecified)
    }

    public static func typography(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerTypographyTokens {
        TaskerThemeManager.tokens(for: layoutClass, traits: traits).typography
    }

    public static func elevation(for layoutClass: TaskerLayoutClass) -> TaskerElevationTokens {
        elevation(for: layoutClass, traits: .unspecified)
    }

    public static func elevation(
        for layoutClass: TaskerLayoutClass,
        traits: TaskerTokenTraitContext
    ) -> TaskerElevationTokens {
        TaskerThemeManager.tokens(for: layoutClass, traits: traits).elevation
    }
}

private struct TaskerLayoutClassKey: EnvironmentKey {
    static let defaultValue: TaskerLayoutClass = .phone
}

public extension EnvironmentValues {
    var taskerLayoutClass: TaskerLayoutClass {
        get { self[TaskerLayoutClassKey.self] }
        set { self[TaskerLayoutClassKey.self] = newValue }
    }
}

private func taskerTokenTraits(
    colorScheme: ColorScheme,
    dynamicTypeSize: DynamicTypeSize,
    colorSchemeContrast: ColorSchemeContrast
) -> TaskerTokenTraitContext {
    TaskerTokenTraitContext(
        colorScheme: colorScheme == .dark ? .dark : .light,
        contentSizeCategory: dynamicTypeSize.uiContentSizeCategory,
        accessibilityContrast: colorSchemeContrast.uiAccessibilityContrast
    )
}

private extension UITraitCollection {
    var taskerTokenTraits: TaskerTokenTraitContext {
        TaskerTokenTraitContext(
            colorScheme: userInterfaceStyle,
            contentSizeCategory: preferredContentSizeCategory,
            accessibilityContrast: accessibilityContrast
        )
    }
}

@MainActor
public extension Color {
    static var tasker: TaskerSwiftUIColorTokens {
        TaskerSwiftUITokens.color
    }

    /// Executes tasker.
    static func tasker(_ role: TaskerColorRole) -> Color {
        Color(uiColor: UIColor { traits in
            TaskerThemeManager.shared.tokens(for: .phone, traits: traits.taskerTokenTraits).color.color(for: role)
        })
    }
}

@MainActor
public extension Font {
    /// Executes tasker.
    static func tasker(_ style: TaskerTextStyle) -> Font {
        Font(TaskerSwiftUITokens.typography.font(for: style))
    }
}

private struct TaskerElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.taskerLayoutClass) private var layoutClass
    let level: TaskerElevationLevel
    let cornerRadius: CGFloat
    let includesBorder: Bool

    /// Executes body.
    @MainActor
    func body(content: Content) -> some View {
        let traits = taskerTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let style = TaskerSwiftUITokens.elevation(for: layoutClass, traits: traits).style(for: level)
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
    /// Executes taskerElevation.
    @MainActor
    func taskerElevation(
        _ level: TaskerElevationLevel,
        cornerRadius: CGFloat = 0,
        includesBorder: Bool = true
    ) -> some View {
        modifier(TaskerElevationModifier(level: level, cornerRadius: cornerRadius, includesBorder: includesBorder))
    }

    /// Executes taskerLayoutClass.
    func taskerLayoutClass(_ layoutClass: TaskerLayoutClass) -> some View {
        environment(\.taskerLayoutClass, layoutClass)
    }
}

public struct TaskerTextFieldStyle: TextFieldStyle {
    public var isFocused: Bool

    /// Initializes a new instance.
    public init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    /// Executes _body.
    public func _body(configuration: TextField<_Label>) -> some View {
        TaskerTextFieldBody(configuration: configuration, isFocused: isFocused)
    }
}

private struct TaskerTextFieldBody<Label: View>: View {
    let configuration: TextField<Label>
    let isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.taskerLayoutClass) private var layoutClass

    var body: some View {
        let traits = taskerTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let tokens = TaskerThemeManager.shared.tokens(for: layoutClass, traits: traits)

        return configuration
            .font(.tasker(.body))
            .foregroundColor(.tasker(.textPrimary))
            .tint(.tasker(.accentPrimary))
            .padding(.horizontal, tokens.spacing.s12)
            .frame(height: TaskerTextFieldTokens.singleLineHeight)
            .background(Color.tasker.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: tokens.corner.r2)
                    .stroke(
                        isFocused ? Color.tasker.accentRing : Color.tasker.divider,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.corner.r2))
    }
}

public struct TaskerChip: View {
    public let title: String
    public var isSelected: Bool
    public var selectedStyle: TaskerChipSelectionStyle
    public var action: (() -> Void)?

    /// Initializes a new instance.
    public init(
        title: String,
        isSelected: Bool,
        selectedStyle: TaskerChipSelectionStyle = .tinted,
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
                .font(.tasker(.callout))
                .foregroundColor(textColor)
                .padding(.horizontal, TaskerSwiftUITokens.spacing.s12)
                .padding(.vertical, TaskerSwiftUITokens.spacing.s8)
                .frame(minWidth: 44, minHeight: 44)
                .background(background)
                .overlay(border)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if !isSelected { return .tasker(.textSecondary) }
        return selectedStyle == .filled ? .tasker(.accentOnPrimary) : .tasker(.accentPrimary)
    }

    @ViewBuilder
    private var background: some View {
        if !isSelected {
            Color.tasker.surfaceSecondary
        } else if selectedStyle == .filled {
            Color.tasker(.chipSelectedBackground)
        } else {
            Color.tasker.accentMuted
        }
    }

    @ViewBuilder
    private var border: some View {
        if isSelected && selectedStyle == .tinted {
            Capsule().stroke(Color.tasker.accentRing, lineWidth: 1)
        } else {
            Capsule().stroke(Color.clear, lineWidth: 0)
        }
    }
}

public struct TaskerCard<Content: View>: View {
    public var active: Bool
    public var elevated: Bool
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.taskerLayoutClass) private var layoutClass

    /// Initializes a new instance.
    public init(active: Bool = false, elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.active = active
        self.elevated = elevated
        self.content = content()
    }

    public var body: some View {
        let traits = taskerTokenTraits(
            colorScheme: colorScheme,
            dynamicTypeSize: dynamicTypeSize,
            colorSchemeContrast: colorSchemeContrast
        )
        let tokens = TaskerThemeManager.shared.tokens(for: layoutClass, traits: traits)
        return content
            .padding(tokens.spacing.cardPadding)
            .background(Color.tasker.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: tokens.corner.r3)
                    .stroke(active ? Color.tasker.strokeStrong : Color.tasker.strokeHairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: tokens.corner.r3))
            .taskerElevation(elevated ? .e2 : .e1, cornerRadius: tokens.corner.r3, includesBorder: false)
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

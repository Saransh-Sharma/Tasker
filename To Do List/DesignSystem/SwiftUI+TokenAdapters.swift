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
    public static var color: TaskerSwiftUIColorTokens {
        TaskerSwiftUIColorTokens(TaskerThemeManager.shared.currentTheme.tokens.color)
    }

    public static var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.currentTheme.tokens.spacing
    }

    public static var corner: TaskerCornerTokens {
        TaskerThemeManager.shared.currentTheme.tokens.corner
    }

    public static var typography: TaskerTypographyTokens {
        TaskerThemeManager.shared.currentTheme.tokens.typography
    }

    public static var elevation: TaskerElevationTokens {
        TaskerThemeManager.shared.currentTheme.tokens.elevation
    }
}

@MainActor
public extension Color {
    static var tasker: TaskerSwiftUIColorTokens {
        TaskerSwiftUITokens.color
    }

    static func tasker(_ role: TaskerColorRole) -> Color {
        Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.color(for: role))
    }
}

@MainActor
public extension Font {
    static func tasker(_ style: TaskerTextStyle) -> Font {
        Font(TaskerSwiftUITokens.typography.font(for: style))
    }
}

private struct TaskerElevationModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let level: TaskerElevationLevel
    let cornerRadius: CGFloat
    let includesBorder: Bool

    @MainActor
    func body(content: Content) -> some View {
        let style = TaskerSwiftUITokens.elevation.style(for: level)
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
    @MainActor
    func taskerElevation(
        _ level: TaskerElevationLevel,
        cornerRadius: CGFloat = 0,
        includesBorder: Bool = true
    ) -> some View {
        modifier(TaskerElevationModifier(level: level, cornerRadius: cornerRadius, includesBorder: includesBorder))
    }
}

public struct TaskerTextFieldStyle: TextFieldStyle {
    public var isFocused: Bool

    public init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }

    public func _body(configuration: TextField<_Label>) -> some View {
        MainActor.assumeIsolated {
            taskerTextFieldBody(configuration: configuration, isFocused: isFocused)
        }
    }
}

@MainActor
private func taskerTextFieldBody<Label: View>(
    configuration: TextField<Label>,
    isFocused: Bool
) -> some View {
    let tokens = TaskerThemeManager.shared.currentTheme.tokens
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

public struct TaskerChip: View {
    public let title: String
    public var isSelected: Bool
    public var selectedStyle: TaskerChipSelectionStyle
    public var action: (() -> Void)?

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

    public init(active: Bool = false, elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.active = active
        self.elevated = elevated
        self.content = content()
    }

    public var body: some View {
        let tokens = TaskerThemeManager.shared.currentTheme.tokens
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

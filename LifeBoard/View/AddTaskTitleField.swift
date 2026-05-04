//
//  AddTaskTitleField.swift
//  LifeBoard
//
//  Primary name input — auto-focus, keyboard-first, submit on Done.
//

import SwiftUI

struct AddTaskTitleField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let iconSystemName: String?
    let iconAccessibilityLabel: String?
    let onIconTap: (() -> Void)?
    let placeholder: LocalizedStringKey
    let helperText: LocalizedStringKey
    let onSubmit: () -> Void

    init(
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        iconSystemName: String? = nil,
        iconAccessibilityLabel: String? = nil,
        onIconTap: (() -> Void)? = nil,
        placeholder: LocalizedStringKey,
        helperText: LocalizedStringKey,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        _isFocused = isFocused
        self.iconSystemName = iconSystemName
        self.iconAccessibilityLabel = iconAccessibilityLabel
        self.onIconTap = onIconTap
        self.placeholder = placeholder
        self.helperText = helperText
        self.onSubmit = onSubmit
    }

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Title")
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)

            HStack(spacing: spacing.s12) {
                if let iconSystemName, let onIconTap {
                    Button("Change task icon", systemImage: iconSystemName, action: onIconTap)
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isFocused ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("addTask.iconButton")
                        .accessibilityLabel("Task icon")
                        .accessibilityValue(iconAccessibilityLabel ?? "")

                    Rectangle()
                        .fill(Color.lifeboard.strokeHairline)
                        .frame(width: 1, height: 22)
                        .accessibilityHidden(true)
                }

                TextField(placeholder, text: $text)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
                    .accessibilityIdentifier("addTask.titleField")
            }
            .padding(.horizontal, spacing.s16)
            .frame(height: spacing.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(isFocused ? Color.lifeboard.surfacePrimary : Color.lifeboard.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2)
                    .stroke(
                        isFocused ? Color.lifeboard.accentRing : Color.lifeboard.strokeHairline,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: corner.r2))
            .animation(LifeBoardAnimation.quick, value: isFocused)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("addTask.titleFieldContainer")

            Text(helperText)
                .font(.lifeboard(.meta))
                .foregroundStyle(isFocused ? Color.lifeboard.textSecondary : Color.lifeboard.textTertiary)
                .padding(.horizontal, spacing.s4)
                .animation(LifeBoardAnimation.quick, value: isFocused)
        }
    }
}

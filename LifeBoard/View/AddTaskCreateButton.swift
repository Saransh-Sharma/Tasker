//
//  AddTaskCreateButton.swift
//  LifeBoard
//
//  Primary CTA with loading state, success flash, and "Add Another" secondary action.
//

import SwiftUI

struct AddTaskCreateButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let successFlash: Bool
    let showAddAnother: Bool
    let buttonTitle: String
    let onCreateAction: () -> Void
    let onAddAnotherAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: spacing.s8) {
            Button {
                if isEnabled && !isLoading {
                    LifeBoardFeedback.light()
                    onCreateAction()
                }
            } label: {
                HStack(spacing: spacing.s8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.lifeboard.accentOnPrimary))
                            .scaleEffect(0.8)
                    } else if successFlash {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                    }

                    Text(isLoading ? "Creating..." : successFlash ? "Added!" : buttonTitle)
                        .font(.lifeboard(.button))
                        .contentTransition(.opacity)
                }
                .foregroundColor(isEnabled ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textQuaternary)
                .frame(maxWidth: .infinity)
                .frame(height: spacing.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .fill(successFlash
                              ? Color.lifeboard.statusSuccess
                              : isEnabled
                                ? Color.lifeboard.accentPrimary
                                : Color.lifeboard.surfaceSecondary
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(
                            successFlash ? Color.lifeboard.statusSuccess.opacity(0.28) : Color.lifeboard.strokeHairline.opacity(isEnabled ? 0 : 0.8),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("addTask.createButton")
            .disabled(!isEnabled || isLoading)
            .animation(LifeBoardAnimation.quick, value: isEnabled)
            .animation(reduceMotion ? nil : LifeBoardAnimation.ctaConfirmation, value: successFlash)
            .animation(LifeBoardAnimation.quick, value: isLoading)

            if showAddAnother {
                Button {
                    LifeBoardFeedback.selection()
                    onAddAnotherAction()
                } label: {
                    Text("Add Another")
                        .font(.lifeboard(.callout))
                        .foregroundColor(Color.lifeboard.accentPrimary)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(LifeBoardAnimation.snappy, value: showAddAnother)
    }
}

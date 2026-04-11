//
//  AddTaskCreateButton.swift
//  Tasker
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

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: spacing.s8) {
            Button {
                if isEnabled && !isLoading {
                    TaskerFeedback.light()
                    onCreateAction()
                }
            } label: {
                HStack(spacing: spacing.s8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.tasker.accentOnPrimary))
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
                        .font(.tasker(.button))
                        .contentTransition(.opacity)
                }
                .foregroundColor(isEnabled ? Color.tasker.accentOnPrimary : Color.tasker.textQuaternary)
                .frame(maxWidth: .infinity)
                .frame(height: spacing.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .fill(successFlash
                              ? Color.tasker.statusSuccess
                              : isEnabled
                                ? Color.tasker.accentPrimary
                                : Color.tasker.surfaceSecondary
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(
                            successFlash ? Color.tasker.statusSuccess.opacity(0.28) : Color.tasker.strokeHairline.opacity(isEnabled ? 0 : 0.8),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .disabled(!isEnabled || isLoading)
            .animation(TaskerAnimation.quick, value: isEnabled)
            .animation(reduceMotion ? nil : TaskerAnimation.ctaConfirmation, value: successFlash)
            .animation(TaskerAnimation.quick, value: isLoading)
            .accessibilityIdentifier("addTask.createButton")

            if showAddAnother {
                Button {
                    TaskerFeedback.selection()
                    onAddAnotherAction()
                } label: {
                    Text("Add Another")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.accentPrimary)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(TaskerAnimation.snappy, value: showAddAnother)
    }
}

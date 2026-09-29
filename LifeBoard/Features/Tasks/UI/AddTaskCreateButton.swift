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
    /// ⌘Return submits, for a sheet whose bar has no Done of its own.
    var submitsWithCommandReturn: Bool = false
    let onCreateAction: () -> Void
    let onAddAnotherAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    private var corner: CornerTokens { ThemeStore.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: spacing.s8) {
            Button {
                if isEnabled && !isLoading {
                    // A press; the commit haptic follows the save itself.
                    Haptic.pick.play()
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
                            .lifeboardFont(.bodyEmphasis)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .lifeboardFont(.bodyEmphasis)
                    }

                    Text(isLoading ? "Adding…" : successFlash ? "Added" : buttonTitle)
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
                .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                .lbAnimatedSheen(isEnabled: isEnabled && isLoading == false)
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("addTask.createButton")
            .keyboardShortcut(submitsWithCommandReturn ? KeyboardShortcut(.return, modifiers: .command) : nil)
            .disabled(!isEnabled || isLoading)
            .animation(MotionProfile.press.animation(reduceMotion: reduceMotion), value: isEnabled)
            .animation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion), value: successFlash)
            .animation(MotionProfile.press.animation(reduceMotion: reduceMotion), value: isLoading)

            if showAddAnother {
                Button {
                    Haptic.pick.play()
                    onAddAnotherAction()
                } label: {
                    Text("Add another")
                        .font(.lifeboard(.callout))
                        .foregroundColor(Color.lifeboard.accentPrimary)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion), value: showAddAnother)
    }
}

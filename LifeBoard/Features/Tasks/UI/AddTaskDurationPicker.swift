//
//  AddTaskDurationPicker.swift
//  LifeBoard
//
//  Estimated duration picker with preset pills and custom option.
//

import SwiftUI

// MARK: - Duration Picker

struct AddTaskDurationPicker: View {
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var duration: TimeInterval?

    @State private var showCustom = false
    @State private var customMinutes: String = ""

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    private var corner: CornerTokens { ThemeStore.shared.currentTheme.tokens.corner }

    private let presets: [(label: String, seconds: TimeInterval)] = [15, 30, 60, 120, 240].map {
        (LifeBoardDuration.text(minutes: $0), TimeInterval($0 * 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Estimate")
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    // None option
                    AddTaskMetadataChip(
                        icon: "clock",
                        text: "None",
                        isActive: duration == nil && !showCustom
                    ) {
                        withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                            duration = nil
                            showCustom = false
                        }
                    }

                    // Preset pills
                    ForEach(presets, id: \.seconds) { preset in
                        AddTaskMetadataChip(
                            icon: "clock",
                            text: preset.label,
                            isActive: duration == preset.seconds
                        ) {
                            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                                duration = preset.seconds
                                showCustom = false
                            }
                        }
                    }

                    // Custom button
                    AddTaskMetadataChip(
                        icon: "pencil",
                        text: showCustom ? (Int(customMinutes).map { LifeBoardDuration.text(minutes: $0) } ?? "Custom") : "Custom",
                        isActive: showCustom
                    ) {
                        withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                            showCustom.toggle()
                        }
                    }
                }
            }

            // Custom input
            if showCustom {
                HStack(spacing: spacing.s8) {
                    TextField("Minutes", text: $customMinutes, prompt: Text("Minutes").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .font(.lifeboard(.callout))
                        .padKeyboard(.numberPad)
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .padding(.horizontal, spacing.s12)
                        .padding(.vertical, spacing.s8)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .fill(Color.lifeboard.surfaceTertiary)
                        )
                        .frame(width: 100)

                    Text("minutes")
                        .font(.lifeboard(.callout))
                        .foregroundColor(Color.lifeboard.textTertiary)

                    Spacer()

                    Button("Set") {
                        if let mins = Int(customMinutes), mins > 0 {
                            duration = TimeInterval(mins * 60)
                        }
                        showCustom = false
                    }
                    .font(.lifeboard(.callout).weight(.medium))
                    .foregroundColor(Color.lifeboard.accentPrimary)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion), value: showCustom)
    }
}

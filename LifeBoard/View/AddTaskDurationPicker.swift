//
//  AddTaskDurationPicker.swift
//  LifeBoard
//
//  Estimated duration picker with preset pills and custom option.
//

import SwiftUI

// MARK: - Duration Picker

struct AddTaskDurationPicker: View {
    @Binding var duration: TimeInterval?

    @State private var showCustom = false
    @State private var customMinutes: String = ""

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    private let presets: [(label: String, seconds: TimeInterval)] = [
        ("15m", 15 * 60),
        ("30m", 30 * 60),
        ("1h", 60 * 60),
        ("2h", 2 * 60 * 60),
        ("4h", 4 * 60 * 60),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Estimated Duration")
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
                        withAnimation(LifeBoardAnimation.snappy) {
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
                            withAnimation(LifeBoardAnimation.snappy) {
                                duration = preset.seconds
                                showCustom = false
                            }
                        }
                    }

                    // Custom button
                    AddTaskMetadataChip(
                        icon: "pencil",
                        text: showCustom ? "\(customMinutes)m" : "Custom",
                        isActive: showCustom
                    ) {
                        withAnimation(LifeBoardAnimation.snappy) {
                            showCustom.toggle()
                        }
                    }
                }
            }

            // Custom input
            if showCustom {
                HStack(spacing: spacing.s8) {
                    TextField("Minutes", text: $customMinutes)
                        .font(.lifeboard(.callout))
                        .keyboardType(.numberPad)
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
        .animation(LifeBoardAnimation.snappy, value: showCustom)
    }
}

//
//  AddTaskXPPreview.swift
//  LifeBoard
//
//  Dynamic XP preview badge — shows exact XP if completed now.
//  Uses .contentTransition(.numericText()) for rolling counter animation.
//

import SwiftUI

// MARK: - Add Task XP Preview

struct AddTaskXPPreview: View {
    let priority: TaskPriority
    let estimatedDuration: TimeInterval?
    let dueDate: Date?
    let todayXPSoFar: Int?
    let isGamificationV2Enabled: Bool

    private var preview: XPCompletionPreview? {
        if isGamificationV2Enabled {
            guard let todayXPSoFar else { return nil }
            return XPCalculationEngine.completionXPIfCompletedNow(
                priorityRaw: priority.rawValue,
                estimatedDuration: estimatedDuration,
                dueDate: dueDate,
                dailyEarnedSoFar: todayXPSoFar,
                isGamificationV2Enabled: true
            )
        }
        return XPCalculationEngine.completionXPIfCompletedNow(
            priorityRaw: priority.rawValue,
            estimatedDuration: estimatedDuration,
            dueDate: dueDate,
            dailyEarnedSoFar: 0,
            isGamificationV2Enabled: false
        )
    }

    private var isHighValue: Bool {
        priority == .max || priority == .high
    }

    private var priorityColor: Color {
        switch priority {
        case .max: return Color.lifeboard.priorityMax
        case .high: return Color.lifeboard.priorityHigh
        case .low: return Color.lifeboard.priorityLow
        case .none: return Color.lifeboard.priorityNone
        }
    }

    @State private var pulsing = false

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHighValue ? Color.lifeboard.accentSecondary : Color.lifeboard.textTertiary)

                Text(preview?.shortLabel ?? "XP pending")
                    .font(.lifeboard(.callout))
                    .fontWeight(.medium)
                    .foregroundColor(isHighValue ? Color.lifeboard.textSecondary : Color.lifeboard.textTertiary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHighValue ? Color.lifeboard.accentWash : Color.lifeboard.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isHighValue ? priorityColor.opacity(pulsing ? 0.8 : 0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .animation(LifeBoardAnimation.quick, value: priority)
        .onChange(of: priority) { _, newPriority in
            if newPriority == .high || newPriority == .max {
                withAnimation(LifeBoardAnimation.gentle) {
                    pulsing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(LifeBoardAnimation.gentle) {
                        pulsing = false
                    }
                }
            }
        }
    }
}

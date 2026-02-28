//
//  AddTaskXPPreview.swift
//  Tasker
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
        case .max: return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low: return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone
        }
    }

    @State private var pulsing = false

    var body: some View {
        HStack {
            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHighValue ? Color.tasker.accentSecondary : Color.tasker.textTertiary)

                Text(preview?.shortLabel ?? "XP pending")
                    .font(.tasker(.callout))
                    .fontWeight(.medium)
                    .foregroundColor(isHighValue ? Color.tasker.textSecondary : Color.tasker.textTertiary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHighValue ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isHighValue ? priorityColor.opacity(pulsing ? 0.8 : 0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .animation(TaskerAnimation.quick, value: priority)
        .onChange(of: priority) { _, newPriority in
            if newPriority == .high || newPriority == .max {
                withAnimation(TaskerAnimation.gentle) {
                    pulsing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(TaskerAnimation.gentle) {
                        pulsing = false
                    }
                }
            }
        }
    }
}

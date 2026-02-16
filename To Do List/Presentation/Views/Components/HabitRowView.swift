//
//  HabitRowView.swift
//  Tasker
//
//  Row view for habits with vertical gradient tint and streak indicators.
//  Features unique layout different from task rows with checkbox and 14-day history.
//

import SwiftUI

// MARK: - Habit Row View

/// Custom row view for displaying habits with streak-based visual styling
public struct HabitRowView: View {
    // MARK: - Properties

    public let habit: HabitRowDisplayData
    public let isCompleted: Bool
    public let onToggle: () -> Void

    /// Maximum streak for gradient calculation
    private let maxStreakForGradient: Int = 14

    // MARK: - Initialization

    public init(
        habit: HabitRowDisplayData,
        isCompleted: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.habit = habit
        self.isCompleted = isCompleted
        self.onToggle = onToggle
    }

    // MARK: - Body

    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onToggle()
            }
        }) {
            HStack(spacing: 12) {
                // Icon with gradient tint background
                habitIcon

                // Name and difficulty
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color(hex: habit.color))
                        .strikethrough(isCompleted)
                        .animation(.easeOut(duration: 0.2), value: isCompleted)

                    Text(habit.difficulty.displayName)
                        .font(.tasker(.caption2))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Streak dots (last 7 days)
                streakDots

                // Checkbox
                checkbox
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(gradientBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Habit Icon

    private var habitIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(gradientTint)
                .frame(width: 44, height: 44)

            Image(systemName: habit.iconName)
                .font(.tasker(.title2))
                .foregroundColor(iconColor)
        }
    }

    // MARK: - Checkbox

    private var checkbox: some View {
        ZStack {
            Circle()
                .stroke(isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 28, height: 28)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.tasker(.caption1))
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Streak Dots

    private var streakDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                let dayCompleted = habit.streakHistory.reversed().dropFirst(index).first ?? false
                Circle()
                    .fill(dayCompleted ? streakColor : Color.gray.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Gradients and Colors

    /// Vertical gradient tint based on streak
    private var gradientTint: Color {
        let streakRatio = Double(min(habit.currentStreak, maxStreakForGradient)) / Double(maxStreakForGradient)
        let baseColor = Color(hex: habit.color)
        return baseColor.opacity(streakRatio * 0.3)
    }

    /// Full background with subtle gradient
    private var gradientBackground: some View {
        let baseColor = Color(hex: habit.color)
        let streakRatio = Double(min(habit.currentStreak, maxStreakForGradient)) / Double(maxStreakForGradient)

        return LinearGradient(
            colors: [
                baseColor.opacity(0),
                baseColor.opacity(streakRatio * 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Icon color (more vibrant on higher streaks)
    private var iconColor: Color {
        let streakRatio = Double(min(habit.currentStreak, maxStreakForGradient)) / Double(maxStreakForGradient)
        let baseColor = Color(hex: habit.color)
        return baseColor.opacity(0.5 + streakRatio * 0.5)
    }

    /// Streak color based on streak length
    private var streakColor: Color {
        switch habit.currentStreak {
        case 0..<3: return Color.green
        case 3..<7: return Color.blue
        case 7..<14: return Color.purple
        default: return Color.orange
        }
    }
}

// MARK: - Habit Display Data

/// Data model for habit display
public struct HabitRowDisplayData: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let iconName: String
    public let color: String
    public let difficulty: HabitDifficulty
    public let currentStreak: Int
    public let streakHistory: [Bool]

    public init(
        id: UUID,
        name: String,
        iconName: String,
        color: String,
        difficulty: HabitDifficulty = .medium,
        currentStreak: Int = 0,
        streakHistory: [Bool] = []
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.color = color
        self.difficulty = difficulty
        self.currentStreak = currentStreak
        self.streakHistory = streakHistory
    }
}

#if DEBUG
struct HabitRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            HabitRowView(
                habit: HabitRowDisplayData(
                    id: UUID(),
                    name: "Morning Meditation",
                    iconName: "brain.head.profile",
                    color: "8B5CF6",
                    difficulty: .easy,
                    currentStreak: 5,
                    streakHistory: [true, true, true, true, true, false, false]
                ),
                isCompleted: false
            ) { logDebug("Tapped") }

            HabitRowView(
                habit: HabitRowDisplayData(
                    id: UUID(),
                    name: "Exercise",
                    iconName: "figure.run",
                    color: "22C55E",
                    difficulty: .hard,
                    currentStreak: 14,
                    streakHistory: Array(repeating: true, count: 14)
                ),
                isCompleted: true
            ) { logDebug("Tapped") }
        }
        .padding()
    }
}
#endif

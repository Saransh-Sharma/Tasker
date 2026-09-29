import SwiftUI

extension HabitBoardScreen {
    var boardLoadingState: some View {
        VStack(spacing: spacing.s12) {
            ProgressView()
            Text("Loading…")
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s24)
        .accessibilityIdentifier(HabitBoardAccessibilityID.loadingState)
    }

    func boardErrorState(message: String) -> some View {
        VStack(spacing: spacing.s12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard.statusWarning)

            Text("Couldn’t load habits.")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)

            Text(message)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: spacing.s8) {
                Button("Try again") {
                    viewModel.refresh()
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier(HabitBoardAccessibilityID.retryButton)

                Button("Manage habits") {
                    openManageHabitsFromBoard()
                }
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier(HabitBoardAccessibilityID.createButton)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s24)
        .accessibilityIdentifier(HabitBoardAccessibilityID.errorState)
    }

    var boardEmptyState: some View {
        VStack(spacing: spacing.s12) {
            Image(systemName: "sun.max.fill")
                .lifeboardFont(.display)
                .foregroundStyle(ClayColorTokens.role(.routine).deep)
                .frame(width: 64, height: 64)
                .background(ClayColorTokens.role(.routine).softSurface, in: Circle())
                .overlay(Circle().stroke(ClayColorTokens.role(.routine).border, lineWidth: 1))

            Text("No habits yet")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)

            Button("Manage habits") {
                openManageHabitsFromBoard()
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
            .accessibilityIdentifier(HabitBoardAccessibilityID.createButton)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s24)
        .accessibilityIdentifier(HabitBoardAccessibilityID.emptyState)
    }

    private func openManageHabitsFromBoard() {
        onManageHabits()
    }
}

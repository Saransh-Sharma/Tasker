//
//  SunriseRecurringTaskDeleteConfirmationView.swift
//  LifeBoard
//

import SwiftUI

struct SunriseRecurringTaskDeleteConfirmationView: View {
    let taskTitle: String
    let onDeleteSingle: () -> Void
    let onDeleteSeries: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lifeboard.bgCanvas.ignoresSafeArea()

                VStack(alignment: .leading, spacing: LBSpacingTokens.lg) {
                    header

                    LBGlassCard(
                        cornerRadius: LBRadiusTokens.largeCard,
                        fill: reduceTransparency ? Color.lifeboard.surfacePrimary : LBColorTokens.glassStrong.opacity(0.86),
                        usesMaterialBackground: reduceTransparency == false
                    ) {
                        VStack(spacing: LBSpacingTokens.sm) {
                            destructiveAction(
                                title: "Delete This Task",
                                systemImage: "calendar.badge.minus",
                                action: onDeleteSingle
                            )

                            Divider()
                                .overlay(Color.lifeboard.strokeHairline.opacity(0.5))

                            destructiveAction(
                                title: "Delete Entire Series",
                                systemImage: "repeat.circle",
                                action: onDeleteSeries
                            )
                        }
                        .padding(LBSpacingTokens.md)
                    }

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.lifeboard(.body))
                    .foregroundColor(Color.lifeboard.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.lifeboard.surfaceSecondary, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.recurringTaskDelete.cancel")
                }
                .padding(LBSpacingTokens.lg)
                .frame(maxWidth: 560)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("home.recurringTaskDelete.close")
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text("Delete recurring task?")
                .font(.lifeboard(.title3))
                .foregroundColor(Color.lifeboard.textPrimary)

            Text("Choose whether to delete only \"\(taskTitle)\" or every task in the series.")
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func destructiveAction(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            action()
        } label: {
            HStack(spacing: LBSpacingTokens.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.lifeboard(.body))

                Spacer()
            }
            .foregroundColor(Color.lifeboard.statusDanger)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title == "Delete This Task" ? "home.recurringTaskDelete.single" : "home.recurringTaskDelete.series")
    }
}

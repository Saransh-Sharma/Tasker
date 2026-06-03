//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayHabitRowView: View {
    let card: EvaDayHabitCard
    let overlay: EvaDayHabitOverlayState
    let chips: [EvaDayStatusChip]
    let actions: [EvaDayHabitAction]
    let chipColorProvider: (String) -> Color
    let actionTitle: (EvaDayHabitAction) -> String
    let actionHandler: (EvaDayHabitAction) -> Void

    var family: HabitColorFamily {
        HabitColorFamily.family(
            for: card.accentHex,
            fallback: card.kind == .positive ? .green : .coral
        )
    }

    var cadence: HabitCadenceDraft {
        card.cadence ?? .daily()
    }

    var boardCells: [HabitBoardCell] {
        HabitBoardPresentationBuilder.buildCells(
            marks: resolvedMarks,
            cadence: cadence,
            referenceDate: Date(),
            dayCount: 14
        )
    }

    var resolvedMarks: [HabitDayMark] {
        guard let resolvedTodayState = overlay.resolvedTodayState else {
            return card.last14Days
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var marks = card.last14Days.filter { !calendar.isDate($0.date, inSameDayAs: today) }
        marks.append(HabitDayMark(date: today, state: resolvedTodayState))
        return marks.sorted { $0.date < $1.date }
    }

    var accentColor: Color {
        HabitEverydayPalette.familyPreview(family)
    }

    var streakLabel: String {
        card.currentStreak > 0 ? "\(card.currentStreak)d streak" : "Streak ready"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            habitTile

            EvaDayHabitActionsView(
                actions: actions,
                isProcessing: overlay.isProcessing,
                actionTitle: actionTitle,
                actionHandler: actionHandler
            )

            if let statusMessage = overlay.statusMessage, statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .padding(LifeBoardTheme.Spacing.md)
        .background(Color.lifeboard(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous)
                .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
        )
    }

    var habitTile: some View {
        Button {
            actionHandler(.open)
        } label: {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.sm) {
                    ZStack {
                        accentColor.opacity(0.14)
                        Image(systemName: card.iconSymbolName ?? "circle.dashed")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: LifeBoardTheme.Spacing.xs) {
                            Text(card.cadenceLabel)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                .lineLimit(1)
                            Text(streakLabel)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                                .lineLimit(1)
                            if let projectName = card.projectName, projectName.isEmpty == false {
                                Text(projectName)
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.textTertiary))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: LifeBoardTheme.Spacing.sm)

                    if overlay.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        EvaDayStatusChipsView(
                            chips: chips,
                            colorProvider: chipColorProvider
                        )
                    }
                }

                HabitBoardStripView(
                    cells: boardCells,
                    family: family,
                    mode: .compact,
                    cellSizeOverride: 13,
                    cellWidthOverride: 13,
                    cellHeightOverride: 13
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.title)
        .accessibilityValue("\(streakLabel). Last \(boardCells.count) days shown.")
        .accessibilityHint("Opens habit details.")
        .accessibilityIdentifier("chat.dayOverview.habitTile.\(card.habitID.uuidString)")
    }
}

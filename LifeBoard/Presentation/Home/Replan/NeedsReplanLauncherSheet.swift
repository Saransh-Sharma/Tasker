//
//  NeedsReplanLauncherSheet.swift
//  LifeBoard
//

import SwiftUI

struct NeedsReplanLauncherSheet: View {
    let summary: NeedsReplanSummary
    let onStart: () -> Void
    let onLater: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s20) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("home.needsReplan.launcher")

            Capsule()
                .fill(Color.lifeboard.strokeHairline.opacity(0.7))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    Image(systemName: summary.count == 0 ? "checkmark.seal.fill" : "sunrise.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(summary.count == 0 ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning)
                        .frame(width: 46, height: 46)
                        .background(Color.lifeboard.accentWash.opacity(0.9), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(summary.launcherTitle)
                            .font(.lifeboard(.screenTitle))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(summary.launcherBodyText)
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if summary.count > 0 {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    launcherRow(summary.count == 1 ? "1 task needs a decision" : "\(summary.count) tasks need a decision", systemImage: "checklist")
                    if summary.datedCount > 0 {
                        let datedLabel = summary.datedCount == 1
                            ? "1 overdue or carry-over task"
                            : "\(summary.datedCount) overdue or carry-over tasks"
                        launcherRow(datedLabel, systemImage: "calendar.badge.exclamationmark")
                    }
                    if summary.unscheduledCount > 0 {
                        let unscheduledLabel = summary.unscheduledCount == 1
                            ? "1 task has no due date or time"
                            : "\(summary.unscheduledCount) tasks have no due date or time"
                        launcherRow(unscheduledLabel, systemImage: "tray")
                    }
                    if summary.dayCount > 1 {
                        launcherRow("Spanning \(summary.dayCount) past days", systemImage: "calendar")
                    }
                    if let newestDate = summary.newestDate {
                        launcherRow("Start with \(newestDate.formatted(.dateTime.weekday(.wide).month().day()))", systemImage: "arrow.forward.circle")
                    }
                }
                .padding(spacing.s12)
                .background(Color.lifeboard.surfaceSecondary.opacity(0.86), in: RoundedRectangle(cornerRadius: corner.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.card, style: .continuous)
                        .stroke(Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
                )
            }

            Button(action: {
                LifeBoardFeedback.selection()
                onStart()
            }) {
                Label(summary.launcherPrimaryActionTitle, systemImage: summary.count == 0 ? "plus.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.lifeboard(.button))
                    .foregroundStyle(Color.lifeboard.accentOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                    .background(Color.lifeboard.actionPrimary, in: RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                    .accessibilityIdentifier("home.needsReplan.start")
            }
            .accessibilityIdentifier("home.needsReplan.start")
            .buttonStyle(.plain)
            .scaleOnPress()

            HStack {
                Button("Later") {
                    LifeBoardFeedback.light()
                    onLater()
                }
                    .font(.lifeboard(.body).weight(.semibold))
                Spacer()
            }
            .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .padding(24)
        .background(Color.lifeboard.bgCanvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func launcherRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: spacing.s12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.lifeboard.accentPrimary)
                .frame(width: 26, height: 26)
                .background(Color.lifeboard.accentWash, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.lifeboard(.support))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

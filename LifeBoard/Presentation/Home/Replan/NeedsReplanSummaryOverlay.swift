//
//  NeedsReplanSummaryOverlay.swift
//  LifeBoard
//

import SwiftUI
import UIKit

struct NeedsReplanSummaryOverlay: View {
    let state: HomeReplanSessionState
    let onReviewSkipped: () -> Void
    let onViewToday: () -> Void
    let onDone: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    Image(systemName: state.skippedCount > 0 ? "clock.badge.exclamationmark.fill" : "checkmark.seal.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(state.skippedCount > 0 ? Color.lifeboard.statusWarning : Color.lifeboard.statusSuccess)
                        .frame(width: 48, height: 48)
                        .background(Color.lifeboard.accentWash.opacity(0.9), in: Circle())
                        .lifeboardSuccessPulse(isActive: state.skippedCount == 0)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(state.skippedCount > 0 ? "You skipped \(state.skippedCount) tasks" : "All caught up")
                            .font(.lifeboard(.title1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(state.skippedCount > 0 ? "You can review them now or leave them for later." : "You've resolved your unfinished tasks.")
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .lineSpacing(2)
                    }
                }

                VStack(alignment: .leading, spacing: spacing.s8) {
                    metric("rescheduled", state.outcomes.rescheduled)
                    metric("moved to Inbox", state.outcomes.movedToInbox)
                    metric("completed", state.outcomes.completed)
                    metric("deleted", state.outcomes.deleted)
                }
                .padding(spacing.s12)
                .background(Color.lifeboard.surfaceSecondary.opacity(0.82), in: RoundedRectangle(cornerRadius: corner.card, style: .continuous))

                if state.skippedCount > 0 {
                    summaryPrimaryButton("Review skipped", systemImage: "arrow.uturn.backward.circle.fill", action: onReviewSkipped)
                    summarySecondaryButton("Finish", action: onDone)
                } else {
                    summaryPrimaryButton("View Today", systemImage: "sun.max.fill", action: onViewToday)
                    summarySecondaryButton("Done", action: onDone)
                }
            }
            .padding(20)
        }
        .frame(maxHeight: min(UIScreen.main.bounds.height * 0.52, 420))
        .background(Color.lifeboard.surfacePrimary.opacity(0.96), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
        .accessibilityIdentifier("home.needsReplan.summary")
    }

    private func metric(_ label: String, _ count: Int) -> some View {
        HStack {
            Text("\(count)")
                .font(.lifeboard(.metric))
                .foregroundStyle(count > 0 ? Color.lifeboard.accentPrimary : Color.lifeboard.textQuaternary)
                .contentTransition(.numericText())
            Text(label)
                .font(.lifeboard(.support).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
            Spacer(minLength: 0)
        }
    }

    private func summaryPrimaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            LifeBoardFeedback.selection()
            action()
        }) {
            Label(title, systemImage: systemImage)
                .font(.lifeboard(.button))
                .foregroundStyle(Color.lifeboard.accentOnPrimary)
                .frame(maxWidth: .infinity, minHeight: spacing.buttonHeight)
                .background(Color.lifeboard.actionPrimary, in: RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private func summarySecondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.lifeboard(.body).weight(.semibold))
            .foregroundStyle(Color.lifeboard.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain)
    }
}

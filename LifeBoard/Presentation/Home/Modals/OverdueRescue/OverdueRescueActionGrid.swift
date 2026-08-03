//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueActionGrid: View {
    let metrics: OverdueRescueDeckLayoutMetrics
    let keepTitle: String
    let keepAccessibilityHint: String
    let keep: () -> Void
    let move: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        Group {
            if metrics.actionGridUsesSingleColumn {
                VStack(spacing: 12) {
                    keepButton
                    moveButton
                    editButton
                    deleteButton
                }
            } else {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        keepButton
                        moveButton
                    }
                    HStack(spacing: 14) {
                        editButton
                        deleteButton
                    }
                }
            }
        }
    }

    var keepButton: some View {
        actionButton(
            title: keepTitle,
            icon: "checkmark.circle",
            fill: OverdueRescuePalette.keepFill,
            foreground: OverdueRescuePalette.keepForeground,
            accessibilityIdentifier: "home.rescue.action.keepToday",
            action: keep
        )
    }

    var moveButton: some View {
        actionButton(
            title: OverdueRescueDeckCopy.moveLater,
            icon: "clock",
            fill: OverdueRescuePalette.moveFill,
            foreground: OverdueRescuePalette.moveForeground,
            accessibilityIdentifier: "home.rescue.action.moveLater",
            action: move
        )
    }

    var editButton: some View {
        actionButton(title: OverdueRescueDeckCopy.edit, icon: "pencil", fill: OverdueRescuePalette.editFill, foreground: OverdueRescuePalette.editForeground, action: edit)
    }

    var deleteButton: some View {
        actionButton(title: OverdueRescueDeckCopy.delete, icon: "trash", fill: OverdueRescuePalette.deleteFill, foreground: OverdueRescuePalette.deleteForeground, action: delete)
    }

    func actionButton(
        title: String,
        icon: String,
        fill: Color,
        foreground: Color,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.lifeboard(.button))
                .fontWeight(.semibold)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: metrics.actionButtonHeight)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(fill.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(foreground.opacity(0.10), lineWidth: 1)
                        )
                        .lbShadow(LBShadowTokens.rescueTile)
                )
                .contentShape(RoundedRectangle(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityHint(accessibilityHint(for: title))
        .accessibilityIdentifier(accessibilityIdentifier ?? "home.rescue.action.\(title.replacingOccurrences(of: " ", with: ""))")
    }

    func accessibilityHint(for title: String) -> String {
        if title == keepTitle { return keepAccessibilityHint }
        if title == OverdueRescueDeckCopy.edit { return "Opens quick edit for this task." }
        if title == OverdueRescueDeckCopy.delete { return "Removes this task from your board." }
        return "Moves this task out of today and moves to the next card."
    }
}

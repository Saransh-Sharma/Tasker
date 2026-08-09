import SwiftUI
import UIKit

// What a person can decide about an overdue task, and how the deck
// surfaces those choices.

// MARK: - OverdueRescueDecisionAction

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueDecisionAction: String, Codable, Sendable {
    case keepToday
    case moveLater
    case edit
    case delete
}

// MARK: - OverdueRescueDecisionSource

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueDecisionSource: String, Codable, Sendable {
    case swipe
    case tap
    case edit
    case delete
    case bulk
}

// MARK: - OverdueRescueActionGrid

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


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
                        .lbShadow(ShadowTokens.rescueTile)
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

// MARK: - OverdueRescueSwipeHint

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueSwipeHint: View {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
            Text(text)
        }
        .font(.lifeboard(.caption1))
        .foregroundStyle(OverdueRescuePalette.secondaryInk)
        .frame(height: 28)
        .accessibilityHidden(true)
    }

    var icon: String {
        switch reveal {
        case .keep: return "hand.point.right"
        case .move: return "hand.point.left"
        case .none: return "hand.draw.fill"
        }
    }

    var text: String {
        switch reveal {
        case .keep: return "Swipe right to keep"
        case .move: return "Swipe left to move later"
        case .none: return "Swipe left or right or tap a choice below."
        }
    }
}

// MARK: - OverdueRescueSwipeRevealKind

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


enum OverdueRescueSwipeRevealKind: Equatable {
    case none
    case keep
    case move
}

// MARK: - OverdueRescueRevealPanel

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueRevealPanel: View {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double
    let metrics: OverdueRescueDeckLayoutMetrics
    let keepTitle: String

    var body: some View {
        RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                    .stroke(panelForeground.opacity(0.18), lineWidth: 1)
            )
            .frame(width: metrics.revealPanelWidth, height: metrics.cardHeight * 0.96)
            .lbShadow(ShadowTokens.rescueReveal(progress: easedProgress))
            .overlay(alignment: reveal == .keep ? .leading : .trailing) {
                if reveal != .none {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 54, weight: .semibold))
                            .frame(width: 60, height: 60)
                        Text(title)
                            .font(.lifeboard(.screenTitle))
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: metrics.revealContentWidth)
                    .foregroundStyle(panelForeground)
                    .opacity(easedProgress)
                    .scaleEffect(0.86 + 0.14 * easedProgress)
                    .padding(.horizontal, metrics.revealContentInset)
                }
            }
            .offset(x: panelOffsetX, y: 0)
            .opacity(reveal == .none ? 0 : easedProgress)
            .accessibilityHidden(true)
    }

    var easedProgress: Double {
        progress * progress * (3 - 2 * progress)
    }

    var panelOffsetX: CGFloat {
        metrics.revealPanelOffset(for: reveal)
    }

    var panelFill: Color {
        switch reveal {
        case .keep: return OverdueRescuePalette.keepFill
        case .move: return OverdueRescuePalette.moveFill
        case .none: return .clear
        }
    }

    var panelForeground: Color {
        switch reveal {
        case .keep: return OverdueRescuePalette.keepForeground
        case .move: return OverdueRescuePalette.moveForeground
        case .none: return Color.clear
        }
    }

    var title: String {
        switch reveal {
        case .keep: return keepTitle.replacingOccurrences(of: " ", with: "\n", options: [], range: keepTitle.range(of: " ", options: .backwards))
        case .move: return "Move\nlater"
        case .none: return ""
        }
    }

    var icon: String {
        switch reveal {
        case .keep: return "checkmark.circle"
        case .move: return "clock"
        case .none: return "circle"
        }
    }
}

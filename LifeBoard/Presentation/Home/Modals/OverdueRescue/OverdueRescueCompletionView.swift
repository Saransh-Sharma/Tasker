//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueCompletionView: View {
    let summary: OverdueRescueSummary
    let remaining: Int
    let bottomInset: CGFloat
    let viewToday: () -> Void
    let reviewRemaining: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 25) {
                HStack {
                    Button("Close", systemImage: "xmark", action: viewToday)
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(OverdueRescuePalette.glassFill))
                        .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                    Spacer()
                    Button("More", systemImage: "ellipsis") {}
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(OverdueRescuePalette.glassFill))
                        .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                OverdueRescueSunriseHero()
                    .frame(width: 294, height: 256)
                    .padding(.top, 6)
                Text("Board cleaned up")
                    .font(.lifeboard(.title1))
                    .fontWeight(.bold)
                    .foregroundStyle(OverdueRescuePalette.ink)
                Text("You sorted what still matters.")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)

                HStack(spacing: 14) {
                    statCard(icon: "checkmark.circle", value: summary.kept, label: "kept", color: Color.lifeboard.statusSuccess)
                    statCard(icon: "clock", value: summary.moved, label: "moved later", color: Color.lifeboard.statusWarning)
                    statCard(icon: "trash", value: summary.deleted, label: "deleted", color: Color.lifeboard.statusDanger)
                }
                .padding(.horizontal, 28)

                Text("Your board should feel lighter now.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)

                Button("View today", action: viewToday)
                    .font(.lifeboard(.button))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                    .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.primaryButtonHeight)
                    .background(OverdueRescueVisualSpec.primaryButtonBackground())
                    .padding(.horizontal, 42)
                    .accessibilityIdentifier("home.rescue.completion.viewToday")

                if remaining > 0 {
                    Button("Review remaining", systemImage: "list.bullet", action: reviewRemaining)
                        .font(.lifeboard(.button))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.secondaryButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.lifeboard.accentPrimary.opacity(0.32), lineWidth: 1.2)
                        )
                        .padding(.horizontal, 42)
                }

                Color.clear.frame(height: max(28, bottomInset))
            }
            .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    func statCard(icon: String, value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title.weight(.semibold))
            Text("\(value)")
                .font(.lifeboard(.title2))
                .fontWeight(.bold)
            Text(label)
                .font(.lifeboard(.caption1))
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 126)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color.opacity(0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(color.opacity(0.10), lineWidth: 1)
                )
                .lbShadow(LBShadowTokens.rescueCompletionTile)
        )
    }
}

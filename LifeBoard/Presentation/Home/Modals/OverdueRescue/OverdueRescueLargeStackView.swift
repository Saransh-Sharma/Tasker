//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueLargeStackView: View {
    let count: Int
    let safeCount: Int
    let applySafeFixes: () -> Void
    let startManualReview: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 22) {
            OverdueRescueShieldHero()
                .frame(width: 220, height: 180)
            Text("Large rescue stack")
                .font(.lifeboard(.title1))
                .fontWeight(.bold)
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text("\(count) tasks need review. Start with high-confidence fixes or review manually.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Apply safe fixes") {
                dismiss()
                applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color.lifeboard.accentPrimary))
            .disabled(safeCount == 0)
            Button("Start manual review") {
                dismiss()
                startManualReview()
            }
            .font(.lifeboard(.button))
            .foregroundStyle(Color.lifeboard.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: 62)
        }
        .padding(28)
        .background(OverdueRescueBackground())
    }
}

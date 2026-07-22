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
                .foregroundStyle(OverdueRescuePalette.ink)
                .multilineTextAlignment(.center)
            Text("\(count) tasks need review. Start with high-confidence fixes or review manually.")
                .font(.lifeboard(.title3))
                .foregroundStyle(OverdueRescuePalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
            Spacer()
            Button("Apply safe fixes") {
                dismiss()
                applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.primaryButtonHeight)
            .background(OverdueRescueVisualSpec.primaryButtonBackground())
            .opacity(safeCount == 0 ? 0.58 : 1.0)
            .disabled(safeCount == 0)
            Button("Start manual review") {
                dismiss()
                startManualReview()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(OverdueRescuePalette.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(OverdueRescuePalette.accentSoftFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(OverdueRescuePalette.accentSoftStroke, lineWidth: 1.2)
                    )
            )
        }
        .padding(28)
        .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }
}

#if DEBUG
#Preview("Large Stack - Light") {
    OverdueRescueLargeStackView(
        count: 28,
        safeCount: 12,
        applySafeFixes: {},
        startManualReview: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Large Stack - Dark") {
    OverdueRescueLargeStackView(
        count: 28,
        safeCount: 12,
        applySafeFixes: {},
        startManualReview: {}
    )
    .preferredColorScheme(.dark)
}
#endif

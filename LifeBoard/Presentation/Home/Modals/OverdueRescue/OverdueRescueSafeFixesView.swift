//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSafeFixesView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(OverdueRescuePalette.ink)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(OverdueRescuePalette.glassFill))
                    .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                Spacer()
            }
            OverdueRescueShieldHero()
                .frame(width: 244, height: 210)
                .padding(.top, 8)
            Text("Apply \(viewModel.safeFixes.count) safe fixes?")
                .font(.lifeboard(.title1))
                .fontWeight(.bold)
                .foregroundStyle(OverdueRescuePalette.ink)
                .multilineTextAlignment(.center)
            Text("LifeBoard found \(viewModel.safeFixes.count) changes it is confident about.")
                .font(.lifeboard(.title3))
                .foregroundStyle(OverdueRescuePalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                if viewModel.safeFixBreakdown.move > 0 {
                    safeRow(icon: "clock", title: "\(viewModel.safeFixBreakdown.move) move later", value: "\(viewModel.safeFixBreakdown.move)", color: Color.lifeboard.statusWarning)
                }
                if viewModel.safeFixBreakdown.move > 0, viewModel.safeFixBreakdown.stay > 0 {
                    Divider()
                }
                if viewModel.safeFixBreakdown.stay > 0 {
                    safeRow(icon: "checkmark.circle", title: "\(viewModel.safeFixBreakdown.stay) stay today", value: "\(viewModel.safeFixBreakdown.stay)", color: Color.lifeboard.statusSuccess)
                }
                if viewModel.safeFixBreakdown.duration > 0, viewModel.safeFixBreakdown.move + viewModel.safeFixBreakdown.stay > 0 {
                    Divider()
                }
                if viewModel.safeFixBreakdown.duration > 0 {
                    safeRow(icon: "calendar", title: "\(viewModel.safeFixBreakdown.duration) gets a duration", value: "\(viewModel.safeFixBreakdown.duration)", color: Color.lifeboard.accentPrimary)
                }
            }
            .padding(.vertical, 10)
            .background(
                OverdueRescueVisualSpec.glassCard(cornerRadius: 28, fill: OverdueRescuePalette.glassFill)
            )

            HStack(spacing: 14) {
                Image(systemName: "shield")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.lifeboard.accentPrimary.opacity(0.10)))
                Text("These changes are non-destructive\nand can be undone.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 34)

            Spacer()
            Button("Apply \(viewModel.safeFixes.count) fixes") {
                dismiss()
                viewModel.applySafeFixes()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.primaryButtonHeight)
            .background(OverdueRescueVisualSpec.primaryButtonBackground())
            .disabled(viewModel.safeFixes.isEmpty)
            Button("Review first") {
                dismiss()
            }
            .font(.lifeboard(.button))
            .fontWeight(.bold)
            .foregroundStyle(Color.lifeboard.accentPrimary)
            .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.secondaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.lifeboard.accentPrimary.opacity(0.32), lineWidth: 1.2)
            )
        }
        .padding(28)
        .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverdueRescueBackground())
        .presentationDetents([.large])
        .presentationBackground(.clear)
    }

    func safeRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.12)))
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(OverdueRescuePalette.ink)
            Spacer()
            Text(value)
                .font(.lifeboard(.headline))
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 22)
        .frame(height: 82)
    }
}

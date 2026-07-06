//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescuePauseView: View {
    @ObservedObject var viewModel: OverdueRescueViewModel
    let bottomInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 28) {
                HStack {
                    Button("Close", systemImage: "xmark") { onDismiss() }
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(OverdueRescuePalette.glassFill))
                        .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                OverdueRescueCupHero()
                    .frame(width: 250, height: 248)

                VStack(spacing: 10) {
                    Text("Pause rescue?")
                        .font(.lifeboard(.title1))
                        .fontWeight(.bold)
                        .foregroundStyle(OverdueRescuePalette.ink)
                    Text("You reviewed \(viewModel.sprintResolvedCount) of \(viewModel.sprintTotal) tasks.\nYour changes are saved.\n\(viewModel.remainingCount) tasks can wait.")
                        .font(.lifeboard(.title3))
                        .foregroundStyle(OverdueRescuePalette.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                }

                HStack(spacing: 18) {
                    Button {
                        onDismiss()
                    } label: {
                        Label("Pause", systemImage: "cup.and.saucer")
                            .font(.lifeboard(.button))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.lifeboard.accentPrimary.opacity(0.38), lineWidth: 1.2)
                            )
                    }
                    .foregroundStyle(Color.lifeboard.accentPrimary)

                    Button {
                        viewModel.resume()
                    } label: {
                        Label("Keep going", systemImage: "arrow.right")
                            .font(.lifeboard(.button))
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(OverdueRescueVisualSpec.primaryButtonBackground())
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 28)

                Button {
                    viewModel.resume()
                } label: {
                    HStack(spacing: 20) {
                        Image(systemName: "lifepreserver")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.statusWarning)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(OverdueRescuePalette.glassFill))
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Resume rescue")
                                .font(.lifeboard(.headline))
                                .foregroundStyle(OverdueRescuePalette.ink)
                            Text("\(viewModel.summary.reviewed) done · \(viewModel.remainingCount) left")
                                .font(.lifeboard(.title3))
                                .foregroundStyle(OverdueRescuePalette.secondaryInk)
                            LifeBoardProgressBar(progress: viewModel.progress, colors: [Color.lifeboard.accentPrimary])
                        }
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }
                    .padding(22)
                    .background(
                        OverdueRescueVisualSpec.glassCard(cornerRadius: 28, fill: OverdueRescuePalette.glassFill)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                Color.clear.frame(height: max(28, bottomInset))
            }
            .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }
}

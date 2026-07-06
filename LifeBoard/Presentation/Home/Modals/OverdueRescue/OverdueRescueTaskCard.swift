//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueTaskCard: View {
    let card: OverdueRescueCardModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(card.task.title)
                        .font(.lifeboard(.title2))
                        .fontWeight(.bold)
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Label(card.projectLabel, systemImage: "folder")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(OverdueRescuePalette.secondaryInk)

                    Text(card.confidenceLabel)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.lifeboard.accentPrimary.opacity(0.11)))
                }
                .padding(.trailing, 78)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.overdueText)
                            .font(.lifeboard(.headline))
                            .fontWeight(.semibold)
                            .foregroundStyle(OverdueRescuePalette.secondaryInk)
                        Text(card.reasonBody)
                            .font(.lifeboard(.body))
                            .foregroundStyle(OverdueRescuePalette.innerBody)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Color.clear.frame(width: 84, height: 1)
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.innerCardCorner, style: .continuous)
                        .fill(OverdueRescuePalette.glassFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.innerCardCorner, style: .continuous)
                                .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
                        )
                        .shadow(color: OverdueRescuePalette.softShadow, radius: 16, y: 8)
                )
            }
            .padding(30)

            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .opacity(0.74)
                .padding(.top, 30)
                .padding(.trailing, 24)
                .accessibilityHidden(true)

            Image(decorative: "rescue_decor_plant")
                .resizable()
                .scaledToFit()
                .frame(width: 106, height: 128)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -22, y: -82)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(
            RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            OverdueRescuePalette.cardSurfaceTop,
                            OverdueRescuePalette.cardSurfaceBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                        .stroke(OverdueRescuePalette.cardStroke, lineWidth: 1)
                )
                .shadow(color: OverdueRescuePalette.softShadow, radius: 32, y: 18)
        )
        .clipShape(RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous))
    }
}

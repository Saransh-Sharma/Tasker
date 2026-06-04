//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueCupHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_cup")
                .resizable()
                .scaledToFit()
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 62, height: 62)
                .opacity(0.8)
                .offset(x: -84, y: -78)
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .opacity(0.6)
                .offset(x: 86, y: -46)
        }
    }
}

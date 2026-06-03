//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSunriseHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_sunrise")
                .resizable()
                .scaledToFit()
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .opacity(0.7)
                .offset(x: -104, y: -62)
            Image(decorative: "rescue_decor_sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .opacity(0.5)
                .offset(x: 106, y: -44)
            OverdueRescuePlant()
                .frame(width: 92, height: 110)
                .offset(x: 98, y: 20)
        }
    }
}

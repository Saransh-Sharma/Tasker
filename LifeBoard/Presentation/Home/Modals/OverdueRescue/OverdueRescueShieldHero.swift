//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueShieldHero: View {
    var body: some View {
        ZStack {
            Image(decorative: "rescue_decor_shield")
                .resizable()
                .scaledToFit()
            OverdueRescuePlant()
                .frame(width: 88, height: 108)
                .offset(x: 98, y: 36)
        }
    }
}

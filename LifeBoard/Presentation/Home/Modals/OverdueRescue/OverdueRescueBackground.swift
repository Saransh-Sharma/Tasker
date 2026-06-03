//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                OverdueRescuePalette.backgroundTop,
                OverdueRescuePalette.backgroundMid,
                OverdueRescuePalette.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

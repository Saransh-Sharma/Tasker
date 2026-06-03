//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueErrorView: View {
    let message: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Color.lifeboard.statusWarning)
            Text("Rescue paused")
                .font(.lifeboard(.title2))
                .fontWeight(.bold)
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text(message)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
            Button("Close", action: close)
            Spacer()
        }
        .padding(28)
    }
}

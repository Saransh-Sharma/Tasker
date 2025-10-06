//
//  ChartCardsScrollView.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI

/// Horizontally scrollable view containing multiple chart cards
struct ChartCardsScrollView: View {
    let referenceDate: Date?

    init(referenceDate: Date? = nil) {
        self.referenceDate = referenceDate
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 16) {
                // Line Chart Card
                ChartCard(
                    title: "Weekly Progress",
                    subtitle: "Task completion scores",
                    referenceDate: referenceDate
                )
                .frame(width: UIScreen.main.bounds.width - 64) // Account for container padding (16*2) + card padding (16*2)

                // Radar Chart Card
                RadarChartCard(
                    title: "Project Breakdown",
                    subtitle: "Weekly scores by project",
                    referenceDate: referenceDate
                )
                .frame(width: UIScreen.main.bounds.width - 64) // Account for container padding (16*2) + card padding (16*2)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Preview

struct ChartCardsScrollView_Previews: PreviewProvider {
    static var previews: some View {
        ChartCardsScrollView()
            .frame(height: 350)
            .background(Color(.systemGroupedBackground))
            .previewLayout(.sizeThatFits)
    }
}

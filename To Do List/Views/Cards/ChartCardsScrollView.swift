//
//  ChartCardsScrollView.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI

/// Vertically scrollable view containing multiple chart cards with guaranteed transparent background
struct ChartCardsScrollView: View {
    let referenceDate: Date?

    init(referenceDate: Date? = nil) {
        self.referenceDate = referenceDate
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 16) {
                // Line Chart Card
                ChartCard(
                    title: "Weekly Progress",
                    subtitle: "Task completion scores",
                    referenceDate: referenceDate
                )
                .background(Color.clear)

                // Radar Chart Card
                RadarChartCard(
                    title: "Project Breakdown",
                    subtitle: "Weekly scores by project",
                    referenceDate: referenceDate
                )
                .background(Color.clear)
            }
            .background(Color.clear)
            .padding(.horizontal, 16)
            .background(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .compositingGroup()
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

//
//  ActivityHeatmapView.swift
//  Tasker
//
//  GitHub-style activity heatmap (7 columns x 52 weeks).
//

import SwiftUI

public struct ActivityHeatmapView: View {
    public let data: [[Int]]
    
    public init(data: [[Int]] = []) {
        self.data = data.isEmpty ? Array(repeating: Array(repeating: 0, count: 52), count: 7) : data
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                let itemSize = getItemSize(in: geometry.size)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Month labels
                    HStack(spacing: itemSize.width + 2) {
                        Text("")
                            .frame(width: 20)
                        ForEach(0..<52) { week in
                            if week % 4 == 0 {
                                let monthIndex = min(week / 4, 11)  // Cap at 11 to prevent out of bounds
                                Text(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][monthIndex])
                                    .font(.tasker(.caption2))
                                    .frame(width: itemSize.width * 4)
                            } else {
                                Spacer().frame(width: itemSize.width * 4)
                            }
                        }
                    }

                    // Heatmap grid
                    ForEach(0..<7, id: \.self) { row in
                        HStack(spacing: 2) {
                            // Show day labels: S, M, T, W, T, F, S
                            Text(["S", "M", "T", "W", "T", "F", "S"][row])
                                .font(.tasker(.caption2))
                                .frame(width: 10, alignment: .trailing)
                            
                            ForEach(0..<52, id: \.self) { col in
                                let value = data[row][col]
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorForValue(value))
                                    .frame(width: itemSize.width, height: itemSize.height)
                            }
                        }
                    }
                }
            }
            .frame(height: 100)
        }
    }
    
    private func getItemSize(in size: CGSize) -> CGSize {
        let availableWidth = size.width - 30 // Account for labels
        return CGSize(width: max(6, availableWidth / 55), height: 10)
    }
    
    private func colorForValue(_ value: Int) -> Color {
        switch value {
        case 0: return TaskerTheme.Colors.textTertiary.opacity(0.2)
        case 1: return TaskerTheme.Colors.coral.opacity(0.3)
        case 2: return TaskerTheme.Colors.coral.opacity(0.5)
        case 3: return TaskerTheme.Colors.coral.opacity(0.7)
        default: return TaskerTheme.Colors.coral
        }
    }
}

//
//  ComparisonCardView.swift
//  Tasker
//
//  Line graph comparing this week vs last week.
//

import SwiftUI

public struct ComparisonCardView: View {
    public let thisWeek: [Int]
    public let lastWeek: [Int]
    
    public init(thisWeek: [Int] = [45, 32, 67, 23, 55, 48, 51], lastWeek: [Int] = [38, 28, 42, 35, 40, 36, 44]) {
        self.thisWeek = thisWeek
        self.lastWeek = lastWeek
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week vs Last Week")
                .font(.headline)
            
            HStack(spacing: 20) {
                ChartLine(data: thisWeek, color: .green, label: "This Week")
                ChartLine(data: lastWeek, color: .gray.opacity(0.5), label: "Last Week")
            }
            .frame(height: 60)
            
            HStack {
                Label("+12%", systemImage: "arrow.up")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
    }
}

struct ChartLine: View {
    let data: [Int]
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                GeometryReader { geo in
                    Path { path in
                        let max = data.max() ?? 1
                        let step = geo.size.width / CGFloat(data.count - 1)
                        
                        var x: CGFloat = 0
                        path.move(to: CGPoint(x: x, y: geo.size.height - CGFloat(data[0]) / CGFloat(max) * geo.size.height))
                        
                        for i in 1..<data.count {
                            x = CGFloat(i) * step
                            let y = geo.size.height - CGFloat(data[i]) / CGFloat(max) * geo.size.height
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 60)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(color)
        }
    }
}

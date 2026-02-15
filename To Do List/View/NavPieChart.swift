//
//  NavPieChart.swift
//  Tasker
//
//  Compact navigation bar pie chart showing today's score.
//  SwiftUI replacement for legacy TinyPieChart (DGCharts).
//

import SwiftUI

// MARK: - Nav Pie Chart

/// Compact pie chart for navigation bar showing today's score.
/// Displays score in center with priority-colored segments.
public struct NavPieChart: View {
    let score: Int
    let maxScore: Int
    var onTap: (() -> Void)? = nil

    @State private var animatedProgress: Double = 0

    private let size: CGFloat = 32
    private let ringWidth: CGFloat = 4
    private let gapAngle: Double = 8 // degrees

    public init(score: Int, maxScore: Int = 18, onTap: (() -> Void)? = nil) {
        self.score = score
        self.maxScore = maxScore
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        Color.tasker.surfaceSecondary,
                        lineWidth: ringWidth
                    )

                // Progress arc
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.tasker.accentPrimary,
                                Color.tasker.accentSecondary,
                                Color.tasker.accentPrimary
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Score text
                Text("\(score)")
                    .font(.system(size: scoreFont, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.tasker.accentPrimary)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today's score: \(score) points")
        .accessibilityHint("Double tap to view analytics")
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progressRatio
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                animatedProgress = min(1, Double(newScore) / Double(maxScore))
            }
        }
    }

    private var progressRatio: Double {
        min(1, Double(score) / Double(maxScore))
    }

    private var scoreFont: CGFloat {
        score >= 10 ? 11 : 13
    }
}

// MARK: - Nav Pie Chart with Priority Breakdown

/// Enhanced pie chart with priority-colored segments.
public struct NavPieChartDetailed: View {
    let score: Int
    let priorityBreakdown: [Int32: Int] // priority raw value -> count
    var onTap: (() -> Void)? = nil

    @State private var animatedScales: [CGFloat] = [0, 0, 0, 0]

    private let size: CGFloat = 36
    private let ringWidth: CGFloat = 5

    // Priority colors in order: None, Low, High, Max
    private var segmentColors: [Color] {
        [
            Color.tasker.priorityNone,
            Color.tasker.priorityLow,
            Color.tasker.priorityHigh,
            Color.tasker.priorityMax
        ]
    }

    public init(score: Int, priorityBreakdown: [Int32: Int], onTap: (() -> Void)? = nil) {
        self.score = score
        self.priorityBreakdown = priorityBreakdown
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: { onTap?() }) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        Color.tasker.surfaceSecondary,
                        lineWidth: ringWidth
                    )

                // Priority segments
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: segmentStops),
                            center: .center
                        ),
                        lineWidth: ringWidth
                    )
                    .scaleEffect(animatedScales[0])

                // Score text
                Text("\(score)")
                    .font(.system(size: scoreFont, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.tasker.accentPrimary)
            }
            .frame(width: size, height: size)
            .shadow(
                color: Color.tasker.accentPrimary.opacity(0.2),
                radius: 2,
                x: 0,
                y: 1
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today's score: \(score) points")
        .onAppear {
            animateSegments()
        }
    }

    private var totalTasks: Int {
        priorityBreakdown.values.reduce(0, +)
    }

    private var segmentGradientColors: [Color] {
        guard totalTasks > 0 else { return [Color.clear] }
        var colors: [Color] = []

        // Build colors for each segment
        for (index, priority) in [Int32(1), Int32(2), Int32(3), Int32(4)].enumerated() {
            let count = priorityBreakdown[priority] ?? 0
            if count > 0 {
                colors.append(segmentColors[index])
            }
        }

        return colors.isEmpty ? [Color.tasker.accentMuted] : colors
    }

    private var segmentStops: [Gradient.Stop] {
        guard totalTasks > 0 else {
            return [Gradient.Stop(color: .clear, location: 0)]
        }

        var stops: [Gradient.Stop] = []
        var location: Double = 0

        for (index, priority) in [Int32(1), Int32(2), Int32(3), Int32(4)].enumerated() {
            let count = priorityBreakdown[priority] ?? 0
            if count > 0 {
                let segmentRatio = Double(count) / Double(totalTasks)
                stops.append(Gradient.Stop(color: segmentColors[index], location: location))
                location += segmentRatio
                stops.append(Gradient.Stop(color: segmentColors[index], location: location))
            }
        }

        return stops.isEmpty ? [Gradient.Stop(color: Color.tasker.accentMuted, location: 0)] : stops
    }

    private func animateSegments() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
            animatedScales = [1, 1, 1, 1]
        }
    }

    private var scoreFont: CGFloat {
        score >= 10 ? 12 : 14
    }
}

// MARK: - Preview

#if DEBUG
struct NavPieChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Basic progress pie
            HStack(spacing: 16) {
                NavPieChart(score: 0)
                NavPieChart(score: 5)
                NavPieChart(score: 12)
                NavPieChart(score: 18)
            }

            Divider()

            // Detailed with priority breakdown
            NavPieChartDetailed(
                score: 15,
                priorityBreakdown: [1: 2, 2: 3, 3: 2, 4: 1]
            )

            Text("Detailed chart with priority breakdown")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif

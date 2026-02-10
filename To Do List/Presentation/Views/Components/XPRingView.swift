//
//  XPRingView.swift
//  Tasker
//
//  Animated progress ring view for displaying daily XP progress.
//  Features custom spring physics animation and level display.
//

import SwiftUI

// MARK: - XP Ring View

/// Animated progress ring showing daily XP progress toward goal
public struct XPRingView: View {
    // MARK: - Properties

    /// Current XP earned today
    public var currentXP: Int

    /// Daily XP goal
    public var goalXP: Int

    /// Whether to animate the progress
    public var animate: Bool = true

    /// Ring thickness
    public var thickness: CGFloat = 8

    /// Ring size
    public var size: CGFloat = 60

    /// Primary accent color
    public var accentColor: Color = TaskerTheme.Colors.xpGold

    /// Background track color
    public var trackColor: Color = TaskerTheme.Colors.xpGoldLight.opacity(0.3)

    /// Animation state
    @State private var progress: Double = 0
    @State private var scale: CGFloat = 1.0

    // MARK: - Computed Properties

    /// Progress percentage (0.0 to 1.0)
    private var progressPercentage: Double {
        guard goalXP > 0 else { return 0 }
        return min(Double(currentXP) / Double(goalXP), 1.0)
    }

    /// Display text for the ring
    private var displayText: String {
        "\(currentXP)"
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(trackColor, lineWidth: thickness)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(
                        lineWidth: thickness,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(animate ? springAnimation : .default, value: progress)

            // Center content
            VStack(spacing: 2) {
                Text(displayText)
                    .font(.tasker(.title2))
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                    .minimumScaleFactor(0.5)

                Text("XP")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)
            }
            .scaleEffect(scale)
            .animation(animate ? springAnimation : .default, value: currentXP)
        }
        .onAppear {
            if animate {
                updateProgress()
            }
        }
        .onChange(of: currentXP) { _ in
            if animate {
                updateProgress()
                triggerHaptic()
            }
        }
    }

    // MARK: - Animation

    /// Custom spring animation
    private var springAnimation: Animation {
        .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.2)
    }

    /// Update progress with animation
    private func updateProgress() {
        withAnimation(springAnimation) {
            progress = progressPercentage
        }

        // Subtle scale effect
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.05
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
            }
        }
    }

    /// Trigger haptic feedback on XP change
    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Stroke Shape

/// Custom stroke shape for rounded line caps
struct StrokeShape: InsettableShape {
    var inset: CGFloat = 0
    let lineWidth: CGFloat
    let lineCap: CGLineCap

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - inset - lineWidth / 2

        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        return path.strokedPath(StrokeStyle(
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: .round,
            miterLimit: 0
        ))
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

// MARK: - XP Ring Header View

/// Header-style XP ring with label
public struct XPRingHeaderView: View {
    public var currentXP: Int
    public var goalXP: Int
    public var title: String = "Today"

    public init(currentXP: Int, goalXP: Int, title: String = "Today") {
        self.currentXP = currentXP
        self.goalXP = goalXP
        self.title = title
    }

    public var body: some View {
        HStack(spacing: TaskerTheme.Spacing.md) {
            XPRingView(
                currentXP: currentXP,
                goalXP: goalXP,
                thickness: 7,
                size: 56
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TaskerTheme.Typography.captionSemibold)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)
                    .textCase(.uppercase)

                Text("\(goalXP - currentXP) more to goal")
                    .font(TaskerTheme.Typography.bodyMedium)
                    .foregroundColor(TaskerTheme.Colors.textPrimary)

                ProgressView(value: Double(currentXP), total: Double(goalXP))
                    .progressViewStyle(.linear)
                    .tint(TaskerTheme.Colors.xpGold)
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }
        }
        .padding(TaskerTheme.Spacing.md)
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.lg)
    }
}

// MARK: - Preview

#if DEBUG
struct XPRingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: TaskerTheme.Spacing.xl) {
            // Empty state
            XPRingView(currentXP: 0, goalXP: 100)
                .previewDisplayName("Empty")

            // Partial progress
            XPRingView(currentXP: 42, goalXP: 100)
                .previewDisplayName("42%")

            // Goal reached
            XPRingView(currentXP: 100, goalXP: 100)
                .previewDisplayName("Complete")

            // Header style
            XPRingHeaderView(currentXP: 42, goalXP: 100)
                .previewDisplayName("Header Style")
        }
        .padding()
        .background(TaskerTheme.Colors.background)
    }
}
#endif

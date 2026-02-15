//
//  CelebrationEffects.swift
//  Tasker
//
//  Micro-interactions and celebration effects for task completion.
//

import SwiftUI

// MARK: - XP Celebration View

/// Animated celebration view that appears when XP is earned.
public struct XPCelebrationView: View {
    let xpValue: Int
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 0
    @State private var particles: [Particle] = []

    public init(xpValue: Int, isPresented: Binding<Bool>) {
        self.xpValue = xpValue
        self._isPresented = isPresented
    }

    public var body: some View {
        if isPresented {
            ZStack {
                // Particles
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }

                // Main XP badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Text("+\(xpValue)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("XP")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.tasker.accentPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .offset(y: yOffset)
            }
            .onAppear {
                performAnimation()
            }
        }
    }

    private func performAnimation() {
        // Generate particles
        particles = (0..<12).map { _ in
            Particle(
                x: CGFloat.random(in: -40...40),
                y: CGFloat.random(in: -20...20),
                size: CGFloat.random(in: 4...8),
                color: [Color.tasker.accentPrimary, Color.tasker.accentSecondary, .yellow].randomElement()!,
                opacity: 1
            )
        }

        // Entrance animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scale = 1
            opacity = 1
        }

        // Rise and fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                yOffset = -60
                opacity = 0
            }

            // Animate particles outward
            for i in particles.indices {
                withAnimation(.easeOut(duration: 0.6).delay(Double(i) * 0.02)) {
                    particles[i].y -= 80
                    particles[i].opacity = 0
                }
            }
        }

        // Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            isPresented = false
            scale = 0.5
            opacity = 0
            yOffset = 0
            particles = []
        }
    }
}

// MARK: - Particle Model

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Streak Celebration View

/// Celebration view for streak achievements.
public struct StreakCelebrationView: View {
    let streakDays: Int
    @Binding var isPresented: Bool

    @State private var flameScale: CGFloat = 0.3
    @State private var flameOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5

    public init(streakDays: Int, isPresented: Binding<Bool>) {
        self.streakDays = streakDays
        self._isPresented = isPresented
    }

    public var body: some View {
        if isPresented {
            ZStack {
                // Expanding ring
                Circle()
                    .stroke(Color.tasker.accentSecondary.opacity(0.3), lineWidth: 3)
                    .frame(width: 80, height: 80)
                    .scaleEffect(ringScale)
                    .opacity(1 - ringScale)

                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.orange)
                        .scaleEffect(flameScale)
                        .opacity(flameOpacity)
                        .symbolEffect(.bounce, options: .repeating.speed(0.5), isActive: true)

                    Text("\(streakDays) day streak!")
                        .font(.tasker(.caption1))
                        .fontWeight(.semibold)
                        .foregroundColor(Color.tasker.textSecondary)
                        .opacity(flameOpacity)
                }
            }
            .onAppear {
                performAnimation()
            }
        }
    }

    private func performAnimation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            flameScale = 1
            flameOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                flameOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isPresented = false
            flameScale = 0.3
            flameOpacity = 0
            ringScale = 0.5
        }
    }
}

// MARK: - Task Complete Animation Modifier

/// Modifier that adds completion animation to any view.
public struct TaskCompleteAnimationModifier: ViewModifier {
    let isComplete: Bool
    @State private var bounceAmount: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .scaleEffect(1 + bounceAmount)
            .onChange(of: isComplete) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                        bounceAmount = 0.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            bounceAmount = 0
                        }
                    }
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Adds completion animation effect.
    public func taskCompleteAnimation(isComplete: Bool) -> some View {
        modifier(TaskCompleteAnimationModifier(isComplete: isComplete))
    }
}

// MARK: - Preview

#if DEBUG
struct CelebrationEffects_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // XP Celebration
            XPCelebrationView(xpValue: 7, isPresented: .constant(true))

            // Streak Celebration
            StreakCelebrationView(streakDays: 7, isPresented: .constant(true))
        }
        .padding(40)
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif

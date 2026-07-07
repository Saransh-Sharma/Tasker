//
//  LBDelight.swift
//  LifeBoard
//
//  Max-delight motion primitives for the Sunrise Glass polish pass.
//  Celebrations are event-gated (first completion of the day, streak
//  milestones) — never fired on every tap. Every primitive collapses to
//  a no-op under Reduce Motion, UI testing, and scroll-optimized rendering.
//

import SwiftUI

// MARK: - Celebration Burst

/// A one-shot radial burst of role-tinted glyphs (~700ms), rendered with
/// `Canvas` so particles never participate in layout. Overlay it on the
/// celebrating view and bump `trigger` to fire.
struct LBCelebrationBurst: View {
    let trigger: Int
    var tint: Color = LBColorTokens.leaf

    @State private var firedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimized

    private static let particleCount = 12
    private static let duration: TimeInterval = 0.7

    var body: some View {
        ZStack {
            if let firedAt, delightMotionEnabled {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(firedAt)
                        guard elapsed >= 0, elapsed < Self.duration else { return }
                        let progress = elapsed / Self.duration
                        let eased = 1 - pow(1 - progress, 3)
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let travel = min(size.width, size.height) * 0.9

                        for particle in 0..<Self.particleCount {
                            let seed = Double(particle)
                            let angle = (seed / Double(Self.particleCount)) * 2 * .pi
                                + sin(seed * 7.13) * 0.35
                            let distance = travel * (0.55 + 0.45 * sin(seed * 3.7).magnitude) * eased
                            let position = CGPoint(
                                x: center.x + cos(angle) * distance,
                                y: center.y + sin(angle) * distance - 10 * eased
                            )
                            let glyph = particle.isMultiple(of: 3) ? "sparkle" : "leaf.fill"
                            let fontSize = 9 + sin(seed * 5.3).magnitude * 5
                            var resolved = context.resolve(
                                Text(Image(systemName: glyph))
                                    .font(.system(size: fontSize))
                                    .foregroundStyle(tint)
                            )
                            resolved.shading = .color(tint.opacity(1 - progress))
                            context.translateBy(x: position.x, y: position.y)
                            context.rotate(by: .radians(angle * 0.4 + eased * 1.6))
                            context.draw(resolved, at: .zero)
                            context.transform = .identity
                        }
                    }
                }
                .allowsHitTesting(false)
                .transition(.identity)
            }
        }
        .onChange(of: trigger) { _, _ in
            guard trigger > 0, delightMotionEnabled else { return }
            firedAt = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration) {
                if let firedAt, Date().timeIntervalSince(firedAt) >= Self.duration {
                    self.firedAt = nil
                }
            }
        }
    }

    private var delightMotionEnabled: Bool {
        LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false && scrollOptimized == false
    }
}

// MARK: - Animated Sheen

/// A slow, ambient diagonal light sweep for primary CTAs. Far subtler than
/// a loading shimmer: one pass every few seconds, masked to the content.
private struct LBAnimatedSheen: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimized

    func body(content: Content) -> some View {
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) || scrollOptimized {
            content
        } else {
            content
                .overlay(
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.14),
                                .white.opacity(0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                )
                .onAppear {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

// MARK: - Ripple Pop

/// One-shot scale pop with a per-index delay, so a row of cells reads as a
/// wave (40ms/cell) when a check-in lands. Bump `trigger` to fire.
private struct LBRipplePop: ViewModifier {
    let trigger: Int
    let index: Int
    @State private var popped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimized

    func body(content: Content) -> some View {
        content
            .scaleEffect(popped ? 1.12 : 1.0)
            .onChange(of: trigger) { _, _ in
                guard trigger > 0,
                      LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false,
                      scrollOptimized == false else { return }
                let delay = Double(index) * LifeBoardAnimation.staggerInterval
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(LifeBoardAnimation.habitFill) { popped = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(LifeBoardAnimation.habitFill) { popped = false }
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Overlays a one-shot celebration burst; bump `trigger` to fire.
    /// Reserve for event-gated moments (first completion of the day,
    /// streak milestones) — not every interaction.
    func lbCelebrationBurst(trigger: Int, tint: Color = LBColorTokens.leaf) -> some View {
        overlay(LBCelebrationBurst(trigger: trigger, tint: tint))
    }

    /// Ambient diagonal light sweep for primary CTAs.
    func lbAnimatedSheen() -> some View {
        modifier(LBAnimatedSheen())
    }

    /// One-shot scale pop delayed by `index`, forming a ripple across a row.
    func lbRipplePop(trigger: Int, index: Int) -> some View {
        modifier(LBRipplePop(trigger: trigger, index: index))
    }
}

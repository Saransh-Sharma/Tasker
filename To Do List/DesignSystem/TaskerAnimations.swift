//
//  TaskerAnimations.swift
//  Tasker
//
//  Reusable animation tokens and ViewModifiers for the "Obsidian & Gold" premium feel.
//  Spring physics everywhere, staggered reveals, haptic helpers.
//

import SwiftUI
import UIKit

// MARK: - Animation Tokens

@MainActor
public enum TaskerAnimation {
    // Spring configs — SwiftUI
    public static let snappy: Animation = .spring(response: 0.35, dampingFraction: 0.75)
    public static let gentle: Animation = .spring(response: 0.5, dampingFraction: 0.8)
    public static let bouncy: Animation = .spring(response: 0.4, dampingFraction: 0.6)
    public static let quick: Animation = .spring(response: 0.25, dampingFraction: 0.85)
    public static let micro: Animation = .spring(response: 0.20, dampingFraction: 0.90)
    public static let expressive: Animation = .spring(response: 0.55, dampingFraction: 0.65)
    public static let ambient: Animation = .easeInOut(duration: 2.0)

    // UIKit spring parameters
    public static let uiSnappy = (duration: 0.4, damping: CGFloat(0.75), velocity: CGFloat(0.5))
    public static let uiGentle = (duration: 0.6, damping: CGFloat(0.8), velocity: CGFloat(0.3))
    public static let uiBouncy = (duration: 0.5, damping: CGFloat(0.6), velocity: CGFloat(0.6))
    public static let uiMicro = (duration: 0.25, damping: CGFloat(0.90), velocity: CGFloat(0.4))
    public static let uiExpressive = (duration: 0.65, damping: CGFloat(0.65), velocity: CGFloat(0.5))

    // Stagger delay per item (seconds)
    public static let staggerInterval: Double = 0.04
}

// MARK: - Staggered Appearance Modifier

public struct StaggeredAppearance: ViewModifier {
    let index: Int
    let totalItems: Int
    /// Initializes a new instance.
    @State private var appeared = false

    public init(index: Int, totalItems: Int = 20) {
        self.index = index
        self.totalItems = totalItems
    }

    /// Executes body.
    public func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(
                TaskerAnimation.gentle.delay(Double(index) * TaskerAnimation.staggerInterval),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

// MARK: - Enhanced Staggered Appearance Modifier

public struct EnhancedStaggeredAppearance: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.taskerLayoutClass) private var layoutClass

    public init(index: Int) {
        self.index = index
    }

    public func body(content: Content) -> some View {
        if reduceMotion || (layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled) {
            return AnyView(content)
        }

        return AnyView(
            content
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)
                .offset(y: appeared ? 0 : 16)
                .animation(
                    TaskerAnimation.gentle.delay(Double(index) * TaskerAnimation.staggerInterval),
                    value: appeared
                )
                .onAppear { appeared = true }
        )
    }
}

// MARK: - Breathing Pulse Modifier

public struct BreathingPulse: ViewModifier {
    let minOpacity: Double
    let maxOpacity: Double
    let duration: Double
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(min: Double = 0.7, max: Double = 1.0, duration: Double = 2.0) {
        self.minOpacity = min
        self.maxOpacity = max
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? maxOpacity : (isPulsing ? maxOpacity : minOpacity))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Task Completion Transition Modifier

public struct TaskCompletionTransition: ViewModifier {
    let isComplete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .opacity(isComplete ? 0.55 : 1.0)
            .scaleEffect(isComplete ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : TaskerAnimation.gentle, value: isComplete)
    }
}

// MARK: - Active Glow Modifier

public struct ActiveGlow: ViewModifier {
    let isActive: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isActive: Bool, color: Color) {
        self.isActive = isActive
        self.color = color
    }

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(0.25) : .clear,
                radius: isActive ? 8 : 0
            )
            .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isActive)
    }
}

// MARK: - Card Press Effect Modifier

public struct CardPressEffect: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: .black.opacity(isPressed ? 0.04 : 0.08),
                radius: isPressed ? 4 : 8
            )
            .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Scale on Press Modifier

public struct ScaleOnPress: ViewModifier {
    /// Executes body.
    public func body(content: Content) -> some View {
        content
            .buttonStyle(TaskerScaleOnPressButtonStyle())
    }
}

private struct TaskerScaleOnPressButtonStyle: ButtonStyle {
    /// Executes makeBody.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(TaskerAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Shimmer Effect Modifier

public struct ShimmerEffect: ViewModifier {
    /// Executes body.
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .white.opacity(0),
                        .white.opacity(0.08),
                        .white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = UIScreen.main.bounds.width
                }
            }
    }
}

// MARK: - View Extensions

public extension View {
    func staggeredAppearance(index: Int, totalItems: Int = 20) -> some View {
        modifier(StaggeredAppearance(index: index, totalItems: totalItems))
    }

    func enhancedStaggeredAppearance(index: Int) -> some View {
        modifier(EnhancedStaggeredAppearance(index: index))
    }

    func breathingPulse(min: Double = 0.7, max: Double = 1.0, duration: Double = 2.0) -> some View {
        modifier(BreathingPulse(min: min, max: max, duration: duration))
    }

    func taskCompletionTransition(isComplete: Bool) -> some View {
        modifier(TaskCompletionTransition(isComplete: isComplete))
    }

    func activeGlow(isActive: Bool, color: Color) -> some View {
        modifier(ActiveGlow(isActive: isActive, color: color))
    }

    func cardPressEffect() -> some View {
        modifier(CardPressEffect())
    }

    func scaleOnPress() -> some View {
        modifier(ScaleOnPress())
    }

    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }

    func bellShake(trigger: Binding<Bool>) -> some View {
        modifier(BellShake(trigger: trigger))
    }
}

// MARK: - Bell Shake Modifier

public struct BellShake: ViewModifier {
    /// Executes body.
    @Binding var trigger: Bool
    @State private var shaking = false

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(shaking ? 15 : 0))
            .animation(
                shaking
                    ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3)
                    : .default,
                value: shaking
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    shaking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shaking = false
                    }
                }
            }
    }
}

// MARK: - UIKit Spring Helpers

public extension UIView {
    /// Executes taskerSpringAnimate.
    @MainActor
    static func taskerSpringAnimate(
        _ params: (duration: Double, damping: CGFloat, velocity: CGFloat)? = nil,
        delay: TimeInterval = 0,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        let resolvedParams = params ?? TaskerAnimation.uiSnappy
        UIView.animate(
            withDuration: resolvedParams.duration,
            delay: delay,
            usingSpringWithDamping: resolvedParams.damping,
            initialSpringVelocity: resolvedParams.velocity,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: animations,
            completion: completion
        )
    }
}

// MARK: - Haptic Helpers

@MainActor
public enum TaskerFeedback {
    public static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

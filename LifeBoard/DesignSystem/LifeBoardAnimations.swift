//
//  LifeBoardAnimations.swift
//  LifeBoard
//
//  Reusable animation tokens and ViewModifiers for the Sarvam-inspired single-brand system.
//  Supports calm transitions, staggered reveals, and shared haptic helpers.
//

import SwiftUI
import UIKit

// MARK: - Animation Tokens

@MainActor
public enum LifeBoardAnimation {
    public static let press: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.09)
    public static let feedbackFast: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.14)
    public static let stateChange: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.22)
    public static let panelIn: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.28)
    public static let panelOut: Animation = .timingCurve(0.25, 1, 0.5, 1, duration: 0.22)
    public static let heroReveal: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.36)
    public static let celebration: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.54)
    public static let gatewayReveal: Animation = .timingCurve(0.16, 1, 0.3, 1, duration: 0.38)
    public static let exit: Animation = panelOut
    public static let ctaConfirmation: Animation = .timingCurve(0.25, 1, 0.5, 1, duration: 0.32)
    public static let numericUpdate: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.34)
    public static let heroEmphasis: Animation = .timingCurve(0.16, 1, 0.3, 1, duration: 0.42)

    // Backward-compatible aliases
    public static let snappy: Animation = stateChange
    public static let gentle: Animation = heroReveal
    public static let bouncy: Animation = celebration
    public static let quick: Animation = feedbackFast
    public static let micro: Animation = feedbackFast
    public static let expressive: Animation = celebration
    public static let ambient: Animation = .easeInOut(duration: 1.4)

    // UIKit parameters
    public static let uiPress = (duration: 0.09, damping: CGFloat(1.0), velocity: CGFloat(0.0))
    public static let uiFeedbackFast = (duration: 0.14, damping: CGFloat(0.96), velocity: CGFloat(0.08))
    public static let uiStateChange = (duration: 0.22, damping: CGFloat(0.94), velocity: CGFloat(0.10))
    public static let uiHeroReveal = (duration: 0.36, damping: CGFloat(0.92), velocity: CGFloat(0.12))
    public static let uiCelebration = (duration: 0.54, damping: CGFloat(0.90), velocity: CGFloat(0.16))
    public static let uiGatewayReveal = (duration: 0.38, damping: CGFloat(0.92), velocity: CGFloat(0.12))

    // Backward-compatible aliases
    public static let uiSnappy = uiStateChange
    public static let uiGentle = uiHeroReveal
    public static let uiBouncy = uiCelebration
    public static let uiMicro = uiFeedbackFast
    public static let uiExpressive = uiCelebration

    // Stagger delay per item (seconds)
    public static let staggerInterval: Double = 0.04

    // Sunrise Glass motion spec (design doc lines 414-430)
    public static let chipSelection: Animation = .spring(response: 0.20, dampingFraction: 0.86)
    public static let dateChange: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.28)
    public static let habitFill: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.18)

    // Entrance stagger stops compounding past this index so long lists settle quickly.
    public static let entranceStaggerCap: Int = 6

    public static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UI_TESTING")
    }

    public static var areProcessAnimationsDisabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-UI_TESTING") || arguments.contains("-DISABLE_ANIMATIONS")
    }

    public static func animationsDisabled(reduceMotion: Bool) -> Bool {
        reduceMotion || areProcessAnimationsDisabled
    }
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
                LifeBoardAnimation.gentle.delay(Double(index) * LifeBoardAnimation.staggerInterval),
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
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    public init(index: Int) {
        self.index = index
    }

    public func body(content: Content) -> some View {
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion)
            || (layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled) {
            return AnyView(content)
        }

        return AnyView(
            content
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)
                .offset(y: appeared ? 0 : 16)
                .animation(
                    LifeBoardAnimation.gentle.delay(Double(index) * LifeBoardAnimation.staggerInterval),
                    value: appeared
                )
                .onAppear { appeared = true }
        )
    }
}

// MARK: - Card Entrance Modifier

/// Fade + 8pt rise entrance per the Sunrise Glass card-entrance spec, with a capped stagger.
/// Entrance is keyed to `onAppear` only — callers embedding this inside a periodically
/// refreshing container (e.g. `TimelineView`) must scope identity so ticks don't re-trigger it.
public struct CardEntrance: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(index: Int) {
        self.index = index
    }

    public func body(content: Content) -> some View {
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
            content
        } else {
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(
                    LifeBoardAnimation.stateChange.delay(
                        Double(min(index, LifeBoardAnimation.entranceStaggerCap)) * LifeBoardAnimation.staggerInterval
                    ),
                    value: appeared
                )
                .onAppear { appeared = true }
        }
    }
}

// MARK: - Completion Celebration Modifier

/// The single shared "success moment": brief scale swell + tint-deepened glow.
/// This is the only place that fires the success haptic, keeping the haptic
/// budget (success = explicit completion only) enforced structurally.
public struct CompletionCelebration: ViewModifier {
    let isComplete: Bool
    let tint: Color
    @State private var swell = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isComplete: Bool, tint: Color) {
        self.isComplete = isComplete
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(swell ? 1.06 : 1.0)
            .shadow(
                color: swell ? tint.opacity(0.30) : .clear,
                radius: swell ? 10 : 0
            )
            .onChange(of: isComplete) { _, newValue in
                guard newValue else { return }
                LifeBoardFeedback.success()
                guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else { return }
                withAnimation(LifeBoardAnimation.celebration) { swell = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.27) {
                    withAnimation(LifeBoardAnimation.celebration) { swell = false }
                }
            }
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
            .opacity(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? maxOpacity : (isPulsing ? maxOpacity : minOpacity))
            .onAppear {
                guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false, minOpacity != maxOpacity else { return }
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
            .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.gentle, value: isComplete)
    }
}

// MARK: - Active Glow Modifier

public struct ActiveGlow: ViewModifier {
    let isActive: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimizedRendering

    public init(isActive: Bool, color: Color) {
        self.isActive = isActive
        self.color = color
    }

    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive && scrollOptimizedRendering == false ? color.opacity(0.25) : .clear,
                radius: isActive && scrollOptimizedRendering == false ? 8 : 0
            )
            .animation((LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) || scrollOptimizedRendering) ? nil : LifeBoardAnimation.quick, value: isActive)
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
            .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.quick, value: isPressed)
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
            .buttonStyle(LifeBoardScaleOnPressButtonStyle())
    }
}

private struct LifeBoardScaleOnPressButtonStyle: ButtonStyle {
    /// Executes makeBody.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && LifeBoardAnimation.areProcessAnimationsDisabled == false ? 0.97 : 1.0)
            .animation(LifeBoardAnimation.areProcessAnimationsDisabled ? nil : LifeBoardAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Shimmer Effect Modifier

public struct ShimmerEffect: ViewModifier {
    /// Executes body.
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
            content
        } else {
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
}

// MARK: - View Extensions

public extension View {
    func staggeredAppearance(index: Int, totalItems: Int = 20) -> some View {
        modifier(StaggeredAppearance(index: index, totalItems: totalItems))
    }

    func cardEntrance(index: Int) -> some View {
        modifier(CardEntrance(index: index))
    }

    func completionCelebration(isComplete: Bool, tint: Color) -> some View {
        modifier(CompletionCelebration(isComplete: isComplete, tint: tint))
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

    func lifeboardSuccessPulse(isActive: Bool) -> some View {
        modifier(LifeBoardSuccessPulse(isActive: isActive))
    }
}

// MARK: - Bell Shake Modifier

public struct BellShake: ViewModifier {
    /// Executes body.
    @Binding var trigger: Bool
    @State private var shaking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(shaking && LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false ? 15 : 0))
            .animation(
                shaking && LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false
                    ? .spring(response: 0.15, dampingFraction: 0.3).repeatCount(3)
                    : nil,
                value: shaking
            )
            .onChange(of: trigger) { _, newValue in
                if newValue, LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false {
                    shaking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shaking = false
                    }
                }
            }
    }
}

public struct LifeBoardSuccessPulse: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false ? 1.015 : 1)
            .shadow(
                color: isActive ? Color.lifeboard.statusSuccess.opacity(reduceMotion ? 0.12 : 0.24) : .clear,
                radius: isActive ? (reduceMotion ? 4 : 12) : 0
            )
            .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.ctaConfirmation, value: isActive)
    }
}

// MARK: - UIKit Spring Helpers

public extension UIView {
    /// Executes lifeboardSpringAnimate.
    @MainActor
    static func lifeboardSpringAnimate(
        _ params: (duration: Double, damping: CGFloat, velocity: CGFloat)? = nil,
        delay: TimeInterval = 0,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        let resolvedParams = params ?? LifeBoardAnimation.uiSnappy
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
public enum LifeBoardFeedback {
    public static func light() {
        guard isHapticFeedbackAvailable else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func medium() {
        guard isHapticFeedbackAvailable else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func heavy() {
        guard isHapticFeedbackAvailable else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    public static func success() {
        guard isHapticFeedbackAvailable else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public static func warning() {
        guard isHapticFeedbackAvailable else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    public static func error() {
        guard isHapticFeedbackAvailable else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    public static func selection() {
        guard isHapticFeedbackAvailable else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private static var isHapticFeedbackAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return true
        #endif
    }
}

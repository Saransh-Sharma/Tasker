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

    // UIKit spring parameters
    public static let uiSnappy = (duration: 0.4, damping: CGFloat(0.75), velocity: CGFloat(0.5))
    public static let uiGentle = (duration: 0.6, damping: CGFloat(0.8), velocity: CGFloat(0.3))
    public static let uiBouncy = (duration: 0.5, damping: CGFloat(0.6), velocity: CGFloat(0.6))

    // Stagger delay per item (seconds)
    public static let staggerInterval: Double = 0.04
}

// MARK: - Staggered Appearance Modifier

public struct StaggeredAppearance: ViewModifier {
    let index: Int
    let totalItems: Int
    @State private var appeared = false

    public init(index: Int, totalItems: Int = 20) {
        self.index = index
        self.totalItems = totalItems
    }

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

// MARK: - Scale on Press Modifier

public struct ScaleOnPress: ViewModifier {
    @State private var isPressed = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(TaskerAnimation.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Shimmer Effect Modifier

public struct ShimmerEffect: ViewModifier {
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

    func scaleOnPress() -> some View {
        modifier(ScaleOnPress())
    }

    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - UIKit Spring Helpers

public extension UIView {
    @MainActor
    static func taskerSpringAnimate(
        _ params: (duration: Double, damping: CGFloat, velocity: CGFloat) = TaskerAnimation.uiSnappy,
        delay: TimeInterval = 0,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        UIView.animate(
            withDuration: params.duration,
            delay: delay,
            usingSpringWithDamping: params.damping,
            initialSpringVelocity: params.velocity,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: animations,
            completion: completion
        )
    }
}

// MARK: - Haptic Helpers

@MainActor
public enum TaskerHaptic {
    public static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

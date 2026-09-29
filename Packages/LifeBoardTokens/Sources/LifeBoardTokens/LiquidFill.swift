import SwiftUI
import UIKit

// MARK: - Liquid fill (ported wave surface)

/// A sine-wave liquid surface. Mask it to any shape and drive `level`
/// (0 = empty, 1 = full); the surface ripples gently via `TimelineView`
/// unless Reduce Motion or Low Power renders it as a still fill.
public struct LiquidWaveShape: Shape {
    public var phase: CGFloat
    public var level: CGFloat
    public let amplitude: CGFloat
    public let frequency: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, level) }
        set {
            phase = newValue.first
            level = newValue.second
        }
    }

    public init(phase: CGFloat, level: CGFloat, amplitude: CGFloat = 3, frequency: CGFloat = 2.2) {
        self.phase = phase
        self.level = min(1, max(0, level))
        self.amplitude = amplitude
        self.frequency = frequency
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let surfaceY = rect.height * (1 - level)
        path.move(to: CGPoint(x: rect.width, y: rect.height * 2))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 2))
        var x: CGFloat = 0
        while x <= rect.width {
            let y = sin(((x / max(1, rect.width)) + phase) * frequency * .pi) * amplitude + surfaceY
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 2))
        path.closeSubpath()
        return path
    }
}

/// Progress rendered as liquid rising inside the masked container. Used by
/// hydration and fasting surfaces; falls back to a static fill under Reduce
/// Motion and Low Power Mode.
public struct LiquidFill: View {
    private let level: Double
    private let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(level: Double, tint: Color) {
        self.level = min(1, max(0, level))
        self.tint = tint
    }

    public var body: some View {
        if reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled {
            GeometryReader { proxy in
                tint.opacity(0.85)
                    .frame(height: proxy.size.height * level)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1 / 24)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let phase = CGFloat(time.truncatingRemainder(dividingBy: 4) / 4)
                ZStack {
                    LiquidWaveShape(phase: phase, level: level, amplitude: 2.6)
                        .fill(tint.opacity(0.4))
                    LiquidWaveShape(phase: phase + 0.35, level: max(0, level - 0.015), amplitude: 3.4)
                        .fill(tint.opacity(0.85))
                }
            }
        }
    }
}

//  Adapted from SwiftUI-Animations (https://github.com/anerma/SwiftUI-Animations)
//  `Circular Download/Support Shapes/DownloadWaveFill.swift`
//  Copyright © 2022 Shubham Singh. Licensed under the Apache License, Version 2.0.
//  See SwiftUI-Animations-NOTICE.txt.
//
//  Changes from the original: `level` is animatable alongside `phase` (the original
//  only rippled and was positioned by an external offset), the surface is derived
//  from the rect rather than a fixed `midY`, amplitude tapers to nothing as the
//  level approaches empty or full, and the sample step is resolution-aware.

import SwiftUI

/// A liquid surface that can be masked into any shape to show a fill level.
///
/// Built for the day ring, where it shows how much of the evening's reconciliation
/// has been decided. A ring that merely *counts* decisions is a progress bar with
/// extra steps; a level that visibly rises reads as the day settling.
///
/// Both `phase` and `level` animate. `phase` alone would ripple forever, which the
/// design law forbids — so callers advance `phase` **once per level change** and let
/// it come to rest. The ripple is the splash of the level moving, not a loop.
struct LifeBoardLiquidLevel: Shape {
    /// Horizontal phase of the surface, in wavelengths. Advancing it slides the crests.
    var phase: CGFloat
    /// 0 = empty, 1 = full.
    var level: CGFloat

    /// Crest height in points at mid-level.
    var amplitude: CGFloat = 3.5
    /// Number of crests across the width.
    var wavelengths: CGFloat = 1.6

    /// Both values animate together, so a level change carries its own ripple.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, level) }
        set {
            phase = newValue.first
            level = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = min(max(level, 0), 1)

        // A dead-flat surface at the extremes: an empty ring should not ripple, and
        // a full one should read as settled rather than still sloshing.
        let taper = sin(clamped * .pi)
        let crest = amplitude * taper

        // level 0 sits at the bottom edge, level 1 at the top.
        let surfaceY = rect.maxY - (rect.height * clamped)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))

        // 1pt steps are wasted on a 148pt ring and expensive on a large one; half a
        // point of arc is well under a pixel at 3x.
        let step = max(1, rect.width / 120)
        var x = rect.minX
        while x <= rect.maxX {
            let relative = (x - rect.minX) / max(rect.width, 1)
            let y = surfaceY + sin((relative * wavelengths + phase) * 2 * .pi) * crest
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        // Close along the far edge and back across the bottom so the fill is solid.
        let lastRelative: CGFloat = 1
        let lastY = surfaceY + sin((lastRelative * wavelengths + phase) * 2 * .pi) * crest
        path.addLine(to: CGPoint(x: rect.maxX, y: lastY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

/// Shared identifiers for the zoom transition into the day-loop rituals.
///
/// Named in one place because the source lives on Home and the destination
/// lives in the shell's route switch — two files that otherwise share nothing.
/// A typo in either would silently fall back to a plain push, which looks like
/// "the animation didn't work" rather than "the ids don't match".
public enum LifeBoardDayLoopTransition {
    public static let close = "route.dayClose"
    public static let open = "route.dayOpen"

    /// Resolves the id for a ritual route. Any other route gets the close id
    /// rather than crashing — a wrong-but-harmless transition beats a trap.
    public static func id(for route: AppRoute) -> String {
        switch route {
        case .dayOpen: open
        default: close
        }
    }
}

/// A vertical thread linking the acts of a ritual, filled to the act you have
/// reached.
///
/// Deliberately *not* a step indicator. The evening ritual is one scroll, not a
/// wizard — paging it would turn "I only wanted to write the line" into four
/// taps. But a scroll with no sense of extent gives you no way to judge whether
/// to start now or later. A thread answers that without ever telling you which
/// act you are supposed to be in.
public struct LifeBoardActThread: Shape {
    /// 0 = nothing settled, 1 = every act complete.
    public var progress: Double

    public init(progress: Double) {
        self.progress = progress
    }

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return path }
        let x = rect.midX
        path.move(to: CGPoint(x: x, y: rect.minY))
        path.addLine(to: CGPoint(x: x, y: rect.minY + rect.height * clamped))
        return path
    }
}

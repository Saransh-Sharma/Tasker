import SwiftUI

/// Where the current moment sits in the day, as an arc position.
///
/// The app already picks a celestial phase for its backdrop, but that only says
/// *which* part of the day it is — dawn and the last minute before noon both
/// read as "morning" and look identical. This turns the clock into a single
/// travelled fraction so the sun or moon can sit at a believable height, and so
/// two glances an hour apart differ.
public enum DaypartProgress {
    /// Fraction of the 24-hour day elapsed, in `0..<1`.
    ///
    /// Seconds are included: an indicator that only moved on the hour would sit
    /// visibly still, which reads as broken rather than calm.
    public static func dayProgress(at date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double((components.hour ?? 0) * 3_600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        return (seconds / 86_400).clampedToUnit
    }

    /// How far through its own phase the moment is, in `0...1`.
    ///
    /// Phases are unequal — night runs eight hours, golden hour two — so this
    /// normalises within the phase the moment actually falls in. Night wraps
    /// midnight, and is measured across the wrap rather than resetting at 00:00.
    public static func phaseProgress(at date: Date, calendar: Calendar = .current) -> Double {
        let hour = Double(calendar.component(.hour, from: date))
            + Double(calendar.component(.minute, from: date)) / 60
        let phase = CelestialPhase.resolve(at: date, calendar: calendar)
        let (start, length) = bounds(of: phase)
        // Night starts at 21:00 and runs to 05:00, so hours before dawn belong
        // to the previous evening's night and sit late in the phase, not early.
        let elapsed = hour >= start ? hour - start : hour + 24 - start
        guard length > 0 else { return 0 }
        return (elapsed / length).clampedToUnit
    }

    /// Start hour and length, in hours, matching `CelestialPhase.resolve`.
    static func bounds(of phase: CelestialPhase) -> (start: Double, length: Double) {
        switch phase {
        case .dawn: (5, 3)
        case .morning: (8, 4)
        case .midday: (12, 5)
        case .goldenHour: (17, 2)
        case .twilight: (19, 2)
        case .night: (21, 8)
        }
    }

    /// Position along the indicator's arc for a moment.
    ///
    /// Daylight and night each get the whole sweep: the sun rises and sets
    /// across it, then the moon does the same. Mapping all 24 hours onto one
    /// sweep would park the sun at the bottom for most of the working day.
    public static func arcProgress(at date: Date, calendar: Calendar = .current) -> Double {
        let hour = Double(calendar.component(.hour, from: date))
            + Double(calendar.component(.minute, from: date)) / 60
        if isDaylight(at: date, calendar: calendar) {
            // 05:00 to 21:00 across the arc.
            return ((hour - 5) / 16).clampedToUnit
        }
        // 21:00 to 05:00, wrapping midnight.
        let elapsed = hour >= 21 ? hour - 21 : hour + 3
        return (elapsed / 8).clampedToUnit
    }

    public static func isDaylight(at date: Date, calendar: Calendar = .current) -> Bool {
        CelestialPhase.resolve(at: date, calendar: calendar) != .night
    }
}

private extension Double {
    var clampedToUnit: Double { min(max(self, 0), 1) }
}

/// A small sun or moon riding an arc, showing how far into the day it is.
///
/// Deliberately not a clock: it answers "how much of the day is left" at a
/// glance, which is the question the planning surfaces are actually asking.
public struct CelestialDaypartIndicator: View {
    private let date: Date
    private let calendar: Calendar

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(date: Date = Date(), calendar: Calendar = .current) {
        self.date = date
        self.calendar = calendar
    }

    private var phase: CelestialPhase {
        CelestialPhase.resolve(at: date, calendar: calendar)
    }

    private var progress: Double {
        DaypartProgress.arcProgress(at: date, calendar: calendar)
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height * 2)
            ZStack {
                CelestialArc()
                    .stroke(
                        Color(LifeBoardColorTokens.foundationHairline),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])
                    )
                CelestialArc(progress: progress)
                    .stroke(
                        Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                celestialBody(side: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private func celestialBody(side: CGFloat) -> some View {
        let point = CelestialArc.point(
            forProgress: progress,
            in: CGRect(x: 0, y: 0, width: side, height: side / 2)
        )
        return Image(decorative: AtmosphereDescriptor.descriptor(for: phase).celestialAsset)
            .resizable()
            .scaledToFit()
            .frame(width: side * 0.14, height: side * 0.14)
            .position(x: point.x, y: point.y)
            .animation(reduceMotion ? nil : LifeBoardAnimation.panelIn, value: progress)
    }

    private var accessibilityDescription: String {
        let percent = Int((progress * 100).rounded())
        let period = DaypartProgress.isDaylight(at: date, calendar: calendar)
            ? "daylight"
            : "night"
        return "\(phase.rawValue.capitalized), \(percent) percent through \(period)"
    }
}

/// The half-dome the celestial body travels, drawn left to right.
public struct CelestialArc: Shape {
    public var progress: Double

    public init(progress: Double = 1) {
        self.progress = progress
    }

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Point on the dome at `progress`, measured from the rect's bottom edge.
    public static func point(forProgress progress: Double, in rect: CGRect) -> CGPoint {
        let clamped = min(max(progress, 0), 1)
        // Half a turn, from due west round the top to due east.
        let angle = Double.pi * (1 - clamped)
        let radiusX = rect.width / 2
        let radiusY = rect.height
        return CGPoint(
            // Plus, not minus: at progress 0 the angle is π and the cosine is
            // -1, which has to land on the left edge so the body rises there.
            x: rect.midX + radiusX * cos(angle),
            y: rect.maxY - radiusY * sin(angle)
        )
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 48
        let travelled = Int((Double(steps) * min(max(progress, 0), 1)).rounded())
        guard travelled > 0 else { return path }
        for step in 0...travelled {
            let point = Self.point(forProgress: Double(step) / Double(steps), in: rect)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

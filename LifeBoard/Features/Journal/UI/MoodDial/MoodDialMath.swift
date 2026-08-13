import CoreGraphics
import Foundation
import SwiftUI
import os

public enum MoodDialMath {
    public static let pointerAngleDegrees = 270.0
    public static let arcStartDegrees = 180.0
    public static let arcSweepDegrees = 180.0

    public static func segmentSweepDegrees(count: Int = Mood.dialMoods.count) -> Double {
        arcSweepDegrees / Double(max(count, 1))
    }

    public static func centerAngleDegrees(for index: Int, count: Int = Mood.dialMoods.count) -> Double {
        arcStartDegrees + (Double(index) + 0.5) * segmentSweepDegrees(count: count)
    }

    public static func rotationDegrees(for index: Int, count: Int = Mood.dialMoods.count) -> Double {
        pointerAngleDegrees - centerAngleDegrees(for: clampedIndex(index, count: count), count: count)
    }

    public static func rotationDegrees(for mood: Mood) -> Double {
        rotationDegrees(for: index(for: mood))
    }

    public static func nearestIndex(forRotationDegrees rotation: Double, count: Int = Mood.dialMoods.count) -> Int {
        let segmentSweep = segmentSweepDegrees(count: count)
        let angleUnderPointer = pointerAngleDegrees - rotation
        let rawIndex = ((angleUnderPointer - arcStartDegrees) / segmentSweep) - 0.5
        return clampedIndex(Int(rawIndex.rounded()), count: count)
    }

    public static func mood(forRotationDegrees rotation: Double) -> Mood {
        Mood.dialMoods[nearestIndex(forRotationDegrees: rotation)]
    }

    public static func clampedRotationDegrees(_ rotation: Double, count: Int = Mood.dialMoods.count) -> Double {
        let first = rotationDegrees(for: 0, count: count)
        let last = rotationDegrees(for: count - 1, count: count)
        return min(max(rotation, last), first)
    }

    public static func resistedRotationDegrees(_ rotation: Double, count: Int = Mood.dialMoods.count) -> Double {
        let first = rotationDegrees(for: 0, count: count)
        let last = rotationDegrees(for: count - 1, count: count)

        if rotation > first {
            return first + (rotation - first) * 0.22
        }

        if rotation < last {
            return last + (rotation - last) * 0.22
        }

        return rotation
    }

    public static func normalizedDeltaDegrees(from start: Double, to end: Double) -> Double {
        var delta = end - start
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    public static func index(for mood: Mood) -> Int {
        Mood.dialMoods.firstIndex(of: mood) ?? Mood.neutralDialIndex
    }

    public static func angleDegrees(for point: CGPoint, around center: CGPoint) -> Double {
        var degrees = atan2(point.y - center.y, point.x - center.x) * 180 / .pi
        if degrees < 0 {
            degrees += 360
        }
        return degrees
    }

    private static func clampedIndex(_ index: Int, count: Int) -> Int {
        min(max(index, 0), max(count - 1, 0))
    }
}

public struct MoodDialWheelMetrics {
    public let size: CGSize
    public let safeAreaInsets: EdgeInsets

    public init(size: CGSize, safeAreaInsets: EdgeInsets = EdgeInsets()) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
    }

    public var outerRadius: CGFloat { min(max(size.width * 1.06, 360), 420) }
    public var innerRadius: CGFloat { min(max(outerRadius * 0.66, 240), 280) }
    public var dialTop: CGFloat { size.height * 0.60 }
    public var center: CGPoint { CGPoint(x: size.width / 2, y: dialTop + outerRadius) }

    public var pointerCenterY: CGFloat {
        min(center.y - innerRadius + 108, size.height - safeAreaInsets.bottom - 34)
    }

    public var gestureTop: CGFloat { max(dialTop - 56, size.height * 0.50) }
    public var gestureHeight: CGFloat { max(size.height - gestureTop, 1) }
    public var gestureCenterY: CGFloat { gestureTop + gestureHeight / 2 }
    public var selectedMoodScale: CGFloat { min(max(size.height / 852, 0.88), 1.04) }

    public var selectedMoodCenterY: CGFloat {
        let estimatedBlockHeight = 304 * selectedMoodScale
        let headerBottom = safeAreaInsets.top + 124
        let upperCenter = dialTop - 24 - estimatedBlockHeight / 2
        let lowerCenter = headerBottom + estimatedBlockHeight / 2
        return upperCenter > lowerCenter
            ? (upperCenter + lowerCenter) / 2
            : max(lowerCenter, dialTop - estimatedBlockHeight / 2)
    }
}

enum MoodDialSignposts {
    struct Token {
        #if DEBUG || PROFILE_SIGNPOSTS
        let name: StaticString
        let id: OSSignpostID
        #endif
    }

    #if DEBUG || PROFILE_SIGNPOSTS
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "MoodDialKit",
        category: .pointsOfInterest
    )
    #endif

    static func event(_ name: StaticString) {
        #if DEBUG || PROFILE_SIGNPOSTS
        os_signpost(.event, log: log, name: name)
        #endif
    }

    static func begin(_ name: StaticString) -> Token {
        #if DEBUG || PROFILE_SIGNPOSTS
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return Token(name: name, id: id)
        #else
        return Token()
        #endif
    }

    static func end(_ token: Token) {
        #if DEBUG || PROFILE_SIGNPOSTS
        os_signpost(.end, log: log, name: token.name, signpostID: token.id)
        #endif
    }
}

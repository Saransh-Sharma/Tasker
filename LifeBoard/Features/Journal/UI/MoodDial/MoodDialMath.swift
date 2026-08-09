import CoreGraphics
import Foundation

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

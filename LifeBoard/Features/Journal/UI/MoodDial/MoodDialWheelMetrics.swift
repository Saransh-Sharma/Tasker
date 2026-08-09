import SwiftUI

public struct MoodDialWheelMetrics {
    public let size: CGSize
    public let safeAreaInsets: EdgeInsets

    public init(size: CGSize, safeAreaInsets: EdgeInsets = EdgeInsets()) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
    }

    public var outerRadius: CGFloat {
        min(max(size.width * 1.06, 360), 420)
    }

    public var innerRadius: CGFloat {
        min(max(outerRadius * 0.66, 240), 280)
    }

    public var dialTop: CGFloat {
        size.height * 0.60
    }

    public var center: CGPoint {
        CGPoint(x: size.width / 2, y: dialTop + outerRadius)
    }

    public var pointerCenterY: CGFloat {
        let idealCenterY = center.y - innerRadius + 108
        let lowestCenterY = size.height - safeAreaInsets.bottom - 34
        return min(idealCenterY, lowestCenterY)
    }

    public var gestureTop: CGFloat {
        max(dialTop - 56, size.height * 0.50)
    }

    public var gestureHeight: CGFloat {
        max(size.height - gestureTop, 1)
    }

    public var gestureCenterY: CGFloat {
        gestureTop + gestureHeight / 2
    }

    public var selectedMoodScale: CGFloat {
        min(max(size.height / 852, 0.88), 1.04)
    }

    public var selectedMoodCenterY: CGFloat {
        let estimatedBlockHeight = 304 * selectedMoodScale
        let headerBottom = safeAreaInsets.top + 124
        let upperCenter = dialTop - 24 - estimatedBlockHeight / 2
        let lowerCenter = headerBottom + estimatedBlockHeight / 2

        if upperCenter > lowerCenter {
            return (upperCenter + lowerCenter) / 2
        }

        return max(lowerCenter, dialTop - estimatedBlockHeight / 2)
    }
}

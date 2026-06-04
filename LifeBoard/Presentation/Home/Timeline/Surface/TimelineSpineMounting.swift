import SwiftUI

enum TimelineSpineMounting {
    static func centerX(for geometry: TimelineStreamGeometry, atY y: CGFloat) -> CGFloat {
        geometry.x(atY: y)
    }

    static func routineTextLeadingX(
        for geometry: TimelineStreamGeometry,
        atY y: CGFloat,
        iconSize: CGFloat,
        railMetrics: TimelineRailMetrics
    ) -> CGFloat {
        railMetrics.routineTextLeadingX(
            iconSize: iconSize,
            mountedSpineX: centerX(for: geometry, atY: y)
        )
    }
}

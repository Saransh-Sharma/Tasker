import SwiftUI

enum TimelineRailTypography {
    static let compactHourSize: CGFloat = 14
    static let exactSize: CGFloat = 14
    static let currentSize: CGFloat = 13

    static func font(for kind: TimelineRailLabelKind, isEmphasized: Bool) -> Font {
        switch kind {
        case .compactHour:
            return .system(size: compactHourSize, weight: isEmphasized ? .semibold : .medium, design: .rounded)
        case .exact:
            return .system(size: exactSize, weight: isEmphasized ? .semibold : .medium, design: .rounded)
        case .current:
            return .system(size: currentSize, weight: .semibold, design: .rounded)
        }
    }
}

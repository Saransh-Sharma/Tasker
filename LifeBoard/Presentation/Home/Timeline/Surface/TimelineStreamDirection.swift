import SwiftUI

enum TimelineStreamDirection: CGFloat, Equatable {
    case leading = -1
    case center = 0
    case trailing = 1

    var inverted: TimelineStreamDirection {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        case .center:
            return .trailing
        }
    }
}

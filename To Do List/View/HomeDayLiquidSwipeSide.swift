import SwiftUI

enum HomeDayLiquidSwipeSide: CaseIterable {
    case leading
    case trailing

    var direction: HomeDayNavigationDirection {
        switch self {
        case .leading:
            return .previous
        case .trailing:
            return .next
        }
    }

    var horizontalSign: CGFloat {
        switch self {
        case .leading:
            return 1
        case .trailing:
            return -1
        }
    }

    var systemImage: String {
        switch self {
        case .leading:
            return "chevron.backward"
        case .trailing:
            return "chevron.forward"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .leading:
            return "Previous Day"
        case .trailing:
            return "Next Day"
        }
    }
}

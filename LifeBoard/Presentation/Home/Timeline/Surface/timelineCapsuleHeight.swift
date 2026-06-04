import SwiftUI

func timelineCapsuleHeight(for duration: TimeInterval?) -> CGFloat {
    let minutes = Int(max(1, (duration ?? 30 * 60) / 60))
    switch minutes {
    case ..<23:
        return 64
    case ..<38:
        return 90
    case ..<53:
        return 110
    case ..<76:
        return 128
    case ..<106:
        return 168
    default:
        return 176
    }
}

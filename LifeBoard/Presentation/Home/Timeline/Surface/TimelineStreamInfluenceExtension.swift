import SwiftUI

extension TimelineStreamInfluence {
    var startY: CGFloat { centerY - (max(height, 40) / 2) }
    var endY: CGFloat { centerY + (max(height, 40) / 2) }
}

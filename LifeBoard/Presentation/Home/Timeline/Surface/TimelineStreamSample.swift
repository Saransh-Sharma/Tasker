import SwiftUI

struct TimelineStreamSample: Equatable, Identifiable {
    let index: Int
    let y: CGFloat
    let x: CGFloat
    let lineWidth: CGFloat
    let tintHex: String?
    let progress: CGFloat

    var id: Int { index }
}

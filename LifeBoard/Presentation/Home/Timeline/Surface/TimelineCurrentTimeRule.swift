import SwiftUI

struct TimelineCurrentTimeRule: View {
    let startX: CGFloat
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.lifeboard.statusDanger.opacity(0.16))
            .frame(width: min(max(width - startX, 0), 92), height: 1)
            .offset(x: startX, y: -0.5)
            .frame(width: width, height: 1, alignment: .leading)
    }
}

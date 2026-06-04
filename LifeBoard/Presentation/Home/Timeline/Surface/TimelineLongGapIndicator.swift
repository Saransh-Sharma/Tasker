import SwiftUI

struct TimelineLongGapIndicator: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(TimelineVisualTokens.utilityText.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

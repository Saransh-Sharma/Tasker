import SwiftUI

struct SunriseTimelineBar: View {


    let onSnapAnchor: (SunriseAnchor) -> Void

    let onDragChanged: (CGFloat) -> Void

    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        Capsule()
            .fill(Color.lifeboard.textTertiary.opacity(0.24))
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Timeline reveal handle")
            .accessibilityHint("Drag to reveal the weekly layer behind the timeline.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onSnapAnchor(.midReveal)
            }
        .padding(.top, 6)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    onDragChanged(value.translation.height)
                }
                .onEnded { value in
                    onDragEnded(value.predictedEndTranslation.height)
                }
        )
        .accessibilityIdentifier("home.timeline.handle")
    }
}

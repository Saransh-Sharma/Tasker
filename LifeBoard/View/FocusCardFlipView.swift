import SwiftUI

struct FocusCardFlipView<Front: View, Back: View>: View {
    let isFlipped: Bool
    let reduceMotion: Bool
    let perspective: CGFloat
    let duration: Double
    let front: Front
    let back: Back

    init(
        isFlipped: Bool,
        reduceMotion: Bool,
        perspective: CGFloat = 0.58,
        duration: Double = 0.42,
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) {
        self.isFlipped = isFlipped
        self.reduceMotion = reduceMotion
        self.perspective = perspective
        self.duration = duration
        self.front = front()
        self.back = back()
    }

    var body: some View {
        ZStack {
            front
                .opacity(frontOpacity)
                .rotation3DEffect(
                    .degrees(frontRotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: perspective
                )
                .zIndex(isFlipped ? 0 : 1)
                .allowsHitTesting(!isFlipped)
                .accessibilityHidden(isFlipped)
                .animation(frontAnimation, value: isFlipped)

            back
                .opacity(backOpacity)
                .rotation3DEffect(
                    .degrees(backRotation),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: perspective
                )
                .zIndex(isFlipped ? 1 : 0)
                .allowsHitTesting(isFlipped)
                .accessibilityHidden(!isFlipped)
                .animation(backAnimation, value: isFlipped)
        }
    }

    private var halfDuration: Double { duration / 2 }

    private var frontRotation: Double {
        reduceMotion ? 0 : (isFlipped ? 90 : 0)
    }

    private var backRotation: Double {
        reduceMotion ? 0 : (isFlipped ? 0 : -90)
    }

    private var frontOpacity: Double {
        reduceMotion && isFlipped ? 0 : 1
    }

    private var backOpacity: Double {
        reduceMotion && !isFlipped ? 0 : 1
    }

    private var frontAnimation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.16)
        }
        return isFlipped
            ? .easeIn(duration: halfDuration)
            : .easeOut(duration: halfDuration).delay(halfDuration)
    }

    private var backAnimation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.16)
        }
        return isFlipped
            ? .easeOut(duration: halfDuration).delay(halfDuration)
            : .easeIn(duration: halfDuration)
    }
}

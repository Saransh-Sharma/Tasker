import SwiftUI

struct TaskerLaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didReveal = false

    var body: some View {
        ZStack {
            Color("LaunchCanvas")
                .ignoresSafeArea()

            Image(decorative: "TaskerSplashIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .opacity(didReveal ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (didReveal ? 1 : 0.94))
        }
        .onAppear(perform: reveal)
    }

    private func reveal() {
        guard didReveal == false else { return }
        withAnimation(reduceMotion ? TaskerAnimation.feedbackFast : TaskerAnimation.gatewayReveal) {
            didReveal = true
        }
    }
}

#Preview {
    TaskerLaunchSplashView()
}

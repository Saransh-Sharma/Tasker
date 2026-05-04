import SwiftUI

@main
struct LifeBoardWatchApp: App {
    @StateObject private var snapshotReceiver = WatchSnapshotReceiver()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .onAppear {
                    snapshotReceiver.activate()
                }
        }
    }
}

private struct WatchHomeView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("LifeBoard")
                .font(.headline)
            Text("Add LifeBoard complications to your watch face for schedule and habit streaks.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

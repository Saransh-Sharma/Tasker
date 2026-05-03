import SwiftUI

@main
struct TaskerWatchApp: App {
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
            Text("Tasker")
                .font(.headline)
            Text("Add Tasker complications to your watch face for schedule and habit streaks.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

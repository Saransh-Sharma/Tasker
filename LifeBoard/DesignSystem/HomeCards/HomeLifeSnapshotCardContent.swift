import SwiftUI

struct HomeLifeSnapshotCardContent: View {
    let mood: String
    let moodLabel: String
    let hydration: String
    let lowEnergy: Bool
    let palette: DaypartPalette
    var onMood: () -> Void = {}
    var onHydration: () -> Void = {}
    var onTrack: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HomeWidgetTitle("How life feels", symbol: "heart.text.square", palette: palette)
                .accessibilityIdentifier("home.widget.lifeSnapshot")
                .homeCardEvidence("snapshot.title", role: "title", copy: "How life feels", typography: .init(role: "headline", points: 17, weight: "semibold", alignment: "leading"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 200 : 100))], spacing: 12) {
                HomeSnapshotMetric(
                    id: "mood",
                    symbol: "face.smiling",
                    value: mood,
                    label: moodLabel,
                    palette: palette
                ) {
                    onMood()
                }
                HomeSnapshotMetric(
                    id: "hydration",
                    symbol: "drop.fill",
                    value: hydration,
                    label: "Hydration",
                    palette: palette
                ) { onHydration() }
                HomeSnapshotMetric(id: "steps", symbol: "figure.walk", value: "Connect", label: "Steps", palette: palette) {
                    onTrack()
                }
                if !lowEnergy {
                    HomeSnapshotMetric(id: "active", symbol: "flame.fill", value: "Connect", label: "Active", palette: palette) {
                        onTrack()
                    }
                }
            }
        }
        .padding(16)
    }
}

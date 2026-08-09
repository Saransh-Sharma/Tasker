import SwiftUI

public struct MoodDialView: View {
    @Binding var selectedMood: Mood
    @State private var isWheelDragging = false
    @Environment(\.moodDialTheme) private var theme

    public init(selectedMood: Binding<Mood>) {
        _selectedMood = selectedMood
    }

    public var body: some View {
        GeometryReader { proxy in
            let metrics = MoodDialWheelMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)

            ZStack {
                LinearGradient(
                    colors: [theme.backgroundTop, theme.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                MoodDialSelectedMoodView(
                    mood: selectedMood,
                    layoutScale: metrics.selectedMoodScale,
                    isInteractionActive: isWheelDragging
                )
                .frame(maxWidth: 340)
                .padding(.horizontal, 28)
                .position(x: proxy.size.width / 2, y: metrics.selectedMoodCenterY)
                .zIndex(2)

                MoodDialWheel(selectedMood: $selectedMood, isDragging: $isWheelDragging, metrics: metrics)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .accessibilityIdentifier("moodDial.surface")
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

public struct MoodDialSheet: View {
    @Binding private var selectedMood: Mood
    @Environment(\.dismiss) private var dismiss

    @State private var draftMood: Mood
    private let originalMood: Mood
    private let onSave: () -> Void

    public init(selectedMood: Binding<Mood>, onSave: @escaping () -> Void) {
        let openingMood = MoodDialPersistence.openingMood(for: selectedMood.wrappedValue)
        _selectedMood = selectedMood
        _draftMood = State(initialValue: openingMood)
        originalMood = openingMood
        self.onSave = onSave
    }

    public var body: some View {
        ZStack(alignment: .top) {
            MoodDialView(selectedMood: $draftMood)

            MoodDialHeader(
                canSave: MoodDialPersistence.shouldSave(originalMood: originalMood, draftMood: draftMood),
                cancel: cancel,
                done: done
            )
            .padding(.top, 16)
        }
        .interactiveDismissDisabled()
        .accessibilityIdentifier("moodDial.sheet")
        .onAppear {
            MoodDialSignposts.event("MoodDialSheetPresented")
            MoodAssetPreheater.preheatMoodAssets()
        }
    }

    private func cancel() {
        dismiss()
    }

    private func done() {
        if MoodDialPersistence.shouldSave(originalMood: originalMood, draftMood: draftMood) {
            MoodDialSignposts.event("MoodDialSave")
            selectedMood = draftMood
            onSave()
        }
        dismiss()
    }
}

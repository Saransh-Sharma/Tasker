import SwiftUI
import WatchCaptureKit

@main
struct LifeBoardWatchApp: App {
    @StateObject private var store = WatchJournalCaptureStore.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView(store: store)
                .onAppear { store.start() }
        }
    }
}

private enum WatchStyle {
    static let canvas = Color(red: 0.055, green: 0.047, blue: 0.075)
    static let paper = Color.white.opacity(0.11)
    static let paperStrong = Color.white.opacity(0.17)
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.76)
    static let muted = Color.white.opacity(0.62)
    static let onAccent = Color.black
    static let separator = Color.white.opacity(0.18)
    static let warning = Color.orange
    static let sun = Color(red: 1.00, green: 0.75, blue: 0.28)
    static let coral = Color(red: 1.00, green: 0.48, blue: 0.42)
    static let mint = Color(red: 0.48, green: 0.88, blue: 0.68)
    static let sky = Color(red: 0.48, green: 0.70, blue: 1.00)
    static let lavender = Color(red: 0.73, green: 0.62, blue: 0.96)
}

private struct WatchHomeView: View {
    @ObservedObject var store: WatchJournalCaptureStore
    @State private var snapshot = TaskListWidgetSnapshot.load()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    todayCard

                    Text("Journal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchStyle.secondary)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        NavigationLink { WatchMoodCaptureView(store: store) } label: {
                            WatchActionTile(title: "Mood", symbol: "face.smiling.fill", tint: WatchStyle.sun)
                        }
                        NavigationLink { WatchTextCaptureView(store: store) } label: {
                            WatchActionTile(title: "Speak", symbol: "text.bubble.fill", tint: WatchStyle.sky)
                        }
                        NavigationLink { WatchRecordCaptureView(store: store) } label: {
                            WatchActionTile(title: "Record", symbol: "waveform", tint: WatchStyle.coral)
                        }
                        NavigationLink { WatchRecentCapturesView(store: store) } label: {
                            WatchActionTile(
                                title: "Recent",
                                symbol: store.pendingCount == 0 ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath",
                                tint: WatchStyle.mint,
                                badge: store.pendingCount
                            )
                        }
                    }
                    .buttonStyle(WatchPressStyle())

                    Label(store.syncSummary, systemImage: store.pendingCount == 0 ? "iphone.gen3.circle.fill" : "lock.circle.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(WatchStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .background(WatchBackground())
            .toolbar(.hidden)
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardWatchSnapshotUpdated)) { _ in
                snapshot = TaskListWidgetSnapshot.load()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("LifeBoard")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WatchStyle.primary)
                Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(WatchStyle.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "sun.max.fill")
                .foregroundStyle(WatchStyle.sun)
                .symbolEffect(.breathe, options: .nonRepeating)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let item = currentTimelineItem {
                Label(item.isCurrent ? "Now" : "Up next", systemImage: item.systemImageName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchStyle.sun)
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WatchStyle.primary)
                    .lineLimit(2)
                if let start = item.startDate {
                    Text(start, style: .time)
                        .font(.caption2)
                        .foregroundStyle(WatchStyle.secondary)
                }
            } else {
                Label("Your day is clear", systemImage: "sparkles")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WatchStyle.primary)
            }

            if let habit = snapshot.habit.primaryHabit {
                Divider().overlay(WatchStyle.separator)
                Label("\(habit.title) · \(habit.currentStreak) day rhythm", systemImage: habit.iconSymbolName)
                    .font(.caption2)
                    .foregroundStyle(WatchStyle.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(WatchStyle.paperStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var currentTimelineItem: TaskListWidgetTimelineItem? {
        let items = snapshot.timeline.day.timedItems + snapshot.timeline.day.inboxItems
        return items.first(where: \.isCurrent)
            ?? items.filter { ($0.startDate ?? .distantFuture) >= Date() }.min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }
}

private struct WatchActionTile: View {
    let title: String
    let symbol: String
    let tint: Color
    var badge = 0

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 34)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchStyle.onAccent)
                        .padding(3)
                        .background(WatchStyle.sun, in: Circle())
                        .offset(x: 6, y: -5)
                }
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchStyle.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(WatchStyle.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) pending" : title)
    }
}

enum WatchJournalMood: String, CaseIterable, Identifiable {
    case angry, sad, anxious, tired, none, calm, grateful, happy, excited
    var id: String { rawValue }
    var title: String { self == .none ? "Neutral" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .angry: "flame.fill"
        case .sad: "cloud.rain.fill"
        case .anxious: "wind"
        case .tired: "moon.zzz.fill"
        case .none: "circle.dashed"
        case .calm: "leaf.fill"
        case .grateful: "heart.fill"
        case .happy: "face.smiling.fill"
        case .excited: "sparkles"
        }
    }
    var tint: Color {
        switch self {
        case .angry: WatchStyle.coral
        case .sad: WatchStyle.sky
        case .anxious: WatchStyle.lavender
        case .tired: WatchStyle.warning
        case .none: WatchStyle.secondary
        case .calm, .grateful: WatchStyle.mint
        case .happy, .excited: WatchStyle.sun
        }
    }
}

private struct WatchMoodCaptureView: View {
    @ObservedObject var store: WatchJournalCaptureStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = 5.0

    private var mood: WatchJournalMood {
        WatchJournalMood.allCases[min(max(Int(selection.rounded()), 0), WatchJournalMood.allCases.count - 1)]
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("How are you?")
                .font(.headline)
                .foregroundStyle(WatchStyle.primary)
            Image(systemName: mood.symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(mood.tint)
                .frame(width: 82, height: 72)
                .background(mood.tint.opacity(0.14), in: Circle())
                .contentTransition(.symbolEffect(.replace))
            Text(mood.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(WatchStyle.primary)
            Button("Save mood") {
                store.saveMood(mood)
                dismiss()
            }
            .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.sun))
        }
        .padding(.horizontal, 10)
        .background(WatchBackground())
        .focusable()
        .digitalCrownRotation($selection, from: 0, through: 8, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78), value: mood)
        .accessibilityElement(children: .contain)
        .accessibilityValue(mood.title)
        .accessibilityHint("Turn the Digital Crown to choose a mood")
    }
}

private struct WatchTextCaptureView: View {
    @ObservedObject var store: WatchJournalCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("A quick thought", systemImage: "text.bubble.fill")
                .font(.headline)
                .foregroundStyle(WatchStyle.sky)
            TextField("What’s on your mind?", text: $text, axis: .vertical)
                .lineLimit(3...5)
                .textInputAutocapitalization(.sentences)
            Text("Saved privately. Dictation stays editable before you send it.")
                .font(.caption2)
                .foregroundStyle(WatchStyle.secondary)
            Button("Save thought") {
                store.saveText(text)
                dismiss()
            }
            .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.sky))
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .background(WatchBackground())
    }
}

private struct WatchRecordCaptureView: View {
    @ObservedObject var store: WatchJournalCaptureStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var recorder = WatchAudioRecorder()
    @State private var pending: (url: URL, duration: TimeInterval)?

    var body: some View {
        VStack(spacing: 9) {
            Text(recorder.isRecording ? "Listening" : pending == nil ? "Voice moment" : "Ready to save")
                .font(.headline)
                .foregroundStyle(WatchStyle.primary)
            waveform
            Text(format(pending?.duration ?? recorder.duration))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(WatchStyle.primary)
            if let error = recorder.errorMessage {
                Text(error).font(.caption2).foregroundStyle(WatchStyle.coral)
            }
            HStack(spacing: 8) {
                Button(recorder.isRecording ? "Stop" : "Record") {
                    if recorder.isRecording { pending = recorder.stop() } else { recorder.start() }
                }
                .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.coral))
                Button("Save") {
                    let result = pending ?? recorder.stop()
                    guard let result else { return }
                    store.saveAudio(fileURL: result.url, duration: result.duration)
                    pending = nil
                    dismiss()
                }
                .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.mint))
                .disabled(!recorder.isRecording && pending == nil)
            }
        }
        .padding(.horizontal, 8)
        .background(WatchBackground())
        .onDisappear {
            if recorder.isRecording { recorder.cancel() }
            if let pending { try? FileManager.default.removeItem(at: pending.url) }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: recorder.isRecording)
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                let profile: [CGFloat] = [0.45, 0.72, 1.0, 0.64, 0.88, 0.58, 0.96, 0.68, 0.42]
                Capsule()
                    .fill(WatchStyle.coral)
                    .frame(width: 5, height: max(8, CGFloat(recorder.level) * profile[index] * 48))
            }
        }
        .frame(height: 52)
        .accessibilityHidden(true)
    }

    private func format(_ value: TimeInterval) -> String {
        let seconds = Int(value)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct WatchRecentCapturesView: View {
    @ObservedObject var store: WatchJournalCaptureStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Recent")
                        .font(.headline)
                        .foregroundStyle(WatchStyle.primary)
                    Spacer()
                    if store.pendingCount > 0 {
                        Button { store.retryPending() } label: {
                            Image(systemName: "arrow.clockwise")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(WatchStyle.sun)
                        .accessibilityLabel("Retry all pending captures")
                    }
                }

                Toggle("Show previews", isOn: $store.showPrivatePreviews)
                    .font(.caption2)
                    .tint(WatchStyle.sun)

                if store.recent.isEmpty {
                    ContentUnavailableView("Nothing held", systemImage: "checkmark.circle", description: Text("New captures stay here until iPhone confirms them."))
                        .foregroundStyle(WatchStyle.primary)
                } else {
                    ForEach(store.recent) { item in
                        Button {
                            if item.syncState != .synced { store.retry(item.id) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: symbol(for: item))
                                    .foregroundStyle(tint(for: item))
                                    .frame(width: 28, height: 28)
                                    .background(tint(for: item).opacity(0.14), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.preview(for: item))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WatchStyle.primary)
                                        .lineLimit(1)
                                    Text(item.statusText)
                                        .font(.caption2)
                                        .foregroundStyle(WatchStyle.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 2)
                                if item.syncState != .synced {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption2)
                                        .foregroundStyle(WatchStyle.muted)
                                }
                            }
                            .padding(9)
                            .background(WatchStyle.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(WatchPressStyle())
                        .disabled(item.audioFileMissing)
                        .accessibilityLabel("\(store.preview(for: item)), \(item.statusText)")
                        .accessibilityHint(item.syncState == .synced ? "" : "Double tap to retry")
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 10)
        }
        .background(WatchBackground())
    }

    private func symbol(for item: WatchRecentCapture) -> String {
        switch item.envelope.kind {
        case .mood: "face.smiling"
        case .speak: "text.bubble"
        case .audio: "waveform"
        }
    }

    private func tint(for item: WatchRecentCapture) -> Color {
        switch item.syncState {
        case .synced: WatchStyle.mint
        case .failed: WatchStyle.coral
        case .sending: WatchStyle.sky
        case .saved, .queued: WatchStyle.sun
        }
    }
}

private struct WatchBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            WatchStyle.canvas.ignoresSafeArea()
            if !reduceTransparency {
                RadialGradient(colors: [WatchStyle.sun.opacity(0.12), .clear], center: .topTrailing, startRadius: 0, endRadius: 180)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct WatchPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct WatchCapsuleButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(WatchStyle.onAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.76), value: configuration.isPressed)
    }
}

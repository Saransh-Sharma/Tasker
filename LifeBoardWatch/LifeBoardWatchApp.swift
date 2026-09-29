import LifeBoardContracts
import SwiftUI
import LifeBoardContracts

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

/// The sections a complication or deep link can land on. The watch app is a
/// single scrolling page, so "opening" a section scrolls it into view.
private enum WatchHomeSection: Hashable {
    case today, fasting, routine, journal

    /// Maps the `lifeboard://` links the watch complications use (the same
    /// hosts the phone understands) to a section on this page.
    init?(url: URL) {
        guard ["lifeboard", "tasker"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        switch url.host?.lowercased() {
        case "tasks", "calendar", "day", "home", "habits", "habit", "focus": self = .today
        case "fasting": self = .fasting
        case "routine", "routines": self = .routine
        case "journal", "note": self = .journal
        default: return nil
        }
    }
}

private struct WatchHomeView: View {
    @ObservedObject var store: WatchJournalCaptureStore
    @State private var snapshot = TaskListWidgetSnapshot.load()
    @State private var confirmingCancelFast: FastingSessionSurfaceSnapshot?
    @State private var confirmingStopRoutine: RoutineRunSurfaceSnapshot?
    /// Shown under the card whose command could not be handed to the phone,
    /// so a failed tap never looks like it worked.
    @State private var commandFailure: (section: WatchHomeSection, message: String)?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    todayCard
                        .id(WatchHomeSection.today)
                    if let fast = snapshot.activeFastingSession {
                        fastingCard(fast)
                            .id(WatchHomeSection.fasting)
                    }
                    if let run = snapshot.activeRoutineRun {
                        routineCard(run)
                            .id(WatchHomeSection.routine)
                    }

                    Text("Journal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchStyle.secondary)
                        .accessibilityAddTraits(.isHeader)
                        .id(WatchHomeSection.journal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        NavigationLink { WatchMoodCaptureView(store: store) } label: {
                            WatchActionTile(title: "Mood", symbol: "face.smiling.fill", tint: WatchStyle.sun)
                        }
                        NavigationLink { WatchTextCaptureView(store: store) } label: {
                            WatchActionTile(title: "Capture", symbol: "text.bubble.fill", tint: WatchStyle.sky)
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
            // Complications link with `lifeboard://…`; without a handler the
            // app just opened wherever it was. Land on the matching section.
            .onOpenURL { url in
                snapshot = TaskListWidgetSnapshot.load()
                guard let section = WatchHomeSection(url: url) else { return }
                proxy.scrollTo(section, anchor: .top)
            }
            }
            .confirmationDialog(
                "Cancel this fast?",
                isPresented: Binding(
                    get: { confirmingCancelFast != nil },
                    set: { if $0 == false { confirmingCancelFast = nil } }
                ),
                titleVisibility: .visible,
                presenting: confirmingCancelFast
            ) { fast in
                Button("Cancel fast", role: .destructive) {
                    sendFasting(.cancel, session: fast)
                }
                Button("Keep fasting", role: .cancel) {}
            } message: { _ in
                Text("It won’t be saved. To keep it, choose Finish.")
            }
            .confirmationDialog(
                "Stop this routine?",
                isPresented: Binding(
                    get: { confirmingStopRoutine != nil },
                    set: { if $0 == false { confirmingStopRoutine = nil } }
                ),
                titleVisibility: .visible,
                presenting: confirmingStopRoutine
            ) { run in
                Button("Stop routine", role: .destructive) {
                    sendRoutine(.stop, run: run)
                }
                Button("Keep going", role: .cancel) {}
            } message: { run in
                Text("\(run.title) ends here.")
            }
        }
    }

    @ViewBuilder
    private func failureText(for section: WatchHomeSection) -> some View {
        if let commandFailure, commandFailure.section == section {
            Label(commandFailure.message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(WatchStyle.coral)
                .fixedSize(horizontal: false, vertical: true)
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
                Label("Nothing planned", systemImage: "sparkles")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WatchStyle.primary)
            }

            if let habit = snapshot.habit.primaryHabit {
                Divider().overlay(WatchStyle.separator)
                Label(
                    habit.currentStreak == 1 ? "\(habit.title) · 1 active day" : "\(habit.title) · \(habit.currentStreak) active days",
                    systemImage: habit.iconSymbolName
                )
                    .font(.caption2)
                    .foregroundStyle(WatchStyle.secondary)
                    .lineLimit(1)
                // The button logs the habit named on the line above — not
                // whichever habit happened to be first in the list.
                if let occurrence = actionableOccurrence(for: habit) {
                    Button {
                        logHabit(occurrence)
                    } label: {
                        Label("Log \(habit.title)", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(WatchPressStyle())
                    .accessibilityHint("Marks it done for today")
                }
            }
            failureText(for: .today)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(WatchStyle.paperStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func logHabit(_ occurrence: BehaviorOccurrenceSurfaceSnapshot) {
        let command = BehaviorOccurrenceActionCommand(
            occurrenceID: occurrence.occurrenceID,
            behaviorID: occurrence.behaviorID,
            action: .complete
        )
        do {
            try WatchSnapshotReceiver.shared.transferBehaviorOccurrence(command)
        } catch {
            WatchHaptics.failure()
            commandFailure = (.today, "Couldn’t send that to your iPhone. Try again.")
            return
        }
        commandFailure = nil
        WatchHaptics.success()
        snapshot.behaviorOccurrences = snapshot.behaviorOccurrences.map {
            guard $0.occurrenceID == occurrence.occurrenceID else { return $0 }
            var updated = $0
            updated.result = .completed
            return updated
        }
    }

    private var currentTimelineItem: TaskListWidgetTimelineItem? {
        let items = snapshot.timeline.day.timedItems + snapshot.timeline.day.inboxItems
        return items.first(where: \.isCurrent)
            ?? items.filter { ($0.startDate ?? .distantFuture) >= Date() }.min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }

    private func actionableOccurrence(for habit: TaskListWidgetHabitPrimary) -> BehaviorOccurrenceSurfaceSnapshot? {
        snapshot.behaviorOccurrences.first {
            $0.domain == .habit && $0.behaviorID == habit.habitID && $0.result == .unresolved
        }
    }

    private func fastingCard(_ fast: FastingSessionSurfaceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Fasting", systemImage: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WatchStyle.mint)
            // Counts up: a countdown stopped at 0:00 at the target while the
            // fast carried on. The goal is shown as a time of day instead.
            Text(timerInterval: fast.startedAt...Date.distantFuture, countsDown: false)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(WatchStyle.primary)
                .accessibilityLabel("Time fasted")
            if let targetEnd = fast.targetEndAt {
                Text("Goal \(targetEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(WatchStyle.secondary)
            }
            HStack(spacing: 8) {
                // Finish keeps the fast; it runs at once.
                Button("Finish") {
                    sendFasting(.finish, session: fast)
                }
                .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.mint))
                .frame(minHeight: 44)
                // Cancel discards it, so it asks first.
                Button("Cancel") {
                    confirmingCancelFast = fast
                }
                .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.coral))
                .frame(minHeight: 44)
            }
            failureText(for: .fasting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(WatchStyle.paperStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func routineCard(_ run: RoutineRunSurfaceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(run.title, systemImage: "repeat")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WatchStyle.lavender)
                .lineLimit(1)
            Text(run.currentStepTitle ?? "Next step")
                .font(.callout.weight(.semibold))
                .foregroundStyle(WatchStyle.primary)
                .lineLimit(2)
            Text("\(run.completedStepCount) of \(run.totalStepCount) done")
                .font(.caption2)
                .foregroundStyle(WatchStyle.secondary)
            HStack(spacing: 8) {
                Button(run.status == .paused ? "Resume" : "Pause") {
                    sendRoutine(run.status == .paused ? .resume : .pause, run: run)
                }
                .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.lavender))
                .frame(minHeight: 44)
                Button("Stop") {
                    confirmingStopRoutine = run
                }
                .buttonStyle(WatchCapsuleButtonStyle(tint: WatchStyle.coral))
                .frame(minHeight: 44)
            }
            failureText(for: .routine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(WatchStyle.paperStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func sendFasting(
        _ action: FastingWatchAction,
        session: FastingSessionSurfaceSnapshot
    ) {
        do {
            try WatchSnapshotReceiver.shared.transferFasting(
                FastingWatchCommand(sessionID: session.sessionID, action: action)
            )
        } catch {
            WatchHaptics.failure()
            commandFailure = (.fasting, "Couldn’t send that to your iPhone. Try again.")
            return
        }
        commandFailure = nil
        WatchHaptics.success()
        snapshot.activeFastingSession = nil
    }

    private func sendRoutine(
        _ action: RoutineWatchAction,
        run: RoutineRunSurfaceSnapshot
    ) {
        do {
            try WatchSnapshotReceiver.shared.transferRoutine(
                RoutineWatchCommand(runID: run.runID, action: action)
            )
        } catch {
            WatchHaptics.failure()
            commandFailure = (.routine, "Couldn’t send that to your iPhone. Try again.")
            return
        }
        commandFailure = nil
        WatchHaptics.success()
        switch action {
        case .pause:
            snapshot.activeRoutineRun?.status = .paused
        case .resume:
            snapshot.activeRoutineRun?.status = .running
        case .stop:
            snapshot.activeRoutineRun = nil
        }
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
        .accessibilityHint("Use the Digital Crown to choose")
    }
}

private struct WatchTextCaptureView: View {
    @ObservedObject var store: WatchJournalCaptureStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Capture", systemImage: "text.bubble.fill")
                .font(.headline)
                .foregroundStyle(WatchStyle.sky)
            TextField("Thought", text: $text, axis: .vertical)
                .lineLimit(3...5)
                .textInputAutocapitalization(.sentences)
            Text("Saved to your journal.")
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
            Text(recorder.isRecording ? "Listening" : pending == nil ? "Voice note" : "Ready to save")
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
                        .accessibilityLabel("Retry all")
                    }
                }

                Toggle("Show previews", isOn: $store.showPrivatePreviews)
                    .font(.caption2)
                    .tint(WatchStyle.sun)

                if store.recent.isEmpty {
                    ContentUnavailableView("Nothing waiting", systemImage: "checkmark.circle", description: Text("Captures wait here until they reach iPhone."))
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
                        .accessibilityHint(item.syncState == .synced ? "" : "Retries sending")
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

import SwiftUI
import UIKit

struct LifeBoardPlanRootView: View {
    @State private var store: PlanStore
    @State private var lens: PlanLens = .day
    @State private var showsBlockComposer = false
    @State private var selectedTaskIDs: Set<UUID> = []
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    init(repository: CoreDataPlanningRepository) {
        _store = State(initialValue: PlanStore(planningRepository: repository, blockRepository: repository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
            LifeBoardAtmosphereView(
                daypart: preferences.resolvedDaypart(),
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .frame(height: 230)
            .clipped()
            .ignoresSafeArea(edges: .top)

            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    Picker("Plan lens", selection: $lens) {
                        ForEach(PlanLens.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("plan.lens")

                    switch lens {
                    case .day: dayContent
                    case .week: weekContent
                    case .backlog: backlogContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .sheet(isPresented: $showsBlockComposer) {
            PlanBlockComposer(day: store.selectedDay) { title, start, duration in
                Task { await store.createBlock(title: title, start: start, duration: duration) }
            }
            .presentationDetents([.medium])
        }
        .alert("Plan needs attention", isPresented: errorBinding) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan with room to breathe")
                        .font(LifeBoardFoundationTypography.screenTitle())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    Text(dayTitle(store.selectedDay))
                        .font(LifeBoardFoundationTypography.body())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button { Task { await store.select(day: PlanningDay(date: Date())) } } label: {
                    Image(systemName: "calendar.circle.fill").font(.title2)
                }
                .accessibilityLabel("Return to today")
                if store.lastMutationReceiptID != nil {
                    Button { Task { await store.undoLastMutation() } } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .accessibilityLabel("Undo last planning change")
                }
            }

            HStack(spacing: 14) {
                Button { Task { await store.moveSelection(by: -1) } } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(contextLine)
                    .font(LifeBoardFoundationTypography.metric())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
                Button { Task { await store.moveSelection(by: 1) } } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 18)
        .frame(minHeight: 142, alignment: .bottom)
        .accessibilityIdentifier("plan.header")
    }

    @ViewBuilder private var dayContent: some View {
        if store.isLoading && store.daySnapshot == nil {
            ProgressView("Building your day").frame(maxWidth: .infinity).padding(40)
        } else if let snapshot = store.daySnapshot {
            capacityCard(snapshot.capacity)
            calendarState(snapshot)

            if snapshot.freeWindows.isEmpty == false {
                sectionHeader("Free windows", systemImage: "clock.badge.checkmark")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(snapshot.freeWindows) { window in freeWindowButton(window) }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if snapshot.commitments.isEmpty == false {
                sectionHeader("Fixed commitments", systemImage: "calendar")
                ForEach(snapshot.commitments) { commitmentCard($0) }
            }
            sectionHeader("Time blocks", systemImage: "rectangle.split.3x1", trailing: {
                Button { showsBlockComposer = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add time block")
            })
            if snapshot.blocks.isEmpty {
                emptyCard("No LifeBoard blocks yet", detail: "Add a calm focus window without changing your external calendar.", symbol: "calendar.badge.plus")
            } else {
                ForEach(snapshot.blocks) { blockCard($0) }
            }

            sectionHeader("Planned work", systemImage: "checklist")
            if snapshot.plannedTasks.isEmpty {
                emptyCard("This day is open", detail: "Choose work from the backlog when you are ready.", symbol: "sun.max")
            } else {
                ForEach(snapshot.plannedTasks) { taskCard($0, planned: true) }
            }

            sectionHeader("Unscheduled", systemImage: "tray")
            ForEach(snapshot.unscheduledTasks.prefix(8)) { taskCard($0, planned: false) }

            if !store.repairProposals.isEmpty {
                repairCard(store.repairProposals)
            }
        }
    }

    @ViewBuilder private var weekContent: some View {
        if let snapshot = store.weekSnapshot {
            let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(snapshot.days) { day in
                    Button {
                        lens = .day
                        Task { await store.select(day: day.day) }
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(shortDayTitle(day.day)).font(.headline)
                                Spacer()
                                if day.mustDoCount > 0 {
                                    Label("\(day.mustDoCount)", systemImage: "exclamationmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            ProgressView(value: loadFraction(day.capacity)).tint(loadColor(day.capacity))
                            HStack {
                                Text(loadLabel(day.capacity))
                                Spacer()
                                Text("\(day.deadlineCount) due")
                            }
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        .foundationClayCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan.week.\(day.day.year)-\(day.day.month)-\(day.day.day)")
                }
            }
            if !snapshot.unplannedTasks.isEmpty {
                emptyCard("\(snapshot.unplannedTasks.count) items still need a day", detail: "Open Backlog to place them in the week.", symbol: "rectangle.stack.badge.plus")
            }
        }
    }

    @ViewBuilder private var backlogContent: some View {
        if let snapshot = store.backlogSnapshot {
            ForEach(BacklogGroup.allCases, id: \.self) { group in
                let values = snapshot.groups[group] ?? []
                if !values.isEmpty {
                    sectionHeader(backlogTitle(group), systemImage: backlogSymbol(group))
                    ForEach(values) { taskCard($0, planned: taskIsPlanned($0)) }
                }
            }
            if snapshot.groups.values.allSatisfy(\.isEmpty) {
                emptyCard("Backlog clear", detail: "Everything open has a home.", symbol: "checkmark.seal")
            }
        }
    }

    private func capacityCard(_ capacity: CapacityBudget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(capacity.overloadDuration > 0 ? "Over capacity" : "Room in the day")
                        .font(.headline)
                    Text(loadLabel(capacity))
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Text(duration(capacity.usableDuration))
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("\(duration(capacity.usableDuration)) usable")
            }
            ProgressView(value: loadFraction(capacity)).tint(loadColor(capacity))
            HStack {
                Label("\(duration(capacity.plannedEstimatedDuration)) planned", systemImage: "checkmark.circle")
                Spacer()
                if capacity.isEstimateIncomplete {
                    Label("\(capacity.missingEstimateCount) estimates missing", systemImage: "questionmark.circle")
                } else {
                    Label("High confidence", systemImage: "checkmark.shield")
                }
            }
            .font(.caption)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.capacity")
    }

    @ViewBuilder
    private func calendarState(_ snapshot: PlanDaySnapshot) -> some View {
        switch snapshot.calendarAuthorization {
        case .notDetermined:
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                VStack(alignment: .leading, spacing: 3) {
                    Text("See real openings").font(.headline)
                    Text("Calendar stays read-only. LifeBoard only uses it to calculate free windows.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button("Allow") { Task { await store.requestCalendarAccess() } }
                    .buttonStyle(.bordered)
            }
            .foundationClayCard()
        case .denied, .restricted:
            Label("Calendar context is unavailable. Planning still works with LifeBoard blocks.", systemImage: "calendar.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .authorized, .unavailable:
            EmptyView()
        }
    }

    private func freeWindowButton(_ window: FreeWindow) -> some View {
        Button {
            Task {
                await store.createBlock(
                    title: "Focus block",
                    start: window.startAt,
                    duration: min(window.duration, 60 * 60)
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(time(window.startAt))–\(time(window.endAt))").font(.subheadline.weight(.semibold))
                Text("\(duration(window.duration)) open").font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Creates a one-hour LifeBoard block, or uses the full opening when shorter")
    }

    private func commitmentCard(_ commitment: PlanningFixedCommitment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: commitment.source == .externalCalendar ? "calendar" : "rectangle.inset.filled")
                .font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title).font(.headline)
                Text("\(time(commitment.startAt))–\(time(commitment.endAt)) · read-only context")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.nextCommitment")
    }

    private func blockCard(_ block: InternalTimeBlock) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.65)).frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title).font(.headline)
                Text("\(time(block.startAt))–\(time(block.endAt)) · \(duration(block.duration))")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Start focus", systemImage: "timer") {
                    Task {
                        await store.startFocus(taskID: block.taskID, timeBlockID: block.id, targetDuration: block.duration)
                        NotificationCenter.default.post(name: .lifeboardOpenFocusDeepLink, object: block.taskID)
                    }
                }
                Button("Add 15 minutes", systemImage: "plus") { Task { await store.resizeBlock(block, minutesDelta: 15) } }
                Button("Remove 15 minutes", systemImage: "minus") { Task { await store.resizeBlock(block, minutesDelta: -15) } }
                Button("Split block", systemImage: "rectangle.split.2x1") { Task { await store.splitBlock(block) } }
                Button("Remove", systemImage: "trash", role: .destructive) { Task { await store.deleteBlock(block) } }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.block.\(block.id.uuidString)")
    }

    private func taskCard(_ task: PlanningTaskSummary, planned: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.dependenciesReady ? "circle" : "lock.circle")
                .foregroundStyle(task.dependenciesReady ? Color(LifeBoardColorTokens.inkTertiary) : .orange)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(task.title).font(.body.weight(.medium)).lineLimit(2)
                    if task.metadata.commitmentLevel == .mustDo {
                        Text("MUST DO").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                    }
                }
                Text(taskMetadataLine(task))
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button(planned ? "Remove from day" : "Plan for this day", systemImage: "calendar") {
                    Task { await store.updateTask(task, planningDay: planned ? nil : store.selectedDay) }
                }
                Button(task.metadata.commitmentLevel == .mustDo ? "Make standard" : "Mark Must Do", systemImage: "exclamationmark.circle") {
                    Task { await store.updateTask(task, preserveDay: true, commitment: task.metadata.commitmentLevel == .mustDo ? .standard : .mustDo) }
                }
                Button("Waiting", systemImage: "hourglass") { Task { await store.updateTask(task, preserveDay: true, availability: .waiting) } }
                Button("Paused", systemImage: "pause.circle") { Task { await store.updateTask(task, preserveDay: true, availability: .paused) } }
                Button("Start focus", systemImage: "timer") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task {
                        await store.startFocus(
                            taskID: task.id,
                            timeBlockID: nil,
                            targetDuration: task.estimatedDuration ?? 25 * 60
                        )
                        NotificationCenter.default.post(name: .lifeboardOpenFocusDeepLink, object: task.id)
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Actions for \(task.title)")
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.task.\(task.id.uuidString)")
    }

    private func repairCard(_ proposals: [PlanRepairProposal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Plan repair", systemImage: "wand.and.stars")
                .font(.headline)
            Text(proposals.first?.explanation ?? "Your day has changed. Choose what should move; nothing changes automatically.")
                .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            HStack {
                Button("Move later") { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    .buttonStyle(.borderedProminent)
                Button("Leave unchanged") {}
                    .buttonStyle(.bordered)
            }
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.repair")
    }

    private func emptyCard(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
    }

    private func sectionHeader<Content: View>(_ title: String, systemImage: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(LifeBoardFoundationTypography.sectionTitle())
            Spacer()
            trailing()
        }
        .padding(.top, 6)
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        sectionHeader(title, systemImage: systemImage) { EmptyView() }
    }

    private var contextLine: String {
        guard let capacity = store.daySnapshot?.capacity else { return "Loading capacity…" }
        return capacity.overloadDuration > 0 ? "\(duration(capacity.overloadDuration)) overloaded" : "\(duration(capacity.remainingKnownCapacity)) known room"
    }

    private func taskIsPlanned(_ task: PlanningTaskSummary) -> Bool { task.metadata.planningDay != nil }
    private func loadFraction(_ value: CapacityBudget) -> Double { value.usableDuration > 0 ? min(1, value.plannedEstimatedDuration / value.usableDuration) : 0 }
    private func loadColor(_ value: CapacityBudget) -> Color { value.overloadDuration > 0 ? .orange : .brown }
    private func loadLabel(_ value: CapacityBudget) -> String {
        if value.overloadDuration > 0 { return "\(duration(value.overloadDuration)) over usable capacity" }
        return "\(duration(value.remainingKnownCapacity)) known capacity remains"
    }
    private func taskMetadataLine(_ task: PlanningTaskSummary) -> String {
        var values: [String] = [task.estimatedDuration.map(duration) ?? "Estimate incomplete"]
        if let due = task.dueDate { values.append("Due \(due.formatted(date: .abbreviated, time: .omitted))") }
        if task.metadata.availability != .actionable { values.append(task.metadata.availability.rawValue.capitalized) }
        if !task.dependenciesReady { values.append("Waiting on dependency") }
        return values.joined(separator: " · ")
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
    private func dayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? "Selected day" }
    private func shortDayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.abbreviated).day()) ?? "Day" }
    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func backlogTitle(_ group: BacklogGroup) -> String {
        switch group { case .thisWeek: "This Week"; case .nextWeek: "Next Week"; default: group.rawValue.capitalized }
    }
    private func backlogSymbol(_ group: BacklogGroup) -> String {
        switch group {
        case .inbox: "tray"; case .thisWeek: "calendar"; case .nextWeek: "calendar.badge.plus"
        case .later: "clock"; case .someday: "sparkles"; case .waiting: "hourglass"; case .paused: "pause.circle"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )
    }
}

private struct PlanBlockComposer: View {
    let day: PlanningDay
    let save: (String, Date, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start: Date
    @State private var minutes = 45.0

    init(day: PlanningDay, save: @escaping (String, Date, TimeInterval) -> Void) {
        self.day = day
        self.save = save
        let base = day.startDate() ?? Date()
        _start = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Block title", text: $title)
                DatePicker("Starts", selection: $start, displayedComponents: [.hourAndMinute])
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(minutes)) minutes")
                    Slider(value: $minutes, in: 15...180, step: 15)
                }
            }
            .navigationTitle("New time block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(title, start, minutes * 60); dismiss() }
                }
            }
        }
    }
}

private extension View {
    func foundationClayCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous).stroke(Color(LifeBoardColorTokens.foundationHairline).opacity(0.72), lineWidth: 0.75))
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 4, y: 2)
    }
}

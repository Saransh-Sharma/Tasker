import SwiftUI

struct InboxCaptureReviewSheet: View {
    let item: InboxItem
    @Bindable var store: InboxStore
    let onClose: () -> Void
    @State private var draft: InboxCaptureReviewDraft
    @State private var tagText: String
    @State private var projectText: String
    @State private var contextText: String
    @State private var selectedDuplicateID: UUID?
    @State private var mergeDestination: InboxMergeDestinationSnapshot?
    @State private var mergeResolution: DuplicateMergeResolution
    /// Drives `CommitControl`, so the button reports the real state of the
    /// write rather than dismissing optimistically.
    @State private var commitPhase: AsyncActionPhase<String> = .idle

    init(item: InboxItem, store: InboxStore, onClose: @escaping () -> Void) {
        self.item = item
        self.store = store
        self.onClose = onClose
        let parsed = TaskCaptureParser.parse(item.title, now: item.capturedAt)
        let captureID: UUID
        if case let .pendingCapture(id) = item.origin { captureID = id }
        else { captureID = item.id }
        let initialDraft = InboxCaptureReviewDraft(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: item.title
        )
        _draft = State(initialValue: initialDraft)
        _tagText = State(initialValue: initialDraft.tagNames.joined(separator: ", "))
        _projectText = State(initialValue: initialDraft.projectName ?? "")
        _contextText = State(initialValue: initialDraft.contextName ?? "")
        let duplicateID = store.duplicateCandidates(for: item).first?.existing.id
        _selectedDuplicateID = State(initialValue: duplicateID)
        _mergeResolution = State(initialValue: DuplicateMergeResolution(finalTitle: initialDraft.title))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $draft.title, prompt: Text("Task title").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                        .returnKeyEndsEditing(text: $draft.title)
                        .accessibilityIdentifier("plan.inbox.review.title")
                }
                .lifeBoardFormRowSurface()

                metadataSection
                    .lifeBoardFormRowSurface()

                if duplicates.isEmpty == false {
                    duplicateSection
                        .lifeBoardFormRowSurface()
                }

                if let error = store.mutationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color.lifeboard.statusWarning)
                    }
                    .lifeBoardFormRowSurface()
                }
            }
            // The warm canvas behind the grouped list, not the system's pure white
            // (light) or pure black (dark) grouped background.
            .scrollContentBackground(.hidden)
            .background { GrainedCanvas() }
            // A bare `Form` renders on `systemGroupedBackground` — a cool grey
            // that belongs to no part of this design system, and which read as a
            // different app from the warm canvas the capture was flicked out of.
            .lifeBoardFormSurface()
            .navigationTitle("Review capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
                // No confirmation toolbar item: the primary action lives in the
                // sheet's bottom action zone, which is where `DESIGN.md` puts it
                // and where a control large enough to morph through its own state
                // actually fits. Two primaries in one sheet would also break the
                // one-dominant-action rule.
            }
            .safeAreaInset(edge: .bottom) {
                CommitControl(
                    title: duplicates.isEmpty ? "File it" : "Keep both",
                    runningTitle: String(localized: "Filing…"),
                    successTitle: "Filed",
                    phase: commitPhase,
                    isEnabled: draft.commitRequest.title.isEmpty == false,
                    action: commit
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea(edges: .bottom)
                )
                .accessibilityIdentifier("plan.inbox.review.file")
            }
            .interactiveDismissDisabled(store.isMutating)
            .onChange(of: draft.title) { _, newValue in
                mergeResolution.finalTitle = newValue
            }
            .onChange(of: tagText) { _, newValue in
                draft.tagNames = newValue
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            }
            .onChange(of: projectText) { _, newValue in
                draft.projectName = newValue
            }
            .onChange(of: contextText) { _, newValue in
                draft.contextName = newValue
            }
            .task(id: selectedDuplicateID) {
                guard let selectedDuplicate else {
                    mergeDestination = nil
                    return
                }
                mergeDestination = await store.mergeDestination(for: selectedDuplicate.existing)
                mergeResolution = DuplicateMergeResolution(finalTitle: draft.title)
            }
        }
        .escapeCancels(perform: onClose)
        .presentationDetents([.large])
    }

    /// Files the reviewed capture, letting the control show the write's real state.
    ///
    /// The sheet stays open until the write actually succeeds. Dismissing first
    /// would leave a failure with nowhere to report — the capture survives a failed
    /// file by design, so the user has to be able to see that and retry.
    private func commit() {
        guard draft.commitRequest.title.isEmpty == false else { return }
        commitPhase = .running(progress: nil)
        Task {
            let filed = await store.fileCapture(item, draft: draft)
            guard filed else {
                commitPhase = .recoverableFailure(
                    AsyncActionFailure(
                        message: store.mutationError ?? String(localized: "Couldn’t file task."),
                        recovery: .retry
                    )
                )
                return
            }
            commitPhase = .success(receipt: draft.commitRequest.title)
            Haptic.commit.play()
            // Long enough to read as a confirmation, short enough not to feel like
            // a wait. The receipt and its Undo are waiting on the Inbox behind.
            try? await Task.sleep(for: .milliseconds(420))
            onClose()
        }
    }

    private var duplicates: [InboxDuplicateCandidate] {
        store.duplicateCandidates(for: item)
    }

    private var selectedDuplicate: InboxDuplicateCandidate? {
        guard let selectedDuplicateID else { return nil }
        return duplicates.first { $0.existing.id == selectedDuplicateID }
    }

    @ViewBuilder
    private var metadataSection: some View {
        Section("Details") {
            Toggle("Include date", isOn: Binding(
                get: { draft.dueDate != nil },
                set: { includesDate in
                    draft.dueDate = includesDate ? (draft.dueDate ?? item.capturedAt) : nil
                    if includesDate == false { draft.isAllDay = false }
                }
            ))
            if draft.dueDate != nil {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { draft.dueDate ?? item.capturedAt },
                        set: { draft.dueDate = $0 }
                    ),
                    displayedComponents: draft.isAllDay ? .date : [.date, .hourAndMinute]
                )
                Toggle("All day", isOn: $draft.isAllDay)
            }

            Picker("Estimate", selection: $draft.estimatedDuration) {
                Text("None").tag(nil as TimeInterval?)
                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                    Text(LifeBoardDuration.text(minutes: minutes)).tag(TimeInterval(minutes * 60) as TimeInterval?)
                }
            }

            Picker("Priority", selection: $draft.priority) {
                Text("Not set").tag(nil as TaskPriority?)
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority as TaskPriority?)
                }
            }

            Picker("Repeat", selection: $draft.repeatPattern) {
                ForEach(Array(Self.recurrenceOptions.enumerated()), id: \.offset) { _, option in
                    Text(option.title).tag(option.pattern)
                }
            }

            // Labelled rather than placeholder-only. A `TextField` loses its
            // placeholder the moment it has a value, so a parsed capture showed
            // two unexplained rows reading "home" and "admin" beneath a column of
            // labelled pickers — the parse was correct but unreadable.
            LabeledContent("Project") {
                TextField("None", text: $projectText, prompt: Text("None").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .accessibilityHint("New names file to Inbox")
            }
            LabeledContent("Context") {
                TextField("None", text: $contextText, prompt: Text("None").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }
            LabeledContent("Tags") {
                TextField("Comma separated", text: $tagText, prompt: Text("Comma separated").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
            }
        }
    }

    @ViewBuilder
    private var duplicateSection: some View {
        Section("Possible duplicate") {
            if duplicates.count > 1 {
                Picker("Compare with", selection: $selectedDuplicateID) {
                    ForEach(duplicates.prefix(3), id: \.existing.id) { candidate in
                        Text(candidate.existing.title).tag(candidate.existing.id as UUID?)
                    }
                }
            } else if let candidate = duplicates.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.existing.title)
                    Text("\(Int((candidate.similarity * 100).rounded()))% title match")
                        .font(.caption)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
            }

            if let destination = mergeDestination, let selectedDuplicate {
                comparisonRow(
                    "Date",
                    existing: Self.dateDescription(destination.dueDate, isAllDay: destination.isAllDay),
                    reviewed: Self.dateDescription(draft.dueDate, isAllDay: draft.isAllDay)
                )
                comparisonRow(
                    "Project",
                    existing: destination.projectName ?? "Inbox",
                    reviewed: draft.projectName ?? "Inbox"
                )
                comparisonRow(
                    "Priority",
                    existing: destination.priority?.displayName ?? "Not set",
                    reviewed: draft.priority?.displayName ?? "Not set"
                )
                comparisonRow(
                    "Repeat",
                    existing: destination.repeatPattern?.displayName ?? "Never",
                    reviewed: draft.repeatPattern?.displayName ?? "Never"
                )
                comparisonRow(
                    "Tags",
                    existing: destination.tagNames.isEmpty ? "None" : destination.tagNames.joined(separator: ", "),
                    reviewed: draft.tagNames.isEmpty ? "None" : draft.tagNames.joined(separator: ", ")
                )

                let conflicts = mergeResolution.conflicts(reviewed: draft, destination: destination)
                if conflicts.isEmpty == false {
                    Text("Confirm each choice to merge.")
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                ForEach(DuplicateMergeResolution.Field.allCases.filter(conflicts.contains), id: \.self) { field in
                    Picker("Use \(field.title)", selection: conflictBinding(field)) {
                        Text("Existing").tag(DuplicateMergeResolution.Choice.destination)
                        Text("Reviewed").tag(DuplicateMergeResolution.Choice.reviewed)
                    }
                    .accessibilityValue(
                        mergeResolution.acknowledgedFields.contains(field)
                            ? "Confirmed"
                            : "Not confirmed"
                    )
                    .accessibilityHint("Pick which to keep")
                }

                Button("Merge into “\(selectedDuplicate.existing.title)”") {
                    guard let request = mergeResolution.commitRequest(
                        reviewed: draft,
                        destination: destination
                    ) else { return }
                    Task {
                        if await store.mergeCapture(item, request: request, with: selectedDuplicate.existing) {
                            onClose()
                        }
                    }
                }
                .disabled(
                    store.isMutating ||
                    mergeResolution.isComplete(reviewed: draft, destination: destination) == false
                )
                .accessibilityIdentifier("plan.inbox.review.merge")
            } else {
                ProgressView("Loading…")
            }
        }
    }

    private func comparisonRow(_ label: String, existing: String, reviewed: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            HStack(alignment: .firstTextBaseline) {
                Text("Existing: \(existing)")
                Spacer(minLength: 12)
                Text("Reviewed: \(reviewed)")
            }
            .font(.footnote)
        }
        .accessibilityElement(children: .combine)
    }

    private func conflictBinding(
        _ field: DuplicateMergeResolution.Field
    ) -> Binding<DuplicateMergeResolution.Choice> {
        Binding(
            get: { mergeResolution.choices[field] ?? .destination },
            set: { mergeResolution.select($0, for: field) }
        )
    }

    private static var recurrenceOptions: [(title: String, pattern: TaskRepeatPattern?)] {
        [
            ("Never", nil),
            ("Daily", .daily),
            ("Weekdays", .weekdays),
            ("Weekly", .weekly(.allDays)),
            ("Monthly", .monthly(.onDate(Calendar.current.component(.day, from: Date())))),
            ("Yearly", .yearly(.onDate(
                month: Calendar.current.component(.month, from: Date()),
                day: Calendar.current.component(.day, from: Date())
            )))
        ]
    }

    private static func dateDescription(_ date: Date?, isAllDay: Bool) -> String {
        guard let date else { return "Not set" }
        return date.formatted(date: .abbreviated, time: isAllDay ? .omitted : .shortened)
    }
}

private extension DuplicateMergeResolution.Field {
    var title: String {
        switch self {
        case .date: "Date"
        case .project: "Project"
        case .priority: "Priority"
        case .recurrence: "Repeat"
        }
    }
}

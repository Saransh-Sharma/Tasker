import Charts
import Observation
import SwiftUI

@MainActor @Observable
final class LifeMomentsStore {
    private(set) var moments: [LifeMoment] = []
    private(set) var isLoading = false
    var errorMessage: String?
    let repository: any LifeMomentRepository
    init(repository: any LifeMomentRepository) { self.repository = repository }
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            moments = try await repository.moments(includeArchived: false)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn’t load moments")
        }
    }
    /// The last archive, with the moment as it was so Undo can put it back.
    private(set) var archiveReceipt: LifeMomentArchiveReceipt?

    func save(_ value: LifeMoment) async {
        do {
            try await repository.save(value)
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t save moment")
        }
    }

    /// Archiving is reversible, so it runs at once and offers Undo.
    @discardableResult
    func archive(_ value: LifeMoment) async -> Bool {
        do {
            try await repository.archive(id: value.id, at: Date())
            Haptic.commit.play()
            archiveReceipt = LifeMomentArchiveReceipt(original: value)
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
            return true
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t archive moment")
            return false
        }
    }

    func undoArchive() async {
        guard let receipt = archiveReceipt else { return }
        var restored = receipt.original
        restored.isArchived = false
        restored.updatedAt = max(Date(), restored.updatedAt)
        do {
            try await repository.save(restored)
            archiveReceipt = nil
            Haptic.pick.play()
            await load()
            SystemSurfaceRefresher.requestRefreshSoon()
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t restore moment")
        }
    }

    func dismissArchiveReceipt() { archiveReceipt = nil }

    /// Deletes without reloading, so the card can dissolve over a write that
    /// already succeeded; the caller reloads once the dissolve has played.
    @discardableResult
    func delete(_ value: LifeMoment, reloads: Bool = true) async -> Bool {
        do {
            try await repository.delete(id: value.id)
            Haptic.commit.play()
            if reloads { await load() }
            SystemSurfaceRefresher.requestRefreshSoon()
            return true
        } catch {
            Haptic.fail.play()
            errorMessage = String(localized: "Couldn’t delete moment")
            return false
        }
    }
}

struct LifeMomentArchiveReceipt: Identifiable {
    let id = UUID()
    let original: LifeMoment

    var presentation: ActionReceiptPresentation {
        ActionReceiptPresentation(id: id, message: "Archived \u{201C}\(original.title)\u{201D}")
    }
}

struct LifeMomentsView: View {
    @State private var store: LifeMomentsStore
    @State private var focus: LifeMomentsFocus
    @State private var showsComposer = false
    @State private var editing: LifeMoment?
    @State private var searchText = ""
    @State private var didApplyInitialFocus = false

    init(
        repository: any LifeMomentRepository,
        initialFocus: LifeMomentsFocus = .overview
    ) {
        _store = State(initialValue: LifeMomentsStore(repository: repository))
        _focus = State(initialValue: initialFocus)
    }

    private var filteredMoments: [LifeMoment] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.isEmpty == false else { return store.moments }
        return store.moments.filter {
            $0.title.lowercased().contains(query) || ($0.note?.lowercased().contains(query) ?? false)
        }
    }

    /// Explicit, user-triggered JSON export. Nothing leaves the device unless
    /// the user picks a share destination themselves.
    private var exportPayload: String {
        struct Export: Codable {
            let title: String; let kind: String; let eventDate: Date
            let recurrence: String; let note: String?
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let values = store.moments.map { moment in
            let recurrence: String = switch moment.recurrenceRule {
            case .none: "never"
            case .weekly: "weekly"
            case .monthly: "monthly"
            case .yearly: "yearly"
            case .everyDays(let days): "every \(days) days"
            }
            return Export(title: moment.title, kind: moment.kind.rawValue, eventDate: moment.eventDate,
                          recurrence: recurrence, note: moment.note)
        }
        return (try? encoder.encode(values)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let receipt = store.archiveReceipt {
                    ReceiptBar(
                        receipt.presentation,
                        undo: { Task { await store.undoArchive() } },
                        onDismiss: { store.dismissArchiveReceipt() }
                    )
                    .accessibilityIdentifier("lifeMoments.archive.receipt")
                }
                if store.isLoading, store.moments.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if let error = store.errorMessage, store.moments.isEmpty {
                    StatusSurface(
                        state: .recoverableError,
                        title: error,
                        message: ""
                    )
                    Button("Try again") { Task { await store.load() } }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if case .moment(let id) = focus,
                          let moment = store.moments.first(where: { $0.id == id }) {
                    LifeMomentFocusedDetail(
                        moment: moment,
                        edit: {
                            editing = moment
                            showsComposer = true
                        },
                        archive: {
                            Task { if await store.archive(moment) { focus = .overview } }
                        },
                        delete: {
                            Task { if await store.delete(moment) { focus = .overview } }
                        }
                    )
                    momentsList(omitting: id)
                } else if case .moment = focus {
                    // `.unavailable` rather than `.recoverableError`: an archived
                    // or deleted moment is not something a retry can bring back,
                    // and DESIGN.md says an unavailable state never offers one.
                    StatusSurface(
                        state: .unavailable,
                        title: String(localized: "Moment not found"),
                        message: String(localized: "It may have been archived or deleted.")
                    )
                    Button("View all moments") { focus = .overview }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if store.moments.isEmpty {
                    StatusSurface(
                        state: .empty,
                        title: String(localized: "No moments yet"),
                        message: String(localized: "Private unless you show them on Home.")
                    )
                    .padding(.top, 40)
                    Button("Add moment") { editing = nil; showsComposer = true }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    momentsList(omitting: nil)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 132)
        }
        .accessibilityIdentifier("lifeMoments.workspace")
        .background {
            GrainedCanvas()
        }
        .navigationTitle("Life moments")
        .searchable(text: $searchText, prompt: "Search moments")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.moments.isEmpty == false {
                    ShareLink(item: exportPayload, preview: SharePreview("Life moments")) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Add moment", systemImage: "plus") { editing = nil; showsComposer = true }
            }
        }
        .task {
            await store.load()
            guard didApplyInitialFocus == false else { return }
            didApplyInitialFocus = true
            if focus == .add {
                editing = nil
                showsComposer = true
            }
        }
        .sheet(isPresented: $showsComposer) { LifeMomentComposer(existing: editing) { value in Task { await store.save(value) } } }
        .alert(store.errorMessage ?? String(localized: "Couldn’t update moments"), isPresented: Binding(
            get: { store.errorMessage != nil && store.moments.isEmpty == false },
            set: { if $0 == false { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        }
    }

    @ViewBuilder
    private func momentsList(omitting omittedID: UUID?) -> some View {
        Text("Moments")
            .font(Typography.sectionTitle())
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .padding(.horizontal, 4)
        ForEach(filteredMoments.filter { $0.id != omittedID }) { moment in
            LifeMomentCard(moment: moment) {
                focus = .moment(moment.id)
            } archive: {
                Task { await store.archive(moment) }
            } delete: {
                await store.delete(moment, reloads: false)
            } didDissolve: {
                Task { await store.load() }
            }
        }
    }
}

private struct LifeMomentFocusedDetail: View {
    let moment: LifeMoment
    let edit: () -> Void
    let archive: () -> Void
    let delete: () -> Void
    @State private var confirmsDelete = false

    private var countdown: String {
        guard let days = moment.calendarDaysUntilNextOccurrence(from: Date()) else { return "Past" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days away"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(countdown)
                .font(Typography.screenTitle())
            Text(moment.title)
                .font(Typography.sectionTitle())
            LabeledContent("Date", value: moment.eventDate.formatted(date: .long, time: .omitted))
            LabeledContent("Repeats", value: recurrenceTitle)
            LabeledContent("Home", value: moment.permitsHomeDisplay ? String(localized: "Shown") : String(localized: "Hidden"))
            if let note = moment.note, note.isEmpty == false {
                Text(note)
                    .font(.body)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Button("Edit moment", systemImage: "pencil", action: edit)
                .buttonStyle(.lifeBoardPrimaryCompact)
                .frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityIdentifier("lifeMoment.edit")
            // Archive and Delete were reachable only from a card's context
            // menu, which the focused detail omits.
            HStack(spacing: 12) {
                Button("Archive", systemImage: "archivebox", action: archive)
                    .buttonStyle(.lifeBoardChip)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("lifeMoment.archive")
                Button("Delete…", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    .buttonStyle(.lifeBoardChip)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("lifeMoment.delete")
            }
        }
        .confirmationDialog(
            "Delete \u{201C}\(moment.title)\u{201D}?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete moment", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can’t be undone. Archive hides it instead.")
        }
        .padding(20)
        .featureHeaderArtwork(.moment)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.largeCard)
        .accessibilityElement(children: .contain)
    }

    private var recurrenceTitle: String {
        switch moment.recurrenceRule {
        case .none: "Never"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .everyDays(let days): "Every \(days) days"
        }
    }
}

/// One meaningful date, as an object rather than a table row.
///
/// The list used `List` + `swipeActions`, which put archive and delete behind a
/// gesture with no visible equivalent. On clay the row becomes a card and the
/// two actions move into a menu, so they are reachable by pointer, keyboard and
/// VoiceOver as well as by knowing to swipe.
private struct LifeMomentCard: View {
    let moment: LifeMoment
    let open: () -> Void
    let archive: () -> Void
    /// Performs the repository delete and reports whether it saved.
    let delete: () async -> Bool
    /// Called once the dissolve has played over a successful delete.
    let didDissolve: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeBoardTransitionCoordinator) private var transitions
    @State private var developProgress: Double = 1
    @State private var dissolveProgress: Double = 0
    @State private var confirmsDelete = false

    private var countdown: (label: String, isPast: Bool) {
        guard let days = moment.calendarDaysUntilNextOccurrence(from: Date()) else {
            return ("Past", true)
        }
        return (days == 0 ? "Today" : "\(days)d", false)
    }

    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: moment.kind == .countdown ? "hourglass" : "calendar.badge.heart")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                    .frame(width: 34, height: 34)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.title)
                        .font(.lifeboard(.bodyStrong))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .multilineTextAlignment(.leading)
                    Text(moment.eventDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer(minLength: 8)

                if dynamicTypeSize.isAccessibilitySize == false {
                    countdownBadge
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lifeBoardClay(.raised, cornerRadius: Radius.largeCard))
        // A Life Moment is literally a memory, which is what DESIGN.md reserves
        // `memoryDevelopReveal` for. Claimed once per card per window session so
        // it develops when the card first arrives and never again on scroll —
        // repeated rows stay quiet.
        .lifeboardMemoryDevelopReveal(progress: developProgress)
        // The dissolve runs only after the repository delete resolves. A card
        // that erodes ahead of a failing write is a lie about the data.
        .lifeboardDissolveAway(
            progress: dissolveProgress,
            tint: Color(SemanticColorTokens.foundationApricotAccent)
        )
        .lifeBoardScrollEntrance(intensity: 0.7)
        .task {
            guard transitions?.claimOneShot("lifeMoment.develop.\(moment.id)") == true else { return }
            developProgress = 0
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { developProgress = 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(moment.title), \(moment.eventDate.formatted(date: .abbreviated, time: .omitted)), \(countdown.label)"))
        .accessibilityAction(named: Text("Archive"), archive)
        .accessibilityAction(named: Text("Delete"), performDelete)
        .contextMenu {
            Button("Archive", systemImage: "archivebox", action: archive)
            Button("Delete", systemImage: "trash", role: .destructive, action: performDelete)
        }
        .confirmationDialog(
            "Delete \u{201C}\(moment.title)\u{201D}?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete moment", role: .destructive) {
                Task {
                    // Persist first; the dissolve is the receipt of a write
                    // that already succeeded, never a promise ahead of one.
                    guard await delete() else { return }
                    withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
                        dissolveProgress = 1
                    } completion: {
                        didDissolve()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can’t be undone. Archive hides it instead.")
        }
    }

    /// Persist first, then dissolve. The caller's `delete` closure owns the
    /// repository write; the erosion is only the receipt of it.
    private func performDelete() {
        confirmsDelete = true
    }

    private var countdownBadge: some View {
        Text(countdown.label)
            .font(.lifeboard(.bodyStrong))
            .monospacedDigit()
            .foregroundStyle(
                Color(countdown.isPast
                    ? SemanticColorTokens.inkTertiary
                    : SemanticColorTokens.inkPrimary)
            )
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
            .accessibilityHidden(true)
    }
}

private struct LifeMomentComposer: View {
    let existing: LifeMoment?
    let onSave: (LifeMoment) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var kind: LifeMomentKind
    @State private var recurrence: LifeMomentRecurrenceRule
    @State private var note: String
    @State private var homeDisplay: Bool
    @State private var successTrigger = 0
    init(existing: LifeMoment?, onSave: @escaping (LifeMoment) -> Void) {
        self.existing = existing; self.onSave = onSave
        _title = State(initialValue: existing?.title ?? ""); _date = State(initialValue: existing?.eventDate ?? Date())
        _kind = State(initialValue: existing?.kind ?? .countdown); _recurrence = State(initialValue: existing?.recurrenceRule ?? .none)
        _note = State(initialValue: existing?.note ?? ""); _homeDisplay = State(initialValue: existing?.permitsHomeDisplay ?? false)
    }
    var body: some View {
        ComposerScaffold(
            title: existing == nil ? String(localized: "New moment") : String(localized: "Edit moment"),
            confirmTitle: String(localized: "Save"),
            isConfirmEnabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            identifier: "lifeMoment.composer",
            onConfirm: save
        ) {
            MomentDetailSection(title: $title, date: $date, kind: $kind)
            MomentRepeatSection(recurrence: $recurrence)
            MomentPrivacySection(homeDisplay: $homeDisplay)
            MomentNoteSection(note: $note)
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func save() {
        guard let value = try? LifeMoment(
            id: existing?.id ?? UUID(),
            title: title,
            kind: kind,
            eventDate: date,
            recurrenceRule: recurrence,
            note: note,
            sensitivity: existing?.sensitivity ?? .privateStandard,
            permitsHomeDisplay: homeDisplay,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        ) else { return }
        onSave(value)
        successTrigger &+= 1
        dismiss()
    }
}

private struct MomentDetailSection: View {
    @Binding var title: String
    @Binding var date: Date
    @Binding var kind: LifeMomentKind

    var body: some View {
        ComposerSection("Moment") {
            ComposerField(
                "Title",
                prompt: "Moment name",
                text: $title,
                showsLabel: false,
                identifier: "lifeMoment.title"
            )
            DateCapsuleRow("Date", selection: $date)
            OptionRail(
                "Kind",
                selection: $kind,
                values: LifeMomentKind.allCases,
                identifierPrefix: "lifeMoment.kind",
                title: Self.kindTitle,
                systemImage: { $0 == .countdown ? "hourglass" : "calendar.badge.heart" }
            )
        }
    }

    /// The raw value is a camel-cased identifier; `.capitalized` alone turned it
    /// into "Recurringmeaningfulevent" on screen. Every kind gets its own name:
    /// the old two-way ternary labelled three different chips "Recurring event".
    private static func kindTitle(_ kind: LifeMomentKind) -> String {
        switch kind {
        case .countdown: String(localized: "Countdown")
        case .anniversary: String(localized: "Anniversary")
        case .milestone: String(localized: "Milestone")
        case .recurringMeaningfulEvent: String(localized: "Recurring event")
        }
    }
}

private struct MomentRepeatSection: View {
    @Binding var recurrence: LifeMomentRecurrenceRule

    private static let options: [LifeMomentRecurrenceRule] = [.none, .weekly, .monthly, .yearly]

    var body: some View {
        ComposerSection("Repeat") {
            OptionRail(
                "Recurrence",
                selection: $recurrence,
                values: Self.options,
                identifierPrefix: "lifeMoment.recurrence",
                title: Self.title,
                showsLabel: false
            )
        }
    }

    private static func title(_ rule: LifeMomentRecurrenceRule) -> String {
        switch rule {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        default: "Never"
        }
    }
}

private struct MomentPrivacySection: View {
    @Binding var homeDisplay: Bool

    var body: some View {
        ComposerSection(
            "Privacy",
            footer: String(localized: "Stays off Home and widgets unless this is on.")
        ) {
            Toggle("Show on Home", isOn: $homeDisplay)
                .toggleStyle(.lifeBoardClay)
                .accessibilityIdentifier("lifeMoment.homeDisplay")
        }
    }
}

private struct MomentNoteSection: View {
    @Binding var note: String

    var body: some View {
        ComposerSection("Note") {
            ComposerField(
                "Optional note",
                prompt: "Optional",
                text: $note,
                shape: .prose(lineLimit: 2...6),
                showsLabel: false
            )
        }
    }
}

import Charts
import Observation
import SwiftUI

@MainActor @Observable
final class LifeMomentsStore {
    private(set) var moments: [LifeMoment] = []
    var errorMessage: String?
    let repository: any LifeMomentRepository
    init(repository: any LifeMomentRepository) { self.repository = repository }
    func load() async { do { moments = try await repository.moments(includeArchived: false); errorMessage = nil } catch { errorMessage = "Moments are unavailable right now." } }
    func save(_ value: LifeMoment) async { do { try await repository.save(value); await load(); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
    func archive(_ value: LifeMoment) async { do { try await repository.archive(id: value.id, at: Date()); await load(); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
    func delete(_ value: LifeMoment) async { do { try await repository.delete(id: value.id); await load(); SystemSurfaceRefresher.requestRefreshSoon() } catch { errorMessage = error.localizedDescription } }
}

struct LifeMomentsView: View {
    @State private var store: LifeMomentsStore
    @State private var showsComposer = false
    @State private var editing: LifeMoment?
    @State private var searchText = ""
    init(repository: any LifeMomentRepository) { _store = State(initialValue: LifeMomentsStore(repository: repository)) }

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
                if store.moments.isEmpty {
                    ContentUnavailableView(
                        "Keep a meaningful date close",
                        systemImage: "sparkles",
                        description: Text("Countdowns and anniversaries stay private unless you allow Home display.")
                    )
                    .padding(.top, 40)
                } else {
                    Text("Meaningful moments")
                        .font(Typography.sectionTitle())
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .padding(.horizontal, 4)
                }
                ForEach(filteredMoments) { moment in
                    LifeMomentCard(moment: moment) {
                        editing = moment
                        showsComposer = true
                    } archive: {
                        Task { await store.archive(moment) }
                    } delete: {
                        Task { await store.delete(moment) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 132)
        }
        .background {
            GrainedCanvas()
        }
        .navigationTitle("Life Moments")
        .searchable(text: $searchText, prompt: "Search moments")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.moments.isEmpty == false {
                    ShareLink(item: exportPayload, preview: SharePreview("Life Moments export")) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Add moment", systemImage: "plus") { editing = nil; showsComposer = true }
            }
        }
        .task { await store.load() }
        .sheet(isPresented: $showsComposer) { LifeMomentComposer(existing: editing) { value in Task { await store.save(value) } } }
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
    let delete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeBoardTransitionCoordinator) private var transitions
    @State private var developProgress: Double = 1
    @State private var dissolveProgress: Double = 0

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
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
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
            withAnimation(.easeOut(duration: 0.7)) { developProgress = 1 }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(moment.title), \(moment.eventDate.formatted(date: .abbreviated, time: .omitted)), \(countdown.label)"))
        .accessibilityAction(named: Text("Archive"), archive)
        .accessibilityAction(named: Text("Delete"), performDelete)
        .contextMenu {
            Button("Archive", systemImage: "archivebox", action: archive)
            Button("Delete", systemImage: "trash", role: .destructive, action: performDelete)
        }
    }

    /// Persist first, then dissolve. The caller's `delete` closure owns the
    /// repository write; the erosion is only the receipt of it.
    private func performDelete() {
        delete()
        withAnimation(.easeIn(duration: 0.42)) { dissolveProgress = 1 }
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
            title: existing == nil ? "New Moment" : "Edit Moment",
            subtitle: "A date worth keeping close.",
            confirmTitle: "Save",
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
                prompt: "Anniversary, first day, the trip…",
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
    /// into "Recurringmeaningfulevent" on screen.
    private static func kindTitle(_ kind: LifeMomentKind) -> String {
        kind == .countdown ? "Countdown" : "Recurring event"
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
            footer: "The title and date stay off Home, widgets, and suggestions until enabled."
        ) {
            Toggle("Allow date on Home", isOn: $homeDisplay)
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
                prompt: "Why this one matters…",
                text: $note,
                shape: .prose(lineLimit: 2...6),
                showsLabel: false
            )
        }
    }
}

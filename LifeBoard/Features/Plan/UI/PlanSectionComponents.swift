import SwiftUI
import UIKit

/// Pure derivations shared by the Plan sections.
///
/// `@MainActor` is required: these read `@Observable @MainActor` stores.
@MainActor
enum PlanSectionCopy {
    /// The app's one duration format ("45 min", "1 hr, 30 min").
    static func duration(_ seconds: TimeInterval) -> String {
        LifeBoardDuration.text(seconds: max(0, seconds))
    }

    static func shortDayTitle(_ day: PlanningDay) -> String {
        day.startDate()?.formatted(.dateTime.weekday(.abbreviated).day()) ?? "Day"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func loadFraction(_ value: CapacityBudget) -> Double {
        value.usableDuration > 0 ? min(1, value.plannedEstimatedDuration / value.usableDuration) : 0
    }

    static func loadColor(_ value: CapacityBudget) -> Color {
        value.overloadDuration > 0
            ? Color(SemanticColorTokens.foundationApricotInk)
            : Color(SemanticColorTokens.foundationFocusRing)
    }

    static func loadLabel(_ value: CapacityBudget) -> String {
        if value.overloadDuration > 0 { return "\(duration(value.overloadDuration)) over" }
        return "\(duration(value.remainingKnownCapacity)) open"
    }

    static func shifted(_ day: PlanningDay, by offset: Int) -> PlanningDay? {
        guard let date = day.startDate(),
              let moved = Calendar.current.date(byAdding: .day, value: offset, to: date) else { return nil }
        return PlanningDay(date: moved, timeZone: TimeZone(identifier: day.timeZoneIdentifier) ?? .current)
    }
}

/// Plan's section header, now a thin wrapper over the shared one.
///
/// It used to be its own `HStack` with its own font and no `.isHeader` trait, so
/// nine of Plan's sections were invisible to VoiceOver's heading rotor and none
/// of them stacked at accessibility text sizes. `DESIGN.md`: one type size and
/// one spacing across the product, and a restyled section header is a defect.
/// The wrapper stays so Plan's call sites keep reading in Plan's own vocabulary.
struct PlanSectionHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    var count: Int?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        SectionHeader(title, symbol: systemImage, count: count, trailing: trailing)
            .padding(.top, 8)
    }
}

extension PlanSectionHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String, count: Int? = nil) {
        self.init(title: title, systemImage: systemImage, count: count) { EmptyView() }
    }
}

struct PlanEmptyCard: View {
    let title: String
    /// Optional by design: an empty state is a title plus one action, and a
    /// body line only when it adds a fact the title doesn't carry.
    let detail: String?
    let symbol: String
    /// An empty state offers one action (DESIGN.md contract 6).
    var actionTitle: String? = nil
    var actionIdentifier: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            if symbol == "sun.max" {
                Image(decorative: AtmosphereDescriptor.descriptor(for: .midday).celestialAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).lifeboardFont(.headline)
                if let detail {
                    Text(detail).lifeboardFont(.caption1).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                if let actionTitle, let action {
                    Button(actionTitle) {
                        Haptic.pick.play()
                        action()
                    }
                    .buttonStyle(.lifeBoardChip)
                    .padding(.top, 4)
                    .accessibilityIdentifier(actionIdentifier ?? "plan.emptyCard.action")
                }
            }
            Spacer()
        }
        .foundationClayCard()
    }
}

/// What the Backlog shows while its snapshot is still `nil`.
///
/// `PlanBacklogSection` wrapped its whole body in `if let snapshot`, with no
/// `else` — so a cold open of the Backlog lens painted an empty pane until the
/// store answered. The *empty* case was always handled (`PlanEmptyCard`,
/// "Backlog clear"); only loading was missing, which is the one state a person
/// cannot tell apart from "nothing here".
///
/// Deliberately shaped like the rows it stands in for — a header bar and three
/// card silhouettes — so the layout does not jump when real content arrives.
struct PlanBacklogSkeleton: View {
    var rowCount: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color(SemanticColorTokens.inkTertiary).opacity(0.18))
                .frame(width: 132, height: 14)

            ForEach(0..<rowCount, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Capsule()
                        .fill(Color(SemanticColorTokens.inkTertiary).opacity(0.20))
                        .frame(height: 14)
                        .frame(maxWidth: index.isMultiple(of: 2) ? .infinity : 220, alignment: .leading)
                    Capsule()
                        .fill(Color(SemanticColorTokens.inkTertiary).opacity(0.12))
                        .frame(width: 96, height: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foundationClayCard()
            }
        }
        .shimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading backlog")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("plan.backlog.loading")
    }
}

/// The read-only calendar banner. Always drawn on the day lens, so as a
/// computed property it was one of the largest single contributors to the
/// root's inlined view value.
struct PlanCalendarStateSection: View {
    let store: PlanStore
    let snapshot: PlanDaySnapshot

    var body: some View {
        switch snapshot.calendarState {
        case .notRequested:
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Show your calendar").font(.subheadline.weight(.semibold))
                    Text("Your events stay unchanged.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                Button("Allow") {
                    Task {
                        // Record through the shared gate so the just-in-time
                        // layer knows we have asked and never double-prompts.
                        PermissionPromptState.recordRequested(.calendar)
                        await store.requestCalendarAccess()
                    }
                }
                .buttonStyle(.lifeBoardChip)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .lifeBoardGlassSurface(cornerRadius: Radius.card, interactive: true)
            .accessibilityIdentifier("plan.calendar.notRequested")
        case .denied:
            HStack(spacing: 12) {
                Label("Calendar access is off", systemImage: "calendar.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Spacer()
                Button("Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .lifeBoardGlassSurface(cornerRadius: Radius.card, interactive: true)
            .accessibilityIdentifier("plan.calendar.denied")
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading…")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Color(SemanticColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
            )
            .accessibilityIdentifier("plan.calendar.loading")
        case .fresh(let fetchedAt):
            Label(
                Self.freshSummary(count: snapshot.commitments.count, fetchedAt: fetchedAt),
                systemImage: "calendar.badge.checkmark"
            )
            .font(.caption)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier("plan.calendar.fresh")
        case .staleCached(let fetchedAt, let message):
            PlanCalendarCacheWarning(
                store: store,
                title: String(localized: "Calendar may be outdated"),
                detail: String(localized: "Updated \(fetchedAt.formatted(date: .omitted, time: .shortened)). \(message)"),
                symbol: "clock.arrow.circlepath",
                identifier: "plan.calendar.stale"
            )
        case .offlineCached(let fetchedAt):
            PlanCalendarCacheWarning(
                store: store,
                title: String(localized: "Calendar offline"),
                detail: String(localized: "Showing events from \(fetchedAt.formatted(date: .omitted, time: .shortened))."),
                symbol: "wifi.slash",
                identifier: "plan.calendar.offline"
            )
        case .failed(let message):
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn’t refresh calendar")
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .lineLimit(2)
                }
                Spacer()
                Button("Try again") { Task { await store.load() } }
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 12)
            .background(
                Color(SemanticColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
            )
            .accessibilityIdentifier("plan.calendar.failed")
        }
    }

    private static func freshSummary(count: Int, fetchedAt: Date) -> String {
        let time = fetchedAt.formatted(date: .omitted, time: .shortened)
        return count == 1
            ? String(localized: "1 event · Updated \(time)")
            : String(localized: "\(count) events · Updated \(time)")
    }
}

struct PlanCalendarCacheWarning: View {
    let store: PlanStore
    let title: String
    let detail: String
    let symbol: String
    let identifier: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            Spacer()
            Button("Try again") { Task { await store.load() } }
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(
            Color(SemanticColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        )
        .accessibilityIdentifier(identifier)
    }
}

struct PlanCalibrationSuggestionRow: View {
    let store: PlanStore
    let suggestion: EstimateCalibrationSuggestion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer.square")
                .foregroundStyle(Color(SemanticColorTokens.foundationSageInk))
            VStack(alignment: .leading, spacing: 2) {
                Text("Usually \(PlanSectionCopy.duration(suggestion.suggestedDuration))")
                    .font(.caption.weight(.semibold))
                Text(
                    "^[\(suggestion.evidenceSessionCount) session](inflect: true) · \(PlanSectionCopy.duration(suggestion.observedMinimum))–\(PlanSectionCopy.duration(suggestion.observedMaximum))"
                )
                .font(.caption2)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer(minLength: 4)
            Button("Use estimate") {
                Task { await store.acceptCalibration(suggestion) }
            }
            .font(.caption.weight(.semibold))
            .frame(minHeight: 44)
        }
        .overlay(alignment: .top) {
            Divider()
                .offset(y: -5)
        }
        .accessibilityIdentifier(
            "plan.calibration.\(suggestion.taskID.uuidString)"
        )
    }
}

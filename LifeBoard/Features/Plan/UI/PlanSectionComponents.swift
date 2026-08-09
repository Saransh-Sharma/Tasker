import SwiftUI
import UIKit

/// Pure derivations shared by the Plan sections.
///
/// `@MainActor` is required: these read `@Observable @MainActor` stores.
@MainActor
enum PlanSectionCopy {
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
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
            ? Color(LifeBoardColorTokens.foundationApricotAccent)
            : Color(LifeBoardColorTokens.foundationFocusRing)
    }

    static func loadLabel(_ value: CapacityBudget) -> String {
        if value.overloadDuration > 0 { return "\(duration(value.overloadDuration)) over usable capacity" }
        return "\(duration(value.remainingKnownCapacity)) known capacity remains"
    }

    static func shifted(_ day: PlanningDay, by offset: Int) -> PlanningDay? {
        guard let date = day.startDate(),
              let moved = Calendar.current.date(byAdding: .day, value: offset, to: date) else { return nil }
        return PlanningDay(date: moved, timeZone: TimeZone(identifier: day.timeZoneIdentifier) ?? .current)
    }
}

struct PlanSectionHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage).font(Typography.sectionTitle())
            Spacer()
            trailing()
        }
        .padding(.top, 6)
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }
}

extension PlanSectionHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}

struct PlanEmptyCard: View {
    let title: String
    let detail: String
    let symbol: String

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
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
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
                    Text("Calendar can reveal real openings").font(.subheadline.weight(.semibold))
                    Text("Optional and read-only.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
            .accessibilityIdentifier("plan.calendar.notRequested")
        case .denied:
            HStack(spacing: 10) {
                Label("Calendar off · planning still works", systemImage: "calendar.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
                Button("Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
            .accessibilityIdentifier("plan.calendar.denied")
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing read-only calendar context")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier("plan.calendar.loading")
        case .fresh(let fetchedAt):
            Label(
                "\(snapshot.commitments.count) read-only commitment\(snapshot.commitments.count == 1 ? "" : "s") · updated \(fetchedAt.formatted(date: .omitted, time: .shortened))",
                systemImage: "calendar.badge.checkmark"
            )
            .font(.caption)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier("plan.calendar.fresh")
        case .staleCached(let fetchedAt, let message):
            PlanCalendarCacheWarning(
                store: store,
                title: "Calendar may be stale",
                detail: "Last updated \(fetchedAt.formatted(date: .omitted, time: .shortened)). \(message)",
                symbol: "clock.arrow.circlepath",
                identifier: "plan.calendar.stale"
            )
        case .offlineCached(let fetchedAt):
            PlanCalendarCacheWarning(
                store: store,
                title: "Offline calendar cache",
                detail: "Openings use events from \(fetchedAt.formatted(date: .omitted, time: .shortened)).",
                symbol: "wifi.slash",
                identifier: "plan.calendar.offline"
            )
        case .failed(let message):
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.exclamationmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar couldn’t refresh")
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .lineLimit(2)
                }
                Spacer()
                Button("Retry") { Task { await store.load() } }
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 12)
            .background(
                Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier("plan.calendar.failed")
        }
    }
}

struct PlanCalendarCacheWarning: View {
    let store: PlanStore
    let title: String
    let detail: String
    let symbol: String
    let identifier: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            Spacer()
            Button("Retry") { Task { await store.load() } }
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(
            Color(LifeBoardColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityIdentifier(identifier)
    }
}

struct PlanCalibrationSuggestionRow: View {
    let store: PlanStore
    let suggestion: EstimateCalibrationSuggestion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer.square")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 2) {
                Text("Observed median: \(PlanSectionCopy.duration(suggestion.suggestedDuration))")
                    .font(.caption.weight(.semibold))
                Text(
                    "\(suggestion.evidenceSessionCount) sessions · \(PlanSectionCopy.duration(suggestion.observedMinimum))–\(PlanSectionCopy.duration(suggestion.observedMaximum)) observed"
                )
                .font(.caption2)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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

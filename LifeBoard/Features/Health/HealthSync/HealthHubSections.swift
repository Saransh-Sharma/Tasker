import Accessibility
import Charts
import SwiftUI

// The Health hub's sections, one `struct` each.
//
// They were seven computed `some View`s on `HealthHubView`, stacked at equal
// weight with no dominant object, each wrapped in a hand-rolled
// `healthWarmCard()` (radius 20, manual stroke, no specular rim, no depth
// shadow, no Increase-Contrast or Reduce-Transparency handling) and headed by a
// locally restyled `healthSectionHeader` used six times — which `DESIGN.md`
// calls a defect in as many words.

// MARK: - Shared formatting

enum HealthHubFormat {
    static func value(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps: "\(Int(value))"
        case .walkingRunningDistance: String(format: "%.1f km", value / 1_000)
        case .water: "\(Int(value)) mL"
        case .bodyMass: String(format: "%.1f kg", value)
        case .bodyFatPercentage: String(format: "%.1f%%", value)
        case .waistCircumference: String(format: "%.1f cm", value)
        case .restingHeartRate: "\(Int(value)) bpm"
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat: String(format: "%.0f g", value)
        case .activeEnergy, .restingEnergy, .dietaryEnergy: "\(Int(value)) kcal"
        default: String(format: "%.1f", value)
        }
    }

    /// Freshness read from the sample rather than asserted. "Today" was
    /// hard-coded onto every row, including week-old records.
    static func freshness(_ lastSampleAt: Date?) -> String {
        guard let lastSampleAt else { return String(localized: "No time recorded") }
        if Calendar.current.isDateInToday(lastSampleAt) { return String(localized: "Today") }
        if Calendar.current.isDateInYesterday(lastSampleAt) { return String(localized: "Yesterday") }
        return lastSampleAt.formatted(date: .abbreviated, time: .omitted)
    }

    /// A display name per metric. The raw value is a camel-cased identifier,
    /// and capitalizing it put "Restingheartrate" on screen.
    static func title(_ metric: HealthMetric) -> String {
        switch metric {
        case .steps: String(localized: "Steps")
        case .walkingRunningDistance: String(localized: "Walking distance")
        case .activeEnergy: String(localized: "Active energy")
        case .restingEnergy: String(localized: "Resting energy")
        case .water: String(localized: "Water")
        case .dietaryEnergy: String(localized: "Dietary energy")
        case .dietaryProtein: String(localized: "Protein")
        case .dietaryCarbohydrates: String(localized: "Carbohydrates")
        case .dietaryFat: String(localized: "Fat")
        case .bodyMass: String(localized: "Weight")
        case .bodyFatPercentage: String(localized: "Body fat")
        case .waistCircumference: String(localized: "Waist")
        case .restingHeartRate: String(localized: "Resting heart rate")
        case .workout: String(localized: "Workouts")
        case .sleep: String(localized: "Sleep")
        }
    }

    static func domainStatus(_ status: HealthDomainStatus) -> String {
        if status.hasPartialWriteAuthorization { return String(localized: "Partly allowed") }
        if status.writeAuthorizations.values.contains(.denied) { return String(localized: "Saving turned off in Health") }
        if status.readRequestState == .neverRequested { return String(localized: "Not connected") }
        return status.writeEnabled ? String(localized: "Saves new logs to Health") : String(localized: "Read only")
    }
}

// MARK: - Hero

/// The hub's one dominant object.
///
/// It carries the connection decision and the capture action, not a metric.
/// Putting today's steps here would duplicate the ring below it and start the
/// hero down the road to a dashboard, which is the failure `DESIGN.md` names:
/// "a hero that has grown a second metric has become a dashboard and must
/// return to clay". The rings, the chart and the value table are evidence, and
/// evidence stays in clay beneath.
struct HealthHubHeroSection: View {
    let isConnected: Bool
    let statusLine: String
    let palette: DaypartPalette
    let onConnect: () -> Void
    let onLogWater: () -> Void
    let pulseTrigger: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusLine)
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))

            Text(isConnected ? String(localized: "Apple Health") : String(localized: "Connect Apple Health"))
                .lifeboardFont(.sectionTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))

            Button(isConnected ? String(localized: "Log water") : String(localized: "Connect"), action: isConnected ? onLogWater : onConnect)
                .buttonStyle(.lifeBoardPrimary)
                .accessibilityIdentifier(isConnected ? "health.hero.logWater" : "health.hero.connect")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardHeroSurface(palette: palette)
        .lifeboardHealthSyncPulse(trigger: pulseTrigger)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("health.hero")
    }
}

// MARK: - Movement

struct HealthHubMovementSection: View {
    let store: HealthConnectionStore
    let warpTrigger: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Activity", symbol: "clock")
            HStack(spacing: 12) {
                HealthHubMetricRing(store: store, metric: .steps, target: 10_000, label: "Steps")
                HealthHubMetricRing(store: store, metric: .activeEnergy, target: 500, label: "Active kcal")
                HealthHubMetricRing(store: store, metric: .walkingRunningDistance, target: 5_000, label: "Distance")
            }
            // The water-goal warp used to fire here, on the movement rings —
            // an effect celebrating a metric this section does not show.
            // `DESIGN.md`: signature effects belong to the recorded state they
            // correspond to. It now lives on Hydration.
            .lifeboardVitalOrbWarp(trigger: warpTrigger)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }
}

private struct HealthHubMetricRing: View {
    let store: HealthConnectionStore
    let metric: HealthMetric
    let target: Double
    let label: String

    var body: some View {
        let value = store.aggregates[metric]?.value
        VStack(spacing: 8) {
            // `EmptyView`, not `Text(label)`. The gauge drew the label *around*
            // the ring and the caption below repeated it, so every ring showed
            // its name twice — overlapping the arc, and truncated to "Activ…"
            // and "Dist…" because an accessory ring has no room for a word.
            Gauge(value: min(value ?? 0, target), in: 0...target) {
                EmptyView()
            } currentValueLabel: {
                Text(value.map { HealthHubFormat.value($0, metric: metric) } ?? "—")
                    .lifeboardFont(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Color.lifeboard(.accentPrimary))

            Text(label)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.map { HealthHubFormat.value($0, metric: metric) } ?? String(localized: "No data"))
    }
}

// MARK: - Hydration

struct HealthHubHydrationSection: View {
    let store: HealthConnectionStore
    /// The person's own daily target from Track. No target, no progress well:
    /// the fill used to measure against a hard-coded 2,000 mL.
    var targetMilliliters: Double? = nil
    /// Bumped when the day's hydration goal is first met.
    var warpTrigger: Int = 0
    let onLogWater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Water", symbol: "drop.fill") {
                Button("Log water", action: onLogWater)
                    .buttonStyle(.lifeBoardChip)
            }
            let value = store.aggregates[.water]?.value
            // Only drawn when there is something to draw. Rendering the track at
            // zero turned "no record" into a 92pt empty slab — which on a dark
            // canvas reads as a void, and either way states an amount the app has
            // not been told. `DESIGN.md`: unknown data is not zero, and no-record
            // is a distinct state from an explicit zero.
            if let value, let target = targetMilliliters, target > 0 {
                GeometryReader { proxy in
                    let progress = min(max(value / target, 0), 1)
                    ZStack(alignment: .bottom) {
                        Color.clear
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Color.lifeboard(.accentPrimary).opacity(0.42))
                            .frame(height: proxy.size.height * progress)
                    }
                }
                .frame(height: 92)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                // A progress track is a recessed well, not a raised panel.
                .lifeBoardClaySurface(.well, cornerRadius: Radius.card)
                .accessibilityHidden(true)
            }

            // Provenance travels with the value, and it names the sources the
            // record actually has rather than asserting both every time.
            Text(
                value.map { amount in
                    let measured = Measurement(value: amount, unit: UnitVolume.milliliters)
                        .formatted(.measurement(width: .abbreviated, usage: .asProvided))
                    let goal = targetMilliliters.map {
                        " of " + Measurement(value: $0, unit: UnitVolume.milliliters)
                            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
                    } ?? ""
                    return "\(measured)\(goal) today · \(store.aggregates[.water]?.sourceLabel ?? "Apple Health")"
                } ?? String(localized: "No water recorded today")
            )
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
        .lifeboardVitalOrbWarp(trigger: warpTrigger)
    }
}

// MARK: - Nutrition

struct HealthHubNutritionSection: View {
    let store: HealthConnectionStore

    @State private var revealProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Nutrition", symbol: "fork.knife")
            Text("Shown as daily totals.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            if hasData == false {
                // Four bars at zero said "you ate nothing today" when what
                // happened was that nothing was recorded. `DESIGN.md`: unknown
                // data is not zero, and no-record is its own state.
                StatusSurface(
                    state: .noRecord,
                    title: String(localized: "Nothing recorded today"),
                    message: "",
                    density: .compact
                )
            } else {
                // Energy is a number of its own, not a bar. Plotted beside the
                // macros on one axis, ~2,000 kcal set the scale and ~60 g of
                // protein, carbs and fat shrank to slivers — the chart could
                // only ever say "calories are big".
                if let calories {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(calories.formatted(.number.precision(.fractionLength(0))))
                            .lifeboardFont(.metric)
                            .monospacedDigit()
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        Text("kcal")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Dietary energy today")
                    .accessibilityValue("\(calories.formatted(.number.precision(.fractionLength(0)))) kilocalories")
                }

                if macroValues.isEmpty == false {
                    Chart(macroValues) { item in
                        BarMark(
                            x: .value("Nutrient", item.label),
                            y: .value("Grams", item.value)
                        )
                        .foregroundStyle(Color.lifeboard(.accentSecondary))
                    }
                    .chartYAxisLabel("g")
                    .frame(height: 150)
                    // A chart hidden from VoiceOver leaves its evidence unreadable.
                    // `DESIGN.md` asks charts for a prose equivalent.
                    .accessibilityElement()
                    .accessibilityLabel("Macros today, from Apple Health")
                    .accessibilityValue(chartSummary)
                    // Audio Graphs: the chart as data, not only as prose.
                    .accessibilityChartDescriptor(CategoryBarChartDescriptor(
                        title: String(localized: "Macros today"),
                        categoryTitle: "Nutrient",
                        valueTitle: "Grams",
                        unit: "g",
                        points: macroValues.map { .init(label: $0.label, value: $0.value) }
                    ))
                    .lifeboardChartRevealSweep(progress: revealProgress)
                }
            }

            if let last = store.aggregates[.dietaryEnergy]?.lastSampleAt {
                Text("Last entry \(last.formatted(date: .abbreviated, time: .shortened))")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
        // The sweep draws once, and only when there is something to reveal.
        // "Empty, denied, and unavailable states never sweep, because a reveal
        // animation implies data arrived."
        .onChange(of: hasData) { _, nowHasData in
            guard nowHasData, revealProgress == 0 else { return }
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { revealProgress = 1 }
        }
        .onAppear {
            revealProgress = hasData ? 1 : 0
        }
    }

    private var hasData: Bool { calories != nil || macroValues.isEmpty == false }

    /// `nil` when nothing was recorded — never `0`.
    private var calories: Double? {
        store.aggregates[.dietaryEnergy]?.value
    }

    /// Only gram macros that actually have a record, so they share an axis in
    /// a single unit. A missing aggregate used to be plotted as `0`, which is
    /// a different claim entirely.
    private var macroValues: [HealthNutritionChartValue] {
        let nutrients: [(String, HealthMetric)] = [
            ("Protein", .dietaryProtein),
            ("Carbs", .dietaryCarbohydrates),
            ("Fat", .dietaryFat)
        ]
        return nutrients.compactMap { label, domain in
            guard let aggregate = store.aggregates[domain] else { return nil }
            return HealthNutritionChartValue(label: label, value: aggregate.value)
        }
    }

    private var chartSummary: String {
        macroValues
            .map { "\($0.label) \($0.value.formatted(.number.precision(.fractionLength(0)))) g" }
            .joined(separator: ", ")
    }
}

// MARK: - Fasting

struct HealthHubFastingSection: View {
    let suggestion: Date?
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Fasting", symbol: "hourglass")

            if let suggestion {
                Text("Suggested start: \(suggestion.formatted(date: .abbreviated, time: .shortened))")
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(source)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            } else {
                Text("Log a meal to see a suggested start.")
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }
}

// MARK: - Values

struct HealthHubValuesSection: View {
    let store: HealthConnectionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Latest values", symbol: "tablecells")
            ForEach(store.aggregates.values.sorted { $0.metric.rawValue < $1.metric.rawValue }) { item in
                HStack {
                    Text(HealthHubFormat.title(item.metric))
                        .lifeboardFont(.body)
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(HealthHubFormat.value(item.value, metric: item.metric))
                            .lifeboardFont(.body)
                            .monospacedDigit()
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                        // Provenance travels with the value: a number without a
                        // source is not evidence.
                        // Was hard-coded "· Today", which claimed a freshness
                        // the record may not have. `DESIGN.md`: never imply
                        // freshness a value cannot support.
                        Text("\(item.sourceLabel) · \(HealthHubFormat.freshness(item.lastSampleAt))")
                            .lifeboardFont(.caption2)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }
}

// MARK: - Connections

struct HealthHubConnectionsSection: View {
    let store: HealthConnectionStore
    let onEducate: (HealthDomain) -> Void
    let onLogWeight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Connections", symbol: "switch.2")
            ForEach(HealthDomain.allCases) { domain in
                HealthHubConnectionRow(
                    domain: domain,
                    status: store.statuses[domain] ?? .init(domain: domain),
                    store: store,
                    onEducate: onEducate
                )
            }
            Button("Log weight", action: onLogWeight)
                .buttonStyle(.lifeBoardChip)
                .accessibilityIdentifier("health.connections.logWeight")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }
}

private struct HealthHubConnectionRow: View {
    let domain: HealthDomain
    let status: HealthDomainStatus
    let store: HealthConnectionStore
    let onEducate: (HealthDomain) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: domain.symbolName)
                .frame(width: 28)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(domain.title)
                    .lifeboardFont(.body)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(HealthHubFormat.domainStatus(status))
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            Spacer()
            if domain.supportsWriteBack {
                // Was `Toggle("")`, so VoiceOver announced a switch with no
                // name. The label stays visually hidden; it is the control's
                // accessible name.
                Toggle("Save \(domain.title) to Health", isOn: Binding(
                    get: { status.writeEnabled },
                    set: { enabled in
                        if enabled && status.readRequestState == .neverRequested {
                            onEducate(domain)
                        } else {
                            Task { await store.setWriteEnabled(enabled, for: domain) }
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.lifeBoardClay)
            } else if status.readRequestState == .neverRequested {
                Button("Connect") { onEducate(domain) }
                    .buttonStyle(.lifeBoardChip)
            }
        }
        .frame(minHeight: 48)
    }
}

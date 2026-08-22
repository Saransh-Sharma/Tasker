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

    static func title(_ metric: HealthMetric) -> String {
        metric.rawValue
            .replacingOccurrences(of: "walkingRunning", with: "walking running ")
            .replacingOccurrences(of: "dietary", with: "")
            .replacingOccurrences(of: "body", with: "body ")
            .capitalized
    }

    static func domainStatus(_ status: HealthDomainStatus) -> String {
        if status.hasPartialWriteAuthorization { return "Partially allowed" }
        if status.writeAuthorizations.values.contains(.denied) { return "Writing denied · local logging still works" }
        if status.readRequestState == .neverRequested { return "Not requested" }
        return status.writeEnabled ? "Future LifeBoard entries sync" : "Read only"
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

            Text(isConnected ? "Apple Health" : "Connect Apple Health")
                .lifeboardFont(.sectionTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))

            Text(isConnected
                 ? "Movement and nutrition read across from Health. What you log here can flow back."
                 : "Choose what LifeBoard may share. Read access stays private — Apple does not reveal whether you denied a read category.")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Button(isConnected ? "Log water" : "Connect", action: isConnected ? onLogWater : onConnect)
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
            SectionHeader("Today from Apple Health", symbol: "clock")
            HStack(spacing: 12) {
                HealthHubMetricRing(store: store, metric: .steps, target: 10_000, label: "Steps")
                HealthHubMetricRing(store: store, metric: .activeEnergy, target: 500, label: "Active kcal")
                HealthHubMetricRing(store: store, metric: .walkingRunningDistance, target: 5_000, label: "Distance")
            }
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
        .accessibilityValue(value.map { HealthHubFormat.value($0, metric: metric) } ?? "Unavailable")
    }
}

// MARK: - Hydration

struct HealthHubHydrationSection: View {
    let store: HealthConnectionStore
    let onLogWater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Hydration", symbol: "drop.fill") {
                Button("Log water", action: onLogWater)
                    .buttonStyle(.lifeBoardChip)
            }
            let value = store.aggregates[.water]?.value
            // Only drawn when there is something to draw. Rendering the track at
            // zero turned "no record" into a 92pt empty slab — which on a dark
            // canvas reads as a void, and either way states an amount the app has
            // not been told. `DESIGN.md`: unknown data is not zero, and no-record
            // is a distinct state from an explicit zero.
            if let value {
                GeometryReader { proxy in
                    let progress = min(max(value / 2_000, 0), 1)
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

            Text(value.map { "\(Int($0)) mL today · Apple Health + LifeBoard" } ?? "No hydration data available")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
    }
}

// MARK: - Nutrition

struct HealthHubNutritionSection: View {
    let store: HealthConnectionStore

    @State private var revealProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Nutrition aggregate", symbol: "fork.knife")
            Text("Apple Health entries stay aggregated. LifeBoard never reconstructs them into meals.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Chart(values) { item in
                BarMark(
                    x: .value("Nutrient", item.label),
                    y: .value("Value", item.value)
                )
                .foregroundStyle(Color.lifeboard(.accentSecondary))
            }
            .frame(height: 150)
            .accessibilityHidden(true)
            .lifeboardChartRevealSweep(progress: revealProgress)

            if let last = store.aggregates[.dietaryEnergy]?.lastSampleAt {
                Text("Last dietary energy: \(last.formatted(date: .abbreviated, time: .shortened))")
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
            withAnimation(.easeOut(duration: 0.6)) { revealProgress = 1 }
        }
        .onAppear {
            revealProgress = hasData ? 1 : 0
        }
    }

    private var hasData: Bool {
        values.contains { $0.value > 0 }
    }

    private var values: [HealthNutritionChartValue] {
        [
            .init(label: "kcal", value: store.aggregates[.dietaryEnergy]?.value ?? 0),
            .init(label: "Protein", value: store.aggregates[.dietaryProtein]?.value ?? 0),
            .init(label: "Carbs", value: store.aggregates[.dietaryCarbohydrates]?.value ?? 0),
            .init(label: "Fat", value: store.aggregates[.dietaryFat]?.value ?? 0)
        ]
    }
}

struct HealthNutritionChartValue: Identifiable {
    let label: String
    let value: Double
    var id: String { label }
}

// MARK: - Fasting

struct HealthHubFastingSection: View {
    let suggestion: Date?
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Fasting context", symbol: "hourglass")
            Text("Suggestion only · LifeBoard never auto-starts a fast or writes fasting to Apple Health.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            if let suggestion {
                Text("Suggested start: \(suggestion.formatted(date: .abbreviated, time: .shortened))")
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(source)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            } else {
                Text("Log a meal or connect dietary energy to receive a start suggestion.")
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
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Accessible values", symbol: "tablecells")
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
                        Text("\(item.sourceLabel) · Today")
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
                Toggle("", isOn: Binding(
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
